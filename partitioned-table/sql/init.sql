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
    constraint fk_drawer_notification_event foreign key (event_id) references event (id)
) partition by range (created);

-- Index on event_id for efficient FK checks when deleting from event table
create index ix_drawer_notification_event_id on drawer_notification(event_id);

create table drawer_notification_org (
    org_id varchar(50) not null,
    user_id varchar(50) not null,
    event_id uuid not null,
    read boolean not null default false,
    created timestamp not null,
    constraint fk_drawer_notification_org_event foreign key (event_id) references event (id)
) partition by list (org_id);

-- Indexes for efficient operations on drawer_notification_org
create index ix_drawer_notification_org_event_id on drawer_notification_org(event_id);
create index ix_drawer_notification_org_created on drawer_notification_org(created);

create procedure init(
    orgs_count integer,
    users_per_org integer,
    days_to_insert integer,
    daily_event_records integer
) language plpgsql as $$
declare
    current_day_timestamp timestamp;
    generated_date date;
    new_partition_day text;
    new_partition_org text;
begin

    raise info 'Bootstrapping the database...';

    -- Create org partitions for drawer_notification_org
    raise info 'Creating org partitions for drawer_notification_org...';
    for i in 1..orgs_count loop
        new_partition_org := 'drawer_notification_org_' || i;
        execute format(
            'create table if not exists %s partition of drawer_notification_org for values in (%L);',
            new_partition_org,
            'org-' || i
        );
    end loop;
    raise info 'Created % org partitions', orgs_count;

    raise info 'Inserting drawer_notification records for % days...', days_to_insert;
    for i in 1..days_to_insert loop

        current_day_timestamp := clock_timestamp() - (days_to_insert - i || ' days')::interval;
        generated_date := current_day_timestamp::date;

        -- Create partition for drawer_notification (by day)
        new_partition_day := 'drawer_notification_' || replace(generated_date::text, '-', '_');
        execute format(
            'create table if not exists %s partition of drawer_notification for values from (%L) to (%L);',
            new_partition_day,
            generated_date::text,
            (generated_date + 1)::text
        );
        raise info 'Created partition %', new_partition_day;

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
        where date(e.created) = generated_date;

        -- Insert into drawer_notification_org (same data, different partitioning)
        insert into drawer_notification_org (org_id, user_id, event_id, read, created)
        select
            e.org_id,
            'user-' || u.user_num,
            e.id,
            false,
            e.created
        from event e
        cross join lateral generate_series(1, users_per_org) as u(user_num)
        where date(e.created) = generated_date;

        raise info 'Day % - Inserted event and drawer_notification records', i;

    end loop;

    raise info 'Done inserting all records';
    raise info 'Done bootstrapping the database';

end;
$$;

-- call init(10, 100, 10, 100000);
