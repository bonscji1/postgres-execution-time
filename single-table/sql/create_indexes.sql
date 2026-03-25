-- Scenario 1: No additional indexes (baseline - only PK)
-- drop all indexes below

-- Scenario 2: Single B-tree index on org_id
drop index if exists ix_drawer_notification_org_id;
create index ix_drawer_notification_org_id on drawer_notification using btree (org_id);

-- Scenario 3: Single B-tree index on user_id
drop index if exists ix_drawer_notification_user_id;
create index ix_drawer_notification_user_id on drawer_notification using btree (user_id);

-- Scenario 4: Both single indexes (org_id + user_id separately)
drop index if exists ix_drawer_notification_org_id;
drop index if exists ix_drawer_notification_user_id;
create index ix_drawer_notification_org_id on drawer_notification using btree (org_id);
create index ix_drawer_notification_user_id on drawer_notification using btree (user_id);

-- Scenario 5: Composite B-tree (org_id, user_id)
drop index if exists ix_drawer_notification_org_user;
create index ix_drawer_notification_org_user on drawer_notification using btree (org_id, user_id);

-- Scenario 6: Composite B-tree (user_id, org_id) - reversed order
drop index if exists ix_drawer_notification_user_org;
create index ix_drawer_notification_user_org on drawer_notification using btree (user_id, org_id);

