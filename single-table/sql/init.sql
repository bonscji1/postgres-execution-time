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
    daily_event_records integer,
    retention_delay integer
) language plpgsql as $$
declare
    current_day_timestamp timestamp;
begin

    raise info 'Bootstrapping the database...';

    raise info 'Inserting drawer_notification records for % days with a retention delay of % days...', days_to_insert, retention_delay;
    for i in 1..days_to_insert loop

        if i > retention_delay then
            delete from drawer_notification
            where event_id in (
                select id from event
                where date(created) = (select date(min(created)) from event)
            );
            delete from event
            where date(created) = (select date(min(created)) from event);
            raise info 'Deleted oldest day from drawer_notification and event';
        end if;

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

        raise info 'Day % - Inserted event and drawer_notification records', i;

    end loop;
    raise info 'Done inserting all records';

    raise info 'Done bootstrapping the database';

end;
$$;

call init(10, 100, 60, 100000, 30);
