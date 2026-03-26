-- Benchmark script for drawer_notification partitioned by day
-- Run each scenario separately to compare performance

\o benchmark_indexes_day_results.txt

-- Helper function to drop all test indexes
create or replace function drop_all_test_indexes_day() returns void as $$
begin
    drop index if exists ix_drawer_notification_org_id;
    drop index if exists ix_drawer_notification_user_id;
    drop index if exists ix_drawer_notification_org_user;
    drop index if exists ix_drawer_notification_user_org;
end;
$$ language plpgsql;

-- =====================================================
-- Scenario 1: Baseline (PK only)
-- =====================================================
select drop_all_test_indexes_day();
vacuum analyze drawer_notification;

\qecho '=== Scenario 1: Baseline - drawer_notification (partitioned by day) ==='
\qecho 'Query: Count notifications for org and user'
explain (analyze, buffers)
select count(*) from drawer_notification where org_id = 'org-5' and user_id = 'user-50';

\qecho 'Query: Select notifications for org and user (with LIMIT)'
explain (analyze, buffers)
select * from drawer_notification where org_id = 'org-5' and user_id = 'user-50' order by created desc limit 20;

\qecho '=== Scenario 1: Done'
\qecho ''

-- =====================================================
-- Scenario 2: B-tree index on org_id
-- =====================================================
select drop_all_test_indexes_day();
create index ix_drawer_notification_org_id on drawer_notification using btree (org_id);
vacuum analyze drawer_notification;

\qecho '=== Scenario 2: B-tree on org_id ==='
\qecho 'Query: Count notifications for org and user'
explain (analyze, buffers)
select count(*) from drawer_notification where org_id = 'org-5' and user_id = 'user-50';

\qecho 'Query: Select notifications for org and user (with LIMIT)'
explain (analyze, buffers)
select * from drawer_notification where org_id = 'org-5' and user_id = 'user-50' order by created desc limit 20;

\qecho '=== Scenario 2: Done'
\qecho ''

-- =====================================================
-- Scenario 3: B-tree index on user_id
-- =====================================================
select drop_all_test_indexes_day();
create index ix_drawer_notification_user_id on drawer_notification using btree (user_id);
vacuum analyze drawer_notification;

\qecho '=== Scenario 3: B-tree on user_id ==='
\qecho 'Query: Count notifications for org and user'
explain (analyze, buffers)
select count(*) from drawer_notification where org_id = 'org-5' and user_id = 'user-50';

\qecho 'Query: Select notifications for org and user (with LIMIT)'
explain (analyze, buffers)
select * from drawer_notification where org_id = 'org-5' and user_id = 'user-50' order by created desc limit 20;

\qecho '=== Scenario 3: Done'
\qecho ''

-- =====================================================
-- Scenario 4: Both single indexes (org_id + user_id)
-- =====================================================
select drop_all_test_indexes_day();
create index ix_drawer_notification_org_id on drawer_notification using btree (org_id);
create index ix_drawer_notification_user_id on drawer_notification using btree (user_id);
vacuum analyze drawer_notification;

\qecho '=== Scenario 4: Two separate B-tree indexes (org_id + user_id) ==='
\qecho 'Query: Count notifications for org and user'
explain (analyze, buffers)
select count(*) from drawer_notification where org_id = 'org-5' and user_id = 'user-50';

\qecho 'Query: Select notifications for org and user (with LIMIT)'
explain (analyze, buffers)
select * from drawer_notification where org_id = 'org-5' and user_id = 'user-50' order by created desc limit 20;

\qecho '=== Scenario 4: Done'
\qecho ''

-- =====================================================
-- Scenario 5: Composite B-tree (org_id, user_id)
-- =====================================================
select drop_all_test_indexes_day();
create index ix_drawer_notification_org_user on drawer_notification using btree (org_id, user_id);
vacuum analyze drawer_notification;

\qecho '=== Scenario 5: Composite B-tree (org_id, user_id) ==='
\qecho 'Query: Count notifications for org and user'
explain (analyze, buffers)
select count(*) from drawer_notification where org_id = 'org-5' and user_id = 'user-50';

\qecho 'Query: Select notifications for org and user (with LIMIT)'
explain (analyze, buffers)
select * from drawer_notification where org_id = 'org-5' and user_id = 'user-50' order by created desc limit 20;

\qecho '=== Scenario 5: Done'
\qecho ''

-- =====================================================
-- Scenario 6: Composite B-tree (user_id, org_id)
-- =====================================================
select drop_all_test_indexes_day();
create index ix_drawer_notification_user_org on drawer_notification using btree (user_id, org_id);
vacuum analyze drawer_notification;

\qecho '=== Scenario 6: Composite B-tree (user_id, org_id) - reversed ==='
\qecho 'Query: Count notifications for org and user'
explain (analyze, buffers)
select count(*) from drawer_notification where org_id = 'org-5' and user_id = 'user-50';

\qecho 'Query: Select notifications for org and user (with LIMIT)'
explain (analyze, buffers)
select * from drawer_notification where org_id = 'org-5' and user_id = 'user-50' order by created desc limit 20;

\qecho '=== Scenario 6: Done'
\qecho ''

-- =====================================================
-- Additional query patterns to test partition pruning
-- =====================================================

\qecho '=== Testing additional query patterns ==='

\qecho 'Query: Exact date range - should hit 1 partition'
explain (analyze, buffers)
select * from drawer_notification
where created >= current_date - interval '1 day'
and created < current_date
and org_id = 'org-5' and user_id = 'user-50';

\qecho 'Query: Count by org with date filter'
explain (analyze, buffers)
select org_id, count(*)
from drawer_notification
where created >= current_date - interval '5 days'
group by org_id;

\qecho '=== Additional query patterns: Done'
\qecho ''

-- Cleanup
select drop_all_test_indexes_day();
drop function drop_all_test_indexes_day();

\o
\qecho 'Results written to benchmark_indexes_day_results.txt'
