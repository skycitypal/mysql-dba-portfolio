-- ============================================================
-- 00_env_check.sql  —  MySQL environment inventory (READ-ONLY)
-- Project: mysql-dba-portfolio        Day 1 / step D1-1
--
-- Run (PowerShell, byte-exact input redirection):
--   cmd /c "mysql -h 127.0.0.1 -P 3306 -u root -p --default-character-set=utf8mb4 -t < D:\mysql-dba-portfolio\sql\00_env_check.sql"
--
-- Run (PowerShell native, stdin pipe):
--   Get-Content -Raw D:\mysql-dba-portfolio\sql\00_env_check.sql | mysql -h 127.0.0.1 -P 3306 -u root -p --default-character-set=utf8mb4 -t
--
-- NOTE ON ALIASES: every column/table alias here is deliberately NOT a
-- MySQL reserved word. `FROM (...) reads` is a syntax error (ERROR 1064)
-- on modern MySQL because `READS` is a keyword. Verify on your own server:
--   SELECT WORD, RESERVED FROM information_schema.KEYWORDS
--   WHERE WORD IN ('READS','R','Q','VAR','VNAME','DB');
-- When in doubt, rename the alias or backtick-quote it.
-- ============================================================


-- 1) version and instance identity -------------------------------------
SELECT VERSION()      AS version,
       @@version_comment AS edition,
       @@hostname     AS host,
       NOW()          AS now_ts;


-- 2) paths and case-sensitivity ----------------------------------------
SELECT @@datadir              AS datadir,
       @@port                 AS port,
       @@lower_case_table_names AS lctn;


-- 3) engine and charset defaults ---------------------------------------
SELECT @@default_storage_engine AS engine,
       @@character_set_server   AS charset,
       @@collation_server       AS collation;


-- 4) key configuration variables ---------------------------------------
SELECT VARIABLE_NAME AS vname, VARIABLE_VALUE AS vval
FROM performance_schema.global_variables
WHERE VARIABLE_NAME IN (
  'innodb_buffer_pool_size', 'innodb_buffer_pool_instances',
  'innodb_redo_log_capacity', 'innodb_flush_log_at_trx_commit',
  'innodb_file_per_table',    'max_connections',
  'slow_query_log',           'long_query_time',
  'log_output',               'log_bin',
  'server_id',                'tmp_table_size',
  'transaction_isolation',    'lower_case_table_names')
ORDER BY VARIABLE_NAME;


-- 5) key runtime status ------------------------------------------------
SELECT VARIABLE_NAME AS vname, VARIABLE_VALUE AS vval
FROM performance_schema.global_status
WHERE VARIABLE_NAME IN (
  'Uptime', 'Threads_connected', 'Threads_running', 'Queries', 'Slow_queries',
  'Innodb_buffer_pool_read_requests', 'Innodb_buffer_pool_reads',
  'Innodb_buffer_pool_pages_total',   'Innodb_buffer_pool_pages_free',
  'Innodb_buffer_pool_pages_dirty')
ORDER BY VARIABLE_NAME;


-- 6) InnoDB buffer pool hit ratio --------------------------------------
--    Higher is better. On a busy OLTP workload < 99% means the pool is too
--    small (data is being served from disk). On a near-empty instance the
--    number is meaningless -- judge it only after seeding real data.
SELECT ROUND(100 * (1 - r.v / q.v), 4) AS buffer_pool_hit_pct
FROM (SELECT VARIABLE_VALUE + 0 AS v FROM performance_schema.global_status
      WHERE VARIABLE_NAME = 'Innodb_buffer_pool_reads') r,
     (SELECT VARIABLE_VALUE + 0 AS v FROM performance_schema.global_status
      WHERE VARIABLE_NAME = 'Innodb_buffer_pool_read_requests') q;


-- 7) data size per schema ----------------------------------------------
SELECT table_schema AS db_name,
       COUNT(*)     AS tbls,
       ROUND(SUM(data_length + index_length) / 1048576, 1) AS size_mb
FROM information_schema.tables
GROUP BY table_schema
ORDER BY size_mb DESC
LIMIT 8;
