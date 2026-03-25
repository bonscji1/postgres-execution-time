-- Benchmark script for testing different index scenarios on drawer_notification_jsonb
-- Run each scenario separately to compare performance

\o benchmark_indexes_jsonb_results.txt

-- Helper function to drop all test indexes
create or replace function drop_all_test_indexes_jsonb() returns void as $$
begin
    drop index if exists ix_drawer_notification_jsonb_org_id;
    drop index if exists ix_drawer_notification_jsonb_users_gin;
    drop index if exists ix_drawer_notification_jsonb_users_gin_path_ops;
    drop index if exists ix_drawer_notification_jsonb_org_users_gin;
    drop index if exists ix_drawer_notification_jsonb_created;
    drop index if exists ix_drawer_notification_jsonb_org_created;
end;
$$ language plpgsql;

-- =====================================================
-- Scenario 1: No additional indexes (baseline)
-- =====================================================
select drop_all_test_indexes_jsonb();
vacuum analyze drawer_notification_jsonb;

\qecho '=== Scenario 1: Baseline (PK only) ==='
\qecho 'Query: Find events for org where user-50 exists in users array'
explain (analyze, buffers)
select * from drawer_notification_jsonb
where org_id = 'org-5'
and users @> '[{"user_id": "user-50"}]'::jsonb;

\qecho '=== Scenario 1: Done'
\qecho ''

-- =====================================================
-- Scenario 2: B-tree index on org_id
-- =====================================================
select drop_all_test_indexes_jsonb();
create index ix_drawer_notification_jsonb_org_id on drawer_notification_jsonb using btree (org_id);
vacuum analyze drawer_notification_jsonb;

\qecho '=== Scenario 2: B-tree on org_id ==='
\qecho 'Query: Find events for org where user-50 exists in users array'
explain (analyze, buffers)
select * from drawer_notification_jsonb
where org_id = 'org-5'
and users @> '[{"user_id": "user-50"}]'::jsonb;

\qecho '=== Scenario 2: Done'
\qecho ''

-- =====================================================
-- Scenario 3: GIN index on users (default jsonb_ops)
-- =====================================================
select drop_all_test_indexes_jsonb();
create index ix_drawer_notification_jsonb_users_gin on drawer_notification_jsonb using gin (users);
vacuum analyze drawer_notification_jsonb;

\qecho '=== Scenario 3: GIN on users (jsonb_ops) ==='
\qecho 'Query: Find events for org where user-50 exists in users array'
explain (analyze, buffers)
select * from drawer_notification_jsonb
where org_id = 'org-5'
and users @> '[{"user_id": "user-50"}]'::jsonb;

\qecho '=== Scenario 3: Done'
\qecho ''

-- =====================================================
-- Scenario 4: GIN index on users (jsonb_path_ops)
-- =====================================================
select drop_all_test_indexes_jsonb();
create index ix_drawer_notification_jsonb_users_gin_path_ops on drawer_notification_jsonb using gin (users jsonb_path_ops);
vacuum analyze drawer_notification_jsonb;

\qecho '=== Scenario 4: GIN on users (jsonb_path_ops) ==='
\qecho 'Query: Find events for org where user-50 exists in users array'
explain (analyze, buffers)
select * from drawer_notification_jsonb
where org_id = 'org-5'
and users @> '[{"user_id": "user-50"}]'::jsonb;

\qecho '=== Scenario 4: Done'
\qecho ''

-- =====================================================
-- Scenario 5: B-tree on org_id + GIN on users
-- =====================================================
select drop_all_test_indexes_jsonb();
create index ix_drawer_notification_jsonb_org_id on drawer_notification_jsonb using btree (org_id);
create index ix_drawer_notification_jsonb_users_gin on drawer_notification_jsonb using gin (users);
vacuum analyze drawer_notification_jsonb;

\qecho '=== Scenario 5: B-tree on org_id + GIN on users ==='
\qecho 'Query: Find events for org where user-50 exists in users array'
explain (analyze, buffers)
select * from drawer_notification_jsonb
where org_id = 'org-5'
and users @> '[{"user_id": "user-50"}]'::jsonb;

\qecho '=== Scenario 5: Done'
\qecho ''

-- =====================================================
-- Scenario 6: B-tree on org_id + GIN on users (path_ops)
-- =====================================================
select drop_all_test_indexes_jsonb();
create index ix_drawer_notification_jsonb_org_id on drawer_notification_jsonb using btree (org_id);
create index ix_drawer_notification_jsonb_users_gin_path_ops on drawer_notification_jsonb using gin (users jsonb_path_ops);
vacuum analyze drawer_notification_jsonb;

\qecho '=== Scenario 6: B-tree on org_id + GIN on users (path_ops) ==='
\qecho 'Query: Find events for org where user-50 exists in users array'
explain (analyze, buffers)
select * from drawer_notification_jsonb
where org_id = 'org-5'
and users @> '[{"user_id": "user-50"}]'::jsonb;

\qecho '=== Scenario 6: Done'
\qecho ''

-- =====================================================
-- Additional query patterns to test
-- =====================================================

\qecho ''
\qecho '=== Testing additional query patterns ==='

\qecho ''
\qecho 'Query: Find all events for an org (no JSONB filter)'
explain (analyze, buffers)
select * from drawer_notification_jsonb
where org_id = 'org-5';

\qecho ''
\qecho 'Query: Find events where user has read=false'
explain (analyze, buffers)
select * from drawer_notification_jsonb
where org_id = 'org-5'
and users @> '[{"user_id": "user-50", "read": false}]'::jsonb;

\qecho ''
\qecho 'Query: Count events per org where specific user exists'
explain (analyze, buffers)
select org_id, count(*)
from drawer_notification_jsonb
where users @> '[{"user_id": "user-50"}]'::jsonb
group by org_id;

\qecho ''
\qecho '=== Additional query patterns: Done'
\qecho ''

-- Cleanup
select drop_all_test_indexes_jsonb();
drop function drop_all_test_indexes_jsonb();

\o
\qecho 'Results written to benchmark_indexes_jsonb_results.txt'