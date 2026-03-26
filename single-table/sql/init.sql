-- Uncomment the line below to disable parallel workers. See https://www.postgresql.org/docs/current/runtime-config-resource.html#GUC-MAX-PARALLEL-WORKERS-PER-GATHER for more details.
-- set max_parallel_workers_per_gather = 0;

create table event (
    id uuid not null default gen_random_uuid(),
    created timestamp not null,
    org_id varchar(50) not null,
    bundle_id uuid not null,
    bundle_display_name text not null,
    application_id uuid not null,
    application_display_name text not null,
    event_type_display_name text not null,
    payload text,
    constraint pk_event primary key (id)
);

-- Index on created column for efficient date-based queries and deletes
create index ix_event_created on event(created);

create table drawer_notification (
    org_id varchar(50) not null,
    user_id varchar(50) not null,
    event_id uuid not null,
    read boolean not null default false,
    created timestamp not null,
    constraint pk_drawer_notification primary key (org_id, user_id, event_id),
    constraint fk_drawer_notification_event foreign key (event_id) references event (id)
);

-- Indexes for efficient FK checks and date-based deletes
create index ix_drawer_notification_event_id on drawer_notification(event_id);
create index ix_drawer_notification_created on drawer_notification(created);

create table drawer_notification_jsonb (
    org_id varchar(50) not null,
    event_id uuid not null,
    users jsonb not null,
    created timestamp not null,
    constraint pk_drawer_notification_jsonb primary key (org_id, event_id),
    constraint fk_drawer_notification_jsonb_event foreign key (event_id) references event (id)
);

-- Indexes for efficient FK checks and date-based deletes
create index ix_drawer_notification_jsonb_event_id on drawer_notification_jsonb(event_id);
create index ix_drawer_notification_jsonb_created on drawer_notification_jsonb(created);

create table drawer_notification_jsonb_simple (
    org_id varchar(50) not null,
    event_id uuid not null,
    user_ids jsonb not null,
    created timestamp not null,
    constraint pk_drawer_notification_jsonb_simple primary key (org_id, event_id),
    constraint fk_drawer_notification_jsonb_simple_event foreign key (event_id) references event (id)
);

-- Indexes for efficient FK checks and date-based deletes
create index ix_drawer_notification_jsonb_simple_event_id on drawer_notification_jsonb_simple(event_id);
create index ix_drawer_notification_jsonb_simple_created on drawer_notification_jsonb_simple(created);

create procedure init(
    orgs_count integer,
    users_per_org integer,
    days_to_insert integer,
    daily_event_records integer
) language plpgsql as $$
declare
    current_day_timestamp timestamp;
begin

    raise info 'Bootstrapping the database...';

    raise info 'Inserting drawer_notification records for % days...', days_to_insert;
    for i in 1..days_to_insert loop

        current_day_timestamp := clock_timestamp() - (days_to_insert - i || ' days')::interval;

        -- Insert events for the day
        insert into event (created, org_id, bundle_id, bundle_display_name, application_id, application_display_name, event_type_display_name, payload)
        select
            current_day_timestamp,
            'org-' || ((j % orgs_count) + 1),
            gen_random_uuid(),
            'bundle-' || ((j % 10) + 1),
            gen_random_uuid(),
            'app-' || ((j % 20) + 1),
            'event-type-' || ((j % 5) + 1),
            '{"data": "' || md5(random()::text) || '"}'
        from generate_series(1, daily_event_records) as j;

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

        -- Insert drawer_notifications_jsonb with all users in a JSONB array per event
        insert into drawer_notification_jsonb (org_id, event_id, users, created)
        select
            e.org_id,
            e.id,
            jsonb_agg(jsonb_build_object('user_id', 'user-' || u.user_num, 'read', false)),
            e.created
        from event e
        cross join lateral generate_series(1, users_per_org) as u(user_num)
        where date(e.created) = date(current_day_timestamp)
        group by e.org_id, e.id, e.created;

        -- Insert drawer_notifications_jsonb_simple with simple array of user IDs
        insert into drawer_notification_jsonb_simple (org_id, event_id, user_ids, created)
        select
            e.org_id,
            e.id,
            jsonb_agg('user-' || u.user_num),
            e.created
        from event e
        cross join lateral generate_series(1, users_per_org) as u(user_num)
        where date(e.created) = date(current_day_timestamp)
        group by e.org_id, e.id, e.created;

        raise info 'Day % - Inserted event and drawer_notification records', i;

    end loop;
    raise info 'Done inserting all records';

    raise info 'Done bootstrapping the database';

end;
$$;

-- call init(10, 100, 15, 100000);
