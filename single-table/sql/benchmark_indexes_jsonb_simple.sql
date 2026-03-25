-- Benchmark script for testing different index scenarios on drawer_notification_jsonb_simple
-- Run each scenario separately to compare performance

\o benchmark_indexes_jsonb_simple_results.txt

-- Helper function to drop all test indexes
create or replace function drop_all_test_indexes_jsonb_simple() returns void as $$
begin
    drop index if exists ix_drawer_notification_jsonb_simple_org_id;
    drop index if exists ix_drawer_notification_jsonb_simple_user_ids_gin;
    drop index if exists ix_drawer_notification_jsonb_simple_user_ids_gin_path_ops;
    drop index if exists ix_drawer_notification_jsonb_simple_org_user_ids_gin;
    drop index if exists ix_drawer_notification_jsonb_simple_created;
    drop index if exists ix_drawer_notification_jsonb_simple_org_created;
end;
$$ language plpgsql;

-- =====================================================
-- Scenario 1: No additional indexes (baseline)
-- =====================================================
select drop_all_test_indexes_jsonb_simple();
vacuum analyze drawer_notification_jsonb_simple;

\qecho '=== Scenario 1: Baseline (PK only) ==='
\qecho 'Query: Find events for org where user-50 exists in user_ids array'
explain (analyze, buffers)
select * from drawer_notification_jsonb_simple
where org_id = 'org-5'
and user_ids @> '["user-50"]'::jsonb;

\qecho '=== Scenario 1: Done'
\qecho ''

-- =====================================================
-- Scenario 2: B-tree index on org_id
-- =====================================================
select drop_all_test_indexes_jsonb_simple();
create index ix_drawer_notification_jsonb_simple_org_id on drawer_notification_jsonb_simple using btree (org_id);
vacuum analyze drawer_notification_jsonb_simple;

\qecho '=== Scenario 2: B-tree on org_id ==='
\qecho 'Query: Find events for org where user-50 exists in user_ids array'
explain (analyze, buffers)
select * from drawer_notification_jsonb_simple
where org_id = 'org-5'
and user_ids @> '["user-50"]'::jsonb;

\qecho '=== Scenario 2: Done'
\qecho ''

-- =====================================================
-- Scenario 3: GIN index on user_ids (default jsonb_ops)
-- =====================================================
select drop_all_test_indexes_jsonb_simple();
create index ix_drawer_notification_jsonb_simple_user_ids_gin on drawer_notification_jsonb_simple using gin (user_ids);
vacuum analyze drawer_notification_jsonb_simple;

\qecho '=== Scenario 3: GIN on user_ids (jsonb_ops) ==='
\qecho 'Query: Find events for org where user-50 exists in user_ids array'
explain (analyze, buffers)
select * from drawer_notification_jsonb_simple
where org_id = 'org-5'
and user_ids @> '["user-50"]'::jsonb;

\qecho '=== Scenario 3: Done'
\qecho ''

-- =====================================================
-- Scenario 4: GIN index on user_ids (jsonb_path_ops)
-- =====================================================
select drop_all_test_indexes_jsonb_simple();
create index ix_drawer_notification_jsonb_simple_user_ids_gin_path_ops on drawer_notification_jsonb_simple using gin (user_ids jsonb_path_ops);
vacuum analyze drawer_notification_jsonb_simple;

\qecho '=== Scenario 4: GIN on user_ids (jsonb_path_ops) ==='
\qecho 'Query: Find events for org where user-50 exists in user_ids array'
explain (analyze, buffers)
select * from drawer_notification_jsonb_simple
where org_id = 'org-5'
and user_ids @> '["user-50"]'::jsonb;

\qecho '=== Scenario 4: Done'
\qecho ''

-- =====================================================
-- Scenario 5: B-tree on org_id + GIN on user_ids
-- =====================================================
select drop_all_test_indexes_jsonb_simple();
create index ix_drawer_notification_jsonb_simple_org_id on drawer_notification_jsonb_simple using btree (org_id);
create index ix_drawer_notification_jsonb_simple_user_ids_gin on drawer_notification_jsonb_simple using gin (user_ids);
vacuum analyze drawer_notification_jsonb_simple;

\qecho '=== Scenario 5: B-tree on org_id + GIN on user_ids ==='
\qecho 'Query: Find events for org where user-50 exists in user_ids array'
explain (analyze, buffers)
select * from drawer_notification_jsonb_simple
where org_id = 'org-5'
and user_ids @> '["user-50"]'::jsonb;

\qecho '=== Scenario 5: Done'
\qecho ''

-- =====================================================
-- Scenario 6: B-tree on org_id + GIN on user_ids (path_ops)
-- =====================================================
select drop_all_test_indexes_jsonb_simple();
create index ix_drawer_notification_jsonb_simple_org_id on drawer_notification_jsonb_simple using btree (org_id);
create index ix_drawer_notification_jsonb_simple_user_ids_gin_path_ops on drawer_notification_jsonb_simple using gin (user_ids jsonb_path_ops);
vacuum analyze drawer_notification_jsonb_simple;

\qecho '=== Scenario 6: B-tree on org_id + GIN on user_ids (path_ops) ==='
\qecho 'Query: Find events for org where user-50 exists in user_ids array'
explain (analyze, buffers)
select * from drawer_notification_jsonb_simple
where org_id = 'org-5'
and user_ids @> '["user-50"]'::jsonb;

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
select * from drawer_notification_jsonb_simple
where org_id = 'org-5';

\qecho ''
\qecho 'Query: Count events per org where specific user exists'
explain (analyze, buffers)
select org_id, count(*)
from drawer_notification_jsonb_simple
where user_ids @> '["user-50"]'::jsonb
group by org_id;

\qecho ''
\qecho 'Query: Find events for multiple users (OR condition)'
explain (analyze, buffers)
select * from drawer_notification_jsonb_simple
where org_id = 'org-5'
and (user_ids @> '["user-50"]'::jsonb or user_ids @> '["user-51"]'::jsonb);

\qecho ''
\qecho '=== Additional query patterns: Done'
\qecho ''

-- Cleanup
select drop_all_test_indexes_jsonb_simple();
drop function drop_all_test_indexes_jsonb_simple();

\o
\qecho 'Results written to benchmark_indexes_jsonb_simple_results.txt'
