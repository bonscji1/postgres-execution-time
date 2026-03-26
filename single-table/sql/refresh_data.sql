-- Script to refresh data in single tables (keep last 14 days only)
-- This script deletes data older than 14 days and benchmarks the execution time

\timing on

-- Calculate the cutoff date (14 days ago from now)
DO $$
DECLARE
    cutoff_date timestamp;
    start_time timestamp;
    end_time timestamp;
    duration_event interval;
    duration_drawer interval;
    duration_drawer_jsonb interval;
    duration_drawer_jsonb_simple interval;
    total_duration interval;
    deleted_events bigint;
    deleted_drawer bigint;
    deleted_drawer_jsonb bigint;
    deleted_drawer_jsonb_simple bigint;
BEGIN
    cutoff_date := current_timestamp - interval '14 days';

    RAISE INFO '=== Starting Data Refresh (Single Tables) ===';
    RAISE INFO 'Cutoff date: %', cutoff_date;
    RAISE INFO 'Current time: %', current_timestamp;
    RAISE INFO '';

    -- Delete from drawer_notification (has FK to event, must go first)
    RAISE INFO 'Deleting from drawer_notification...';
    start_time := clock_timestamp();

    DELETE FROM drawer_notification
    WHERE created < cutoff_date;

    GET DIAGNOSTICS deleted_drawer = ROW_COUNT;
    end_time := clock_timestamp();
    duration_drawer := end_time - start_time;

    RAISE INFO 'Deleted % rows from drawer_notification in %', deleted_drawer, duration_drawer;
    RAISE INFO '';

    -- Delete from drawer_notification_jsonb
    RAISE INFO 'Deleting from drawer_notification_jsonb...';
    start_time := clock_timestamp();

    DELETE FROM drawer_notification_jsonb
    WHERE created < cutoff_date;

    GET DIAGNOSTICS deleted_drawer_jsonb = ROW_COUNT;
    end_time := clock_timestamp();
    duration_drawer_jsonb := end_time - start_time;

    RAISE INFO 'Deleted % rows from drawer_notification_jsonb in %', deleted_drawer_jsonb, duration_drawer_jsonb;
    RAISE INFO '';

    -- Delete from drawer_notification_jsonb_simple
    RAISE INFO 'Deleting from drawer_notification_jsonb_simple...';
    start_time := clock_timestamp();

    DELETE FROM drawer_notification_jsonb_simple
    WHERE created < cutoff_date;

    GET DIAGNOSTICS deleted_drawer_jsonb_simple = ROW_COUNT;
    end_time := clock_timestamp();
    duration_drawer_jsonb_simple := end_time - start_time;

    RAISE INFO 'Deleted % rows from drawer_notification_jsonb_simple in %', deleted_drawer_jsonb_simple, duration_drawer_jsonb_simple;
    RAISE INFO '';

    -- Delete from event (after child tables)
    RAISE INFO 'Deleting from event...';
    start_time := clock_timestamp();

    DELETE FROM event
    WHERE created < cutoff_date;

    GET DIAGNOSTICS deleted_events = ROW_COUNT;
    end_time := clock_timestamp();
    duration_event := end_time - start_time;

    RAISE INFO 'Deleted % rows from event in %', deleted_events, duration_event;
    RAISE INFO '';

    -- Calculate total duration
    total_duration := duration_drawer + duration_drawer_jsonb + duration_drawer_jsonb_simple + duration_event;

    RAISE INFO '=== Delete Summary ===';
    RAISE INFO 'Total rows deleted:';
    RAISE INFO '  - event: %', deleted_events;
    RAISE INFO '  - drawer_notification: %', deleted_drawer;
    RAISE INFO '  - drawer_notification_jsonb: %', deleted_drawer_jsonb;
    RAISE INFO '  - drawer_notification_jsonb_simple: %', deleted_drawer_jsonb_simple;
    RAISE INFO '';
    RAISE INFO 'Delete execution times:';
    RAISE INFO '  - drawer_notification: %', duration_drawer;
    RAISE INFO '  - drawer_notification_jsonb: %', duration_drawer_jsonb;
    RAISE INFO '  - drawer_notification_jsonb_simple: %', duration_drawer_jsonb_simple;
    RAISE INFO '  - event: %', duration_event;
    RAISE INFO '  Total delete time: %', total_duration;
    RAISE INFO '';

END $$;

-- VACUUM ANALYZE all tables to reclaim space
VACUUM ANALYZE event;
VACUUM ANALYZE drawer_notification;
VACUUM ANALYZE drawer_notification_jsonb;
VACUUM ANALYZE drawer_notification_jsonb_simple;

\timing off
