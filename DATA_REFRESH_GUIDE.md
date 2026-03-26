# Data Refresh Scripts - Usage Guide

These scripts simulate and benchmark the process of maintaining a 15-day rolling window of data by deleting/dropping old records.

## Overview

Both scripts:
1. Keep only the last 14 days of data
2. Benchmark all operations (DELETE/DROP and VACUUM)
3. Output detailed timing metrics to the console

**Note:** DELETE/DROP operations are timed within the script. VACUUM operations are timed by psql's `\timing` feature.

## Single Table Approach

**Location:** `single-table/sql/refresh_data.sql`

**What it does:**
- Deletes rows older than 14 days from all tables using `DELETE` statements
- Runs `VACUUM ANALYZE` on all tables to reclaim disk space
- Times each operation individually

**Run:**
```bash
psql -U postgres -d your_database -f single-table/sql/refresh_data.sql
```

**Optionally save output to file:**
```bash
psql -U postgres -d your_database -f single-table/sql/refresh_data.sql 2>&1 | tee refresh_output.txt
```

## Partitioned Table Approach

**Location:** `partitioned-table/sql/refresh_data.sql`

**What it does:**
- **Day partitioning** (`drawer_notification`): Drops entire partitions older than 14 days (fastest)
- **Org partitioning** (`drawer_notification_org`): Deletes old rows using DELETE (slower than DROP, but benefits from partition pruning)
- Deletes old rows from the `event` table (not partitioned)
- Runs `VACUUM ANALYZE` on tables
- Times each operation individually to compare the three approaches

**Run:**
```bash
psql -U postgres -d your_database -f partitioned-table/sql/refresh_data.sql
```

**Optionally save output to file:**
```bash
psql -U postgres -d your_database -f partitioned-table/sql/refresh_data.sql 2>&1 | tee refresh_output.txt
```

## Simulation Steps

### 1. Set up test data with more than 14 days

Modify your `init()` calls to create data spanning more than 14 days:

**Single table:**
```sql
-- Create 30 days of data
call init(10, 100, 30, 100000);
```

**Partitioned table:**
```sql
-- Create 30 days of data with partitions
call init(10, 100, 30, 100000);
```

### 2. Run the refresh script

This will delete/drop the first 14 days of data (keeping only the last 14 days).

### 3. Compare the results

The scripts will output detailed timing information to the console:

**Single Table Output Example:**
```
INFO:  === Starting Data Refresh (Single Tables) ===
INFO:  Cutoff date: 2026-03-11 10:00:00
INFO:  Current time: 2026-03-26 10:00:00
INFO:
INFO:  Deleting from drawer_notification...
INFO:  Deleted 10000000 rows from drawer_notification in 00:00:05.234
INFO:
INFO:  Deleting from drawer_notification_jsonb...
INFO:  Deleted 1000000 rows from drawer_notification_jsonb in 00:00:02.123
INFO:
INFO:  Deleting from drawer_notification_jsonb_simple...
INFO:  Deleted 1000000 rows from drawer_notification_jsonb_simple in 00:00:01.987
INFO:
INFO:  Deleting from event...
INFO:  Deleted 100000 rows from event in 00:00:03.456
INFO:
INFO:  === Delete Summary ===
INFO:  Total delete time: 00:00:12.800
Time: 12800.234 ms (VACUUM operations follow)
Time: 8123.456 ms
Time: 15456.789 ms
Time: 4789.123 ms
Time: 3234.567 ms
```

**Partitioned Table Output Example:**
```
INFO:  === Starting Data Refresh (Partitioned Tables) ===
INFO:  Cutoff date: 2026-03-11
INFO:  Current time: 2026-03-26 10:00:00
INFO:
INFO:  Dropping old partitions from drawer_notification...
INFO:  Dropped partition: drawer_notification_2026_03_05 (date: 2026-03-05)
INFO:  Dropped partition: drawer_notification_2026_03_06 (date: 2026-03-06)
INFO:  Dropped 15 partitions from drawer_notification in 00:00:00.087
INFO:
INFO:  Deleting from drawer_notification_org (org-partitioned)...
INFO:  Deleted 10000000 rows from drawer_notification_org in 00:00:04.123
INFO:
INFO:  Deleting old events...
INFO:  Deleted 100000 rows from event in 00:00:03.456
INFO:
INFO:  === Delete/Drop Summary ===
INFO:  Execution times:
INFO:    - Drop drawer_notification partitions (day partitioning): 00:00:00.087
INFO:    - Delete from drawer_notification_org (org partitioning): 00:00:04.123
INFO:    - Delete from event (no partitioning): 00:00:03.456
INFO:  Total delete/drop time: 00:00:07.666
INFO:
INFO:  Performance Comparison:
INFO:    Day partitioning (DROP):  00:00:00.087
INFO:    Org partitioning (DELETE): 00:00:04.123
Time: 7666.123 ms (VACUUM follows)
Time: 8123.456 ms
Time: 4521.234 ms
```

## Key Performance Differences

**Three approaches compared:**

1. **Day Partitioning (DROP partitions)** - FASTEST
   - Drops entire partitions (metadata operation, ~milliseconds)
   - No VACUUM needed on partitioned child tables
   - Best for time-series data with natural retention windows

2. **Org Partitioning (DELETE with partition pruning)** - MIDDLE
   - DELETE operations but benefits from partition pruning
   - Only scans partitions that match the WHERE clause
   - Faster than single table, slower than dropping partitions
   - VACUUM needed to reclaim space

3. **Single Table (DELETE, full scan)** - SLOWEST
   - DELETE must scan the entire table
   - No partition pruning benefits
   - VACUUM must scan entire table to reclaim space
   - Total time includes both DELETE and VACUUM overhead

## Benchmarking Tips

1. **Run multiple times** - First run may be slower due to cold caches
2. **Use realistic data volumes** - Scale to match production workloads
3. **Monitor disk I/O** - Use `iostat` or `pg_stat_statements` during execution
4. **Check table sizes before/after** - Use the `relations_size.sql` scripts
5. **Consider autovacuum** - In production, autovacuum may interfere; disable for testing

## Production Considerations

- **Partitioned tables**: Drop partitions during low-traffic periods
- **Single tables**: Use `DELETE` in batches to avoid lock contention
- **Indexes**: More indexes = slower DELETE, faster queries
- **Foreign keys**: CASCADE deletes add overhead (single table approach)

## Quick Test Guide

```bash
# 1. Create 30 days of data (so you have data to delete)
psql -U postgres -d your_database -c "call init(10, 100, 30, 100000);"

# 2. Run single table refresh
psql -U postgres -d your_database -f single-table/sql/refresh_data.sql

# OR run partitioned table refresh
psql -U postgres -d your_database -f partitioned-table/sql/refresh_data.sql

# Optional: Save output to file for comparison
psql -U postgres -d your_database -f single-table/sql/refresh_data.sql 2>&1 | tee single_refresh.txt
psql -U postgres -d your_database -f partitioned-table/sql/refresh_data.sql 2>&1 | tee partitioned_refresh.txt
```

All timing metrics are displayed in the console.
