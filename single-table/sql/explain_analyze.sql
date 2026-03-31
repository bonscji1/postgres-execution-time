-- ==================================================================================
-- SECTION A: CORE PRODUCTION QUERIES
-- ==================================================================================
-- Queries matching actual production usage patterns from notifications repository

-- Query 1A: Drawer notifications (basic)
-- Production: DrawerNotificationRepository.getNotifications() line 45-46

\echo ''
\echo '====== QUERY 1A: DENORMALIZED ======'
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
\echo '====== QUERY 1B: NORMALIZED ======'
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

-- Query 2A: Event log with event type display name filter
-- Production: EventRepository.addHqlConditions() line 152

\echo ''
\echo '====== QUERY 2A: DENORMALIZED ======'
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
\echo '====== QUERY 2B: NORMALIZED ======'
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

-- Query 3A: Drawer with bundle filter (ID-based)
-- Production: DrawerNotificationRepository.addHqlConditions() line 111

\echo ''
\echo '====== QUERY 3A: DENORMALIZED ======'
explain (analyze, buffers, verbose)
select
    dn.event_id,
    dn.read,
    e.bundle_display_name,
    e.application_display_name,
    e.event_type_display_name,
    dn.created,
    e.severity
from drawer_notification dn
join event e on dn.event_id = e.id
where dn.org_id = 'org-1'
  and dn.user_id = 'user-42'
  and e.bundle_id in (
    select id from bundles where name in ('bundle-1', 'bundle-2')
  )
order by dn.created desc
limit 20;

\echo ''
\echo '====== QUERY 3B: NORMALIZED ======'
explain (analyze, buffers, verbose)
select
    dn.event_id,
    dn.read,
    b.display_name as bundle_display_name,
    a.display_name as application_display_name,
    et.display_name as event_type_display_name,
    dn.created,
    e.severity
from drawer_notification dn
join event e on dn.event_id = e.id
join event_type et on e.event_type_id = et.id
join applications a on et.application_id = a.id
join bundles b on a.bundle_id = b.id
where dn.org_id = 'org-1'
  and dn.user_id = 'user-42'
  and e.bundle_id in (
    select id from bundles where name in ('bundle-1', 'bundle-2')
  )
order by dn.created desc
limit 20;

-- Query 4A: Event log with bundle and application filters (ID-based)
-- Production: EventRepository.addHqlConditions() lines 140-144

\echo ''
\echo '====== QUERY 4A: DENORMALIZED ======'
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
  and e.bundle_id in (
    select id from bundles where name in ('bundle-1', 'bundle-2', 'bundle-3')
  )
  and e.application_id in (
    select id from applications where name in ('app-1', 'app-2', 'app-3', 'app-4')
  )
order by e.created desc
limit 50;

\echo ''
\echo '====== QUERY 4B: NORMALIZED ======'
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
  and e.bundle_id in (
    select id from bundles where name in ('bundle-1', 'bundle-2', 'bundle-3')
  )
  and e.application_id in (
    select id from applications where name in ('app-1', 'app-2', 'app-3', 'app-4')
  )
order by e.created desc
limit 50;

-- Query 5A: Date range with severity filter
-- Production: EventRepository.addHqlConditions() with severity + date range

\echo ''
\echo '====== QUERY 5A: DENORMALIZED ======'
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
  and e.created >= now() - interval '7 days'
  and e.severity in ('WARNING', 'CRITICAL')
  and e.has_authorization_criterion = false
order by e.created desc
limit 100;

\echo ''
\echo '====== QUERY 5B: NORMALIZED ======'
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
  and e.created >= now() - interval '7 days'
  and e.severity in ('WARNING', 'CRITICAL')
  and e.has_authorization_criterion = false
order by e.created desc
limit 100;

-- Query 6A: Sort by application display name
-- Production: Event.SORT_FIELDS line 131 - "application" sorting

\echo ''
\echo '====== QUERY 6A: DENORMALIZED ======'
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
order by e.application_display_name, e.created desc
limit 100;

\echo ''
\echo '====== QUERY 6B: NORMALIZED ======'
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
order by a.display_name, e.created desc
limit 100;

-- Query 7A: Drawer with event type filter
-- Production: DrawerNotificationRepository with eventTypeIds filter

\echo ''
\echo '====== QUERY 7A: DENORMALIZED ======'
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
\echo '====== QUERY 7B: NORMALIZED ======'
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

-- Query 8A: Count events by bundle with filters
-- Production: EventRepository.count() line 85

\echo ''
\echo '====== QUERY 8A: DENORMALIZED ======'
explain (analyze, buffers, verbose)
select
    e.bundle_display_name,
    count(*) as event_count
from event e
where e.org_id = 'org-2'
  and e.created >= now() - interval '30 days'
  and e.severity in ('INFO', 'WARNING')
group by e.bundle_display_name
order by event_count desc;

\echo ''
\echo '====== QUERY 8B: NORMALIZED ======'
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
  and e.severity in ('INFO', 'WARNING')
group by b.display_name
order by event_count desc;

-- ==================================================================================
-- SECTION B: SECONDARY PRODUCTION QUERIES
-- ==================================================================================
-- Less frequently used production patterns

-- Query 9A: Sort by bundle display name
-- Production: Event.SORT_FIELDS bundle sorting

\echo ''
\echo '====== QUERY 9A: DENORMALIZED ======'
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
\echo '====== QUERY 9B: NORMALIZED ======'
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

-- Query 10A: Severity filter only
-- Production: EventRepository severities filter (usually combined with date)

\echo ''
\echo '====== QUERY 10A: DENORMALIZED ======'
explain (analyze, buffers, verbose)
select
    e.id,
    e.created,
    e.bundle_display_name,
    e.application_display_name,
    e.event_type_display_name,
    e.severity
from event e
where e.org_id = 'org-4'
  and e.severity in ('WARNING', 'CRITICAL')
order by e.created desc
limit 100;

\echo ''
\echo '====== QUERY 10B: NORMALIZED ======'
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
where e.org_id = 'org-4'
  and e.severity in ('WARNING', 'CRITICAL')
order by e.created desc
limit 100;

-- ==================================================================================
-- SECTION C: STRESS TESTS & EDGE CASES
-- ==================================================================================
-- Synthetic queries to test optimizer behavior (not production patterns)

-- Query 11A: Multiple display name filters (SYNTHETIC - not used in production)
-- Production uses ID-based filtering, not display name IN clauses

\echo ''
\echo '====== QUERY 11A: DENORMALIZED (STRESS TEST) ======'
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
\echo '====== QUERY 11B: NORMALIZED (STRESS TEST) ======'
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

-- Query 12A: Deep join chain with complex sorting (STRESS TEST)
-- Tests worst-case join performance with multiple ORDER BY columns

\echo ''
\echo '====== QUERY 12A: DENORMALIZED (STRESS TEST) ======'
explain (analyze, buffers, verbose)
select
    e.id,
    e.created,
    e.bundle_display_name,
    e.application_display_name,
    e.event_type_display_name,
    e.severity
from event e
where e.org_id = 'org-5'
  and e.created >= now() - interval '14 days'
order by e.bundle_display_name, e.application_display_name, e.event_type_display_name, e.created desc
limit 100;

\echo ''
\echo '====== QUERY 12B: NORMALIZED (STRESS TEST) ======'
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
where e.org_id = 'org-5'
  and e.created >= now() - interval '14 days'
order by b.display_name, a.display_name, et.display_name, e.created desc
limit 100;