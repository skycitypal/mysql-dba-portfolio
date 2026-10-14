-- ============================================================
-- 00_env_check.sql  —  MySQL 环境清点 / environment inventory
-- 纯只读（READ-ONLY），不会改动任何数据
-- 项目 mysql-dba-portfolio，环境清点的第一步
--
-- 怎么跑（PowerShell，把文件原样喂给客户端）：
--   cmd /c "mysql -h 127.0.0.1 -P 3306 -u root -p --default-character-set=utf8mb4 -t < D:\mysql-dba-portfolio\sql\00_env_check.sql"
--
-- 也可以用 PowerShell 管道：
--   Get-Content -Raw D:\mysql-dba-portfolio\sql\00_env_check.sql | mysql -h 127.0.0.1 -P 3306 -u root -p --default-character-set=utf8mb4 -t
--
-- 关于别名的说明 / NOTE ON ALIASES
--   这里所有别名都刻意避开了 MySQL 保留字。
--   `FROM (...) reads` 在较新的 MySQL 上会语法报错（ERROR 1064），因为 READS 是关键字。
--   想在自己服务器上确认保留字，不用翻文档，直接查：
--     SELECT WORD, RESERVED FROM information_schema.KEYWORDS
--     WHERE WORD IN ('READS','R','Q','VAR','VNAME','DB');
--   拿不准就换个别名，或者用反引号包起来。
-- ============================================================


-- 1) 版本与实例身份 / version and instance identity ---------------------
SELECT VERSION()      AS version,
       @@version_comment AS edition,
       @@hostname     AS host,
       NOW()          AS now_ts;


-- 2) 数据目录与表名大小写 / paths and case-sensitivity -------------------
SELECT @@datadir              AS datadir,
       @@port                 AS port,
       @@lower_case_table_names AS lctn;


-- 3) 默认存储引擎与字符集 / engine and charset defaults ------------------
SELECT @@default_storage_engine AS engine,
       @@character_set_server   AS charset,
       @@collation_server       AS collation;


-- 4) 关键配置参数 / key configuration variables -------------------------
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


-- 5) 关键运行状态 / key runtime status ----------------------------------
SELECT VARIABLE_NAME AS vname, VARIABLE_VALUE AS vval
FROM performance_schema.global_status
WHERE VARIABLE_NAME IN (
  'Uptime', 'Threads_connected', 'Threads_running', 'Queries', 'Slow_queries',
  'Innodb_buffer_pool_read_requests', 'Innodb_buffer_pool_reads',
  'Innodb_buffer_pool_pages_total',   'Innodb_buffer_pool_pages_free',
  'Innodb_buffer_pool_pages_dirty')
ORDER BY VARIABLE_NAME;


-- 6) InnoDB 缓冲池命中率 / buffer pool hit ratio ------------------------
--    越高越好。繁忙的 OLTP 场景里低于 99%，说明缓冲池偏小，数据得从磁盘读。
--    但空载实例上这个数字没有意义——先把真实数据造出来，再看它。
SELECT ROUND(100 * (1 - r.v / q.v), 4) AS buffer_pool_hit_pct
FROM (SELECT VARIABLE_VALUE + 0 AS v FROM performance_schema.global_status
      WHERE VARIABLE_NAME = 'Innodb_buffer_pool_reads') r,
     (SELECT VARIABLE_VALUE + 0 AS v FROM performance_schema.global_status
      WHERE VARIABLE_NAME = 'Innodb_buffer_pool_read_requests') q;


-- 7) 各库数据量 / data size per schema ----------------------------------
SELECT table_schema AS db_name,
       COUNT(*)     AS tbls,
       ROUND(SUM(data_length + index_length) / 1048576, 1) AS size_mb
FROM information_schema.tables
GROUP BY table_schema
ORDER BY size_mb DESC
LIMIT 8;
