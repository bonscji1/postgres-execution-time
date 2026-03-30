-- Uncomment the line below to disable parallel workers. See https://www.postgresql.org/docs/current/runtime-config-resource.html#GUC-MAX-PARALLEL-WORKERS-PER-GATHER for more details.
-- set max_parallel_workers_per_gather = 0;

-- Normalized tables (production schema)
create table bundles (
    id uuid not null default gen_random_uuid(),
    name varchar(255) not null,
    display_name text not null,
    constraint pk_bundles primary key (id)
);

create table applications (
    id uuid not null default gen_random_uuid(),
    name varchar(255) not null,
    display_name text not null,
    bundle_id uuid not null,
    constraint pk_applications primary key (id),
    constraint fk_applications_bundle foreign key (bundle_id) references bundles (id)
);

create table event_type (
    id uuid not null default gen_random_uuid(),
    name varchar(255) not null,
    display_name text not null,
    application_id uuid not null,
    constraint pk_event_type primary key (id),
    constraint fk_event_type_application foreign key (application_id) references applications (id)
);

-- Event table with both normalized FK and denormalized fields (matching production)
create table event (
    id uuid not null default gen_random_uuid(),
    created timestamp not null,
    account_id varchar(50),
    org_id varchar(50) not null,
    -- Denormalized fields (current production approach)
    bundle_id uuid not null,
    bundle_display_name text not null,
    application_id uuid not null,
    application_display_name text not null,
    event_type_display_name text not null,
    -- Normalized FK (new approach)
    event_type_id uuid not null,
    payload text,
    rendered_drawer_notification text,
    source_environment varchar,
    severity varchar(20),
    external_id uuid,
    has_authorization_criterion boolean not null default false,
    constraint pk_event primary key (id),
    constraint fk_event_event_type foreign key (event_type_id) references event_type (id)
);

create table drawer_notification (
    org_id varchar(50) not null,
    user_id varchar(50) not null,
    event_id uuid not null,
    read boolean not null default false,
    created timestamp not null,
    constraint pk_drawer_notification primary key (org_id, user_id, event_id),
    constraint fk_drawer_notification_event foreign key (event_id) references event (id)
);

create procedure init(
    orgs_count integer,
    users_per_org integer,
    days_to_insert integer,
    daily_event_records integer
) language plpgsql as $$
declare
    current_day_timestamp timestamp;
    bundle_ids uuid[];
    application_ids uuid[];
    event_type_ids uuid[];
begin

    raise info 'Bootstrapping the database...';

    raise info 'Creating normalized reference data (bundles, applications, event_types)...';

    -- Create 10 bundles
    insert into bundles (name, display_name)
    select
        'bundle-' || i,
        'Bundle ' || i || ' Display Name'
    from generate_series(1, 10) as i;

    select array_agg(id order by display_name) into bundle_ids from bundles;
    raise info 'Created % bundles', array_length(bundle_ids, 1);

    -- Create 20 applications (2 per bundle)
    insert into applications (name, display_name, bundle_id)
    select
        'app-' || i,
        'Application ' || i || ' Display Name',
        bundle_ids[((i - 1) % 10) + 1]
    from generate_series(1, 20) as i;

    select array_agg(id order by display_name) into application_ids from applications;
    raise info 'Created % applications', array_length(application_ids, 1);

    -- Create 100 event types (5 per application)
    insert into event_type (name, display_name, application_id)
    select
        'event-type-' || i,
        'Event Type ' || i || ' Display Name',
        application_ids[((i - 1) % 20) + 1]
    from generate_series(1, 100) as i;

    select array_agg(id order by display_name) into event_type_ids from event_type;
    raise info 'Created % event types', array_length(event_type_ids, 1);

    raise info 'Inserting event and drawer_notification records for % days...', days_to_insert;
    for i in 1..days_to_insert loop

        current_day_timestamp := clock_timestamp() - (days_to_insert - i || ' days')::interval;

        -- Insert events for the day with both denormalized fields and normalized FK
        insert into event (created, account_id, org_id, bundle_id, bundle_display_name, application_id, application_display_name, event_type_display_name, event_type_id, payload, rendered_drawer_notification, source_environment, severity, external_id, has_authorization_criterion)
        select
            current_day_timestamp,
            null, -- account_id (legacy field, nullable)
            'org-' || ((j % orgs_count) + 1),
            a.bundle_id,
            b.display_name,
            et.application_id,
            a.display_name,
            et.display_name,
            et.id,
            '{"data": "' || md5(random()::text) || '"}'::text,
            'Notification from ' || b.display_name || ' - ' || a.display_name || ': ' || et.display_name, -- rendered_drawer_notification
            case when j % 3 = 0 then 'production' else null end, -- source_environment
            case (j % 3) when 0 then 'INFO' when 1 then 'WARNING' else 'CRITICAL' end, -- severity
            gen_random_uuid(), -- external_id
            (j % 10 = 0) -- has_authorization_criterion (10% of events)
        from generate_series(1, daily_event_records) as j
        cross join lateral (
            select * from event_type where id = event_type_ids[((j % 100) + 1)]
        ) et
        join applications a on a.id = et.application_id
        join bundles b on b.id = a.bundle_id;

        -- Insert drawer_notifications for each event, for each user in the org
        insert into drawer_notification (org_id, user_id, event_id, read, created)
        select
            e.org_id,
            'user-' || u.user_num,
            e.id,
            false,
            e.created
        from event e
        cross join lateral generate_series(1, users_per_org) as u(user_num)
        where date(e.created) = date(current_day_timestamp);

        raise info 'Day % - Inserted event and drawer_notification records', i;

    end loop;
    raise info 'Done inserting all records';

    raise info 'Done bootstrapping the database';

end;
$$;

-- ==========================================================================
-- INDEXES - matching production + optimizations for normalized approach
-- ==========================================================================

-- Event table indexes (matching production)
create index ix_event_org_id on event (org_id, created desc, id);
create index ix_event_org_id_application_id on event (org_id, application_id, created desc, id);
create index ix_event_org_id_bundle_id_application_id_event_type_display_name
    on event (org_id, bundle_id, application_id, event_type_display_name, created desc, id);

-- CRITICAL: Index for normalized approach (joins on event_type_id)
-- This index is ESSENTIAL for good performance when joining event -> event_type
create index ix_event_event_type_id on event (event_type_id);

-- Drawer notification indexes (matching production)
create index ix_drawer_notification_org_id_user_id_read_created_event_id
    on drawer_notification (org_id, user_id, read, created desc, event_id);
create index ix_drawer_notification_event_id on drawer_notification (event_id);

-- Normalized table FK indexes (CRITICAL for join performance)
-- PostgreSQL does NOT automatically index FK columns!
-- These speed up joins and also speed up data insertion (FK constraint validation)
create index ix_applications_bundle_id on applications (bundle_id);
create index ix_event_type_application_id on event_type (application_id);

-- Optional: Indexes to speed up filtering by display names in normalized approach
-- These allow index-only scans when filtering by display_name in WHERE clauses
create index ix_bundles_display_name on bundles (display_name);
create index ix_applications_display_name on applications (display_name);
create index ix_event_type_display_name on event_type (display_name);

-- Init data by:
-- call init(10, 100, 15, 5000);
