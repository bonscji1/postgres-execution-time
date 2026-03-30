-- ==================================================================================
-- BENCHMARK 1: Fetching event log with drawer notifications (typical user query)
-- ==================================================================================

-- Scenario: User opens notification drawer and sees their recent unread events
-- This is the most common query pattern in production

\echo '====== QUERY 1A: DENORMALIZED APPROACH (current production) ======'
\echo 'Using denormalized display_name fields directly from event table'
\echo 'Matches actual DrawerNotificationRepository.getNotifications() query'
\echo ''

explain (analyze, buffers, verbose)
select
    dn.event_id,
    dn.read,
    e.bundle_display_name,
    e.application_display_name,
    e.event_type_display_name,
    dn.created,
    e.rendered_drawer_notification,
    b.name as bundle_name,
    e.severity
from drawer_notification dn
join event e on dn.event_id = e.id
join bundles b on e.bundle_id = b.id
where dn.org_id = 'org-1'
  and dn.user_id = 'user-42'
  and dn.read = false
order by dn.created desc
limit 20;

\echo ''
\echo '====== QUERY 1B: NORMALIZED APPROACH (with joins to get display names) ======'
\echo 'Using JOINs to bundles, applications, event_type tables'
\echo 'Same output as 1A but using normalized approach'
\echo ''

explain (analyze, buffers, verbose)
select
    dn.event_id,
    dn.read,
    b.display_name as bundle_display_name,
    a.display_name as application_display_name,
    et.display_name as event_type_display_name,
    dn.created,
    e.rendered_drawer_notification,
    b.name as bundle_name,
    e.severity
from drawer_notification dn
join event e on dn.event_id = e.id
join event_type et on e.event_type_id = et.id
join applications a on et.application_id = a.id
join bundles b on a.bundle_id = b.id
where dn.org_id = 'org-1'
  and dn.user_id = 'user-42'
  and dn.read = false
order by dn.created desc
limit 20;

-- ==================================================================================
-- BENCHMARK 2: Event log filtering and sorting by display names
-- ==================================================================================

-- Scenario: Admin UI filtering events by bundle/app/event type display name
-- Tests the impact of joins on WHERE clauses and ORDER BY

\echo ''
\echo '====== QUERY 2A: DENORMALIZED - Filter by event type display name ======'
\echo ''

explain (analyze, buffers, verbose)
select
    e.id,
    e.created,
    e.bundle_display_name,
    e.application_display_name,
    e.event_type_display_name
from event e
where e.org_id = 'org-5'
  and e.event_type_display_name like 'Event Type 1%'
order by e.created desc
limit 50;

\echo ''
\echo '====== QUERY 2B: NORMALIZED - Filter by event type display name (with join) ======'
\echo ''

explain (analyze, buffers, verbose)
select
    e.id,
    e.created,
    b.display_name as bundle_display_name,
    a.display_name as application_display_name,
    et.display_name as event_type_display_name
from event e
join event_type et on e.event_type_id = et.id
join applications a on et.application_id = a.id
join bundles b on a.bundle_id = b.id
where e.org_id = 'org-5'
  and et.display_name like 'Event Type 1%'
order by e.created desc
limit 50;

-- ==================================================================================
-- BENCHMARK 3: Sorting by display names (tests JOIN overhead on ORDER BY)
-- ==================================================================================

\echo ''
\echo '====== QUERY 3A: DENORMALIZED - Order by bundle display name ======'
\echo ''

explain (analyze, buffers, verbose)
select
    e.id,
    e.created,
    e.bundle_display_name,
    e.application_display_name,
    e.event_type_display_name
from event e
where e.org_id = 'org-3'
  and e.created >= now() - interval '7 days'
order by e.bundle_display_name, e.created desc
limit 100;

\echo ''
\echo '====== QUERY 3B: NORMALIZED - Order by bundle display name (with join) ======'
\echo ''

explain (analyze, buffers, verbose)
select
    e.id,
    e.created,
    b.display_name as bundle_display_name,
    a.display_name as application_display_name,
    et.display_name as event_type_display_name
from event e
join event_type et on e.event_type_id = et.id
join applications a on et.application_id = a.id
join bundles b on a.bundle_id = b.id
where e.org_id = 'org-3'
  and e.created >= now() - interval '7 days'
order by b.display_name, e.created desc
limit 100;

-- ==================================================================================
-- BENCHMARK 4: Count events (aggregation query)
-- ==================================================================================

\echo ''
\echo '====== QUERY 4A: DENORMALIZED - Count events by bundle ======'
\echo ''

explain (analyze, buffers, verbose)
select
    e.bundle_display_name,
    count(*) as event_count
from event e
where e.org_id = 'org-2'
  and e.created >= now() - interval '30 days'
group by e.bundle_display_name
order by event_count desc;

\echo ''
\echo '====== QUERY 4B: NORMALIZED - Count events by bundle (with join) ======'
\echo ''

explain (analyze, buffers, verbose)
select
    b.display_name as bundle_display_name,
    count(*) as event_count
from event e
join event_type et on e.event_type_id = et.id
join applications a on et.application_id = a.id
join bundles b on a.bundle_id = b.id
where e.org_id = 'org-2'
  and e.created >= now() - interval '30 days'
group by b.display_name
order by event_count desc;

-- ==================================================================================
-- BENCHMARK 5: Complex filtering (multiple display name filters)
-- ==================================================================================

\echo ''
\echo '====== QUERY 5A: DENORMALIZED - Filter by multiple display names ======'
\echo ''

explain (analyze, buffers, verbose)
select
    e.id,
    e.created,
    e.bundle_display_name,
    e.application_display_name,
    e.event_type_display_name
from event e
where e.org_id = 'org-7'
  and e.bundle_display_name in ('Bundle 1 Display Name', 'Bundle 2 Display Name')
  and e.application_display_name like 'Application%'
order by e.created desc
limit 50;

\echo ''
\echo '====== QUERY 5B: NORMALIZED - Filter by multiple display names (with joins) ======'
\echo ''

explain (analyze, buffers, verbose)
select
    e.id,
    e.created,
    b.display_name as bundle_display_name,
    a.display_name as application_display_name,
    et.display_name as event_type_display_name
from event e
join event_type et on e.event_type_id = et.id
join applications a on et.application_id = a.id
join bundles b on a.bundle_id = b.id
where e.org_id = 'org-7'
  and b.display_name in ('Bundle 1 Display Name', 'Bundle 2 Display Name')
  and a.display_name like 'Application%'
order by e.created desc
limit 50;

-- ==================================================================================
-- BENCHMARK 6: Drawer notification filtering by event type IDs (critical production pattern)
-- ==================================================================================

-- Scenario: Drawer notification query filtering by specific event types
-- This tests the ix_event_event_type_id index performance
-- Matches DrawerNotificationRepository line 107: dn.event.eventType.id IN (:eventTypeIds)

\echo ''
\echo '====== QUERY 6A: DENORMALIZED - Drawer query filtering by event types ======'
\echo 'Note: Production uses event_type FK join even with denormalized approach'
\echo ''

explain (analyze, buffers, verbose)
select
    dn.event_id,
    dn.read,
    e.bundle_display_name,
    e.application_display_name,
    e.event_type_display_name,
    dn.created
from drawer_notification dn
join event e on dn.event_id = e.id
where dn.org_id = 'org-2'
  and dn.user_id = 'user-50'
  and e.org_id = 'org-2'
  and e.event_type_id in (
    select id from event_type where display_name like 'Event Type 1%'
  )
order by dn.created desc
limit 20;

\echo ''
\echo '====== QUERY 6B: NORMALIZED - Drawer query with full join chain ======'
\echo 'Uses normalized approach with all JOINs'
\echo ''

explain (analyze, buffers, verbose)
select
    dn.event_id,
    dn.read,
    b.display_name as bundle_display_name,
    a.display_name as application_display_name,
    et.display_name as event_type_display_name,
    dn.created
from drawer_notification dn
join event e on dn.event_id = e.id
join event_type et on e.event_type_id = et.id
join applications a on et.application_id = a.id
join bundles b on a.bundle_id = b.id
where dn.org_id = 'org-2'
  and dn.user_id = 'user-50'
  and e.org_id = 'org-2'
  and et.display_name like 'Event Type 1%'
order by dn.created desc
limit 20;

-- ==================================================================================
-- BENCHMARK 7: Filtering by severity and authorization criterion (production pattern)
-- ==================================================================================

\echo ''
\echo '====== QUERY 7A: DENORMALIZED - Filter by severity (production use case) ======'
\echo ''

explain (analyze, buffers, verbose)
select
    e.id,
    e.created,
    e.bundle_display_name,
    e.application_display_name,
    e.event_type_display_name,
    e.severity
from event e
where e.org_id = 'org-3'
  and e.severity in ('WARNING', 'CRITICAL')
  and e.has_authorization_criterion = false
  and e.created >= now() - interval '7 days'
order by e.created desc
limit 100;

\echo ''
\echo '====== QUERY 7B: NORMALIZED - Filter by severity (with joins) ======'
\echo ''

explain (analyze, buffers, verbose)
select
    e.id,
    e.created,
    b.display_name as bundle_display_name,
    a.display_name as application_display_name,
    et.display_name as event_type_display_name,
    e.severity
from event e
join event_type et on e.event_type_id = et.id
join applications a on et.application_id = a.id
join bundles b on a.bundle_id = b.id
where e.org_id = 'org-3'
  and e.severity in ('WARNING', 'CRITICAL')
  and e.has_authorization_criterion = false
  and e.created >= now() - interval '7 days'
order by e.created desc
limit 100;
