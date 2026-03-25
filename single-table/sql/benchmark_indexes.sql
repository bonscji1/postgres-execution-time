-- Benchmark script for testing different index scenarios
-- Run each scenario separately to compare performance

\o benchmark_indexes_results.txt

-- Helper function to drop all test indexes
create or replace function drop_all_test_indexes() returns void as $$
begin
    drop index if exists ix_drawer_notification_org_id;
    drop index if exists ix_drawer_notification_user_id;
    drop index if exists ix_drawer_notification_org_user;
    drop index if exists ix_drawer_notification_user_org;
    drop index if exists ix_drawer_notification_org_user_covering;
end;
$$ language plpgsql;

-- Scenario 1: No additional indexes (baseline)
-- =====================================================
select drop_all_test_indexes();
vacuum analyze drawer_notification;

\qecho '=== Scenario 1: Baseline (PK only) ==='
explain (analyze, buffers)
select * from drawer_notification where org_id = 'org-5' and user_id = 'user-50';

\qecho '=== Scenario 1: Done'
\qecho ''

-- =====================================================
-- Scenario 2: Single B-tree index on org_id
-- =====================================================
select drop_all_test_indexes();
create index ix_drawer_notification_org_id on drawer_notification using btree (org_id);
vacuum analyze drawer_notification;

\qecho '=== Scenario 2: Single B-tree on org_id ==='
explain (analyze, buffers)
select * from drawer_notification where org_id = 'org-5' and user_id = 'user-50';

\qecho '=== Scenario 2: Done'
\qecho ''

-- =====================================================
-- Scenario 3: Single B-tree index on user_id
-- =====================================================
select drop_all_test_indexes();
create index ix_drawer_notification_user_id on drawer_notification using btree (user_id);
vacuum analyze drawer_notification;

\qecho '=== Scenario 3: Single B-tree on user_id ==='
explain (analyze, buffers)
select * from drawer_notification where org_id = 'org-5' and user_id = 'user-50';

\qecho '=== Scenario 3: Done'
\qecho ''

-- =====================================================
-- Scenario 4: Both single indexes (org_id + user_id)
-- =====================================================
select drop_all_test_indexes();
create index ix_drawer_notification_org_id on drawer_notification using btree (org_id);
create index ix_drawer_notification_user_id on drawer_notification using btree (user_id);
vacuum analyze drawer_notification;

\qecho '=== Scenario 4: Two separate B-tree indexes (org_id + user_id) ==='
explain (analyze, buffers)
select * from drawer_notification where org_id = 'org-5' and user_id = 'user-50';

\qecho '=== Scenario 4: Done'
\qecho ''

-- =====================================================
-- Scenario 5: Composite B-tree (org_id, user_id)
-- =====================================================
select drop_all_test_indexes();
create index ix_drawer_notification_org_user on drawer_notification using btree (org_id, user_id);
vacuum analyze drawer_notification;

\qecho '=== Scenario 5: Composite B-tree (org_id, user_id) ==='
explain (analyze, buffers)
select * from drawer_notification where org_id = 'org-5' and user_id = 'user-50';

\qecho '=== Scenario 5: Done'
\qecho ''

-- =====================================================
-- Scenario 6: Composite B-tree (user_id, org_id)
-- =====================================================
select drop_all_test_indexes();
create index ix_drawer_notification_user_org on drawer_notification using btree (user_id, org_id);
vacuum analyze drawer_notification;

\qecho '=== Scenario 6: Composite B-tree (user_id, org_id) - reversed ==='
explain (analyze, buffers)
select * from drawer_notification where org_id = 'org-5' and user_id = 'user-50';

\qecho '=== Scenario 6: Done'
\qecho ''

-- Cleanup
select drop_all_test_indexes();
drop function drop_all_test_indexes();

\o
\qecho 'Results written to benchmark_indexes_results.txt'