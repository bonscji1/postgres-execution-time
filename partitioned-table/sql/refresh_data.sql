-- Script to refresh data in partitioned tables (keep last 14 days only)
-- This script drops partitions older than 14 days and benchmarks the execution time

\timing on

-- Drop old partitions for drawer_notification (partitioned by day)
DO $$
DECLARE
    cutoff_date date;
    partition_name text;
    start_time timestamp;
    end_time timestamp;
    duration_drawer interval;
    duration_drawer_org interval;
    duration_event interval;
    total_duration interval;
    dropped_partitions int := 0;
    deleted_drawer_org bigint;
    deleted_events bigint;
    partition_date date;
BEGIN
    cutoff_date := (current_timestamp - interval '14 days')::date;

    RAISE INFO '=== Starting Data Refresh (Partitioned Tables) ===';
    RAISE INFO 'Cutoff date: %', cutoff_date;
    RAISE INFO 'Current time: %', current_timestamp;
    RAISE INFO '';

    -- Drop old partitions from drawer_notification
    RAISE INFO 'Dropping old partitions from drawer_notification...';
    start_time := clock_timestamp();

    FOR partition_name IN
        SELECT tablename
        FROM pg_tables
        WHERE schemaname = 'public'
        AND tablename LIKE 'drawer_notification_%'
        AND tablename != 'drawer_notification_org'
        AND tablename NOT LIKE 'drawer_notification_org_%'
        ORDER BY tablename
    LOOP
        -- Extract date from partition name (format: drawer_notification_YYYY_MM_DD)
        BEGIN
            partition_date := to_date(substring(partition_name from 'drawer_notification_(.*)'), 'YYYY_MM_DD');

            IF partition_date < cutoff_date THEN
                EXECUTE format('DROP TABLE IF EXISTS %I CASCADE', partition_name);
                dropped_partitions := dropped_partitions + 1;
                RAISE INFO 'Dropped partition: % (date: %)', partition_name, partition_date;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING 'Could not process partition %: %', partition_name, SQLERRM;
        END;
    END LOOP;

    end_time := clock_timestamp();
    duration_drawer := end_time - start_time;

    RAISE INFO 'Dropped % partitions from drawer_notification in %', dropped_partitions, duration_drawer;
    RAISE INFO '';

    -- Delete from drawer_notification_org (partitioned by org_id, must use DELETE)
    RAISE INFO 'Deleting from drawer_notification_org (org-partitioned)...';
    start_time := clock_timestamp();

    DELETE FROM drawer_notification_org
    WHERE created < cutoff_date::timestamp;

    GET DIAGNOSTICS deleted_drawer_org = ROW_COUNT;
    end_time := clock_timestamp();
    duration_drawer_org := end_time - start_time;

    RAISE INFO 'Deleted % rows from drawer_notification_org in %', deleted_drawer_org, duration_drawer_org;
    RAISE INFO '';

    -- Delete old events (event table is not partitioned)
    RAISE INFO 'Deleting old events...';
    start_time := clock_timestamp();

    DELETE FROM event
    WHERE created < cutoff_date::timestamp;

    GET DIAGNOSTICS deleted_events = ROW_COUNT;
    end_time := clock_timestamp();
    duration_event := end_time - start_time;

    RAISE INFO 'Deleted % rows from event in %', deleted_events, duration_event;
    RAISE INFO '';

    -- Calculate total duration
    total_duration := duration_drawer + duration_drawer_org + duration_event;

    RAISE INFO '=== Delete/Drop Summary ===';
    RAISE INFO 'Dropped partitions (day): %', dropped_partitions;
    RAISE INFO 'Deleted from drawer_notification_org: %', deleted_drawer_org;
    RAISE INFO 'Deleted events: %', deleted_events;
    RAISE INFO '';
    RAISE INFO 'Execution times:';
    RAISE INFO '  - Drop drawer_notification partitions (day partitioning): %', duration_drawer;
    RAISE INFO '  - Delete from drawer_notification_org (org partitioning): %', duration_drawer_org;
    RAISE INFO '  - Delete from event (no partitioning): %', duration_event;
    RAISE INFO '  Total delete/drop time: %', total_duration;
    RAISE INFO '';
    RAISE INFO 'Performance Comparison:';
    RAISE INFO '  Day partitioning (DROP):  %', duration_drawer;
    RAISE INFO '  Org partitioning (DELETE): %', duration_drawer_org;
    RAISE INFO '';

END $$;

-- VACUUM ANALYZE tables to reclaim space
VACUUM ANALYZE event;
VACUUM ANALYZE drawer_notification_org;

\timing off
