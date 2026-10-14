-- ============================================================
-- 00b_env_check_round2.sql  —  my.ini  vs  EFFECTIVE (runtime) values
-- Project: mysql-dba-portfolio        Day 1 / step D1-1 (round 2)
--
-- WHY THIS EXISTS
--   Round 1 proved that my.ini and the running server can DISAGREE:
--   my.ini line 271 says innodb_buffer_pool_instances=8, but the runtime
--   value is 1. A parameter audit must therefore always read the RUNTIME
--   values; the config file is a request, not the truth.
--   This script dumps the effective value of every parameter my.ini sets.
--
-- Run:
--   cmd /c "mysql -h 127.0.0.1 -P 3306 -u root -p --default-character-set=utf8mb4 -t < D:\mysql-dba-portfolio\sql\00b_env_check_round2.sql"
-- ============================================================


-- 1) effective value of every parameter that my.ini sets -----------------
SELECT VARIABLE_NAME AS vname, VARIABLE_VALUE AS vval
FROM performance_schema.global_variables
WHERE VARIABLE_NAME IN (
  -- paths / identity
  'datadir', 'basedir', 'port', 'server_id', 'hostname',
  -- logging
  'log_output', 'general_log', 'general_log_file',
  'slow_query_log', 'slow_query_log_file', 'long_query_time',
  'log_queries_not_using_indexes', 'min_examined_row_limit',
  'log_error', 'log_bin', 'log_bin_basename', 'binlog_expire_logs_seconds',
  -- sql / charset
  'sql_mode', 'character_set_server', 'collation_server',
  'default_storage_engine', 'lower_case_table_names',
  'transaction_isolation', 'secure_file_priv', 'max_allowed_packet',
  -- connections / tables
  'max_connections', 'max_connect_errors', 'table_open_cache', 'open_files_limit',
  -- temp tables
  'tmp_table_size', 'max_heap_table_size', 'temptable_max_ram', 'temptable_max_mmap',
  'internal_tmp_mem_storage_engine',
  -- per-connection buffers
  'join_buffer_size', 'sort_buffer_size', 'read_buffer_size', 'read_rnd_buffer_size',
  -- MyISAM
  'key_buffer_size', 'myisam_sort_buffer_size', 'myisam_max_sort_file_size',
  -- InnoDB
  'innodb_buffer_pool_size', 'innodb_buffer_pool_instances', 'innodb_page_size',
  'innodb_redo_log_capacity', 'innodb_log_buffer_size', 'innodb_flush_log_at_trx_commit',
  'innodb_file_per_table', 'innodb_thread_concurrency', 'innodb_autoextend_increment',
  'innodb_concurrency_tickets', 'innodb_old_blocks_time', 'innodb_stats_on_metadata',
  'innodb_checksum_algorithm', 'flush_time', 'binlog_row_event_max_size',
  'sync_source_info', 'sync_relay_log', 'mysqlx_port')
ORDER BY VARIABLE_NAME;


-- 2) buffer-pool arithmetic check ---------------------------------------
--    pool_bytes / page_bytes must equal Innodb_buffer_pool_pages_total (8192)
SELECT @@innodb_buffer_pool_size / @@innodb_page_size AS computed_pages,
       @@innodb_buffer_pool_size / 1048576             AS pool_mib,
       @@innodb_page_size                              AS page_bytes,
       @@innodb_buffer_pool_instances                  AS pool_instances;


-- 3) slow-query log: is the threshold the only reason it is empty? -------
SELECT @@slow_query_log                   AS slow_log_on,
       @@long_query_time                  AS threshold_sec,
       @@log_queries_not_using_indexes    AS log_no_index,
       @@min_examined_row_limit           AS min_rows,
       (SELECT VARIABLE_VALUE + 0 FROM performance_schema.global_status
        WHERE VARIABLE_NAME = 'Slow_queries') AS slow_queries_count,
       @@slow_query_log_file              AS slow_log_file;
