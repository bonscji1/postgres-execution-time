-- Test query: SELECT * FROM drawer_notification WHERE org_id = 'org-X' AND user_id = 'user-Y'

explain (analyze, buffers, verbose)
select *
from drawer_notification
where org_id = 'org-5' and user_id = 'user-50';

-- Variation: with ORDER BY created DESC
explain (analyze, buffers, verbose)
select *
from drawer_notification
where org_id = 'org-5' and user_id = 'user-50'
order by created desc;

-- Variation: counting matching rows
explain (analyze, buffers, verbose)
select count(*)
from drawer_notification
where org_id = 'org-5' and user_id = 'user-50';

-- Variation: selecting specific columns (not *)
explain (analyze, buffers, verbose)
select event_id, read, created
from drawer_notification
where org_id = 'org-5' and user_id = 'user-50';
