-- ============================================================
-- 00b_env_check_round2.sql  —  配置文件里写的 vs 实际生效的
--                             my.ini vs EFFECTIVE (runtime) values
-- 项目 mysql-dba-portfolio，环境清点第二步
--
-- 为什么要写这个脚本
--   第一轮查出 my.ini 和运行中的服务器会对不上：my.ini 第 271 行写着
--   innodb_buffer_pool_instances=8，运行时实际是 1，错误日志里连告警都没有。
--   所以做参数审计时，唯一可信的来源是运行时值——配置文件是"请求"，不是"事实"。
--   这个脚本把 my.ini 里设过的每一项，实际生效值全列出来。
--
-- 怎么跑：
--   cmd /c "mysql -h 127.0.0.1 -P 3306 -u root -p --default-character-set=utf8mb4 -t < D:\mysql-dba-portfolio\sql\00b_env_check_round2.sql"
-- ============================================================


-- 1) my.ini 里设过的每一项，实际生效值是什么 / effective values ----------
SELECT VARIABLE_NAME AS vname, VARIABLE_VALUE AS vval
FROM performance_schema.global_variables
WHERE VARIABLE_NAME IN (
  -- 路径与身份 / paths & identity
  'datadir', 'basedir', 'port', 'server_id', 'hostname',
  -- 日志 / logging
  'log_output', 'general_log', 'general_log_file',
  'slow_query_log', 'slow_query_log_file', 'long_query_time',
  'log_queries_not_using_indexes', 'min_examined_row_limit',
  'log_error', 'log_bin', 'log_bin_basename', 'binlog_expire_logs_seconds',
  -- SQL 模式与字符集 / sql & charset
  'sql_mode', 'character_set_server', 'collation_server',
  'default_storage_engine', 'lower_case_table_names',
  'transaction_isolation', 'secure_file_priv', 'max_allowed_packet',
  -- 连接与表缓存 / connections & tables
  'max_connections', 'max_connect_errors', 'table_open_cache', 'open_files_limit',
  -- 临时表 / temp tables
  'tmp_table_size', 'max_heap_table_size', 'temptable_max_ram', 'temptable_max_mmap',
  'internal_tmp_mem_storage_engine',
  -- 每连接缓冲区 / per-connection buffers
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


-- 2) 缓冲池算术校验 / buffer-pool arithmetic check ----------------------
--    缓冲池字节数 ÷ 页大小，应当等于第一轮查到的页总数 8192
SELECT @@innodb_buffer_pool_size / @@innodb_page_size AS computed_pages,
       @@innodb_buffer_pool_size / 1048576             AS pool_mib,
       @@innodb_page_size                              AS page_bytes,
       @@innodb_buffer_pool_instances                  AS pool_instances;


-- 3) 慢日志：空了是不是只因为阈值太高 / is the threshold the only reason --
SELECT @@slow_query_log                   AS slow_log_on,
       @@long_query_time                  AS threshold_sec,
       @@log_queries_not_using_indexes    AS log_no_index,
       @@min_examined_row_limit           AS min_rows,
       (SELECT VARIABLE_VALUE + 0 FROM performance_schema.global_status
        WHERE VARIABLE_NAME = 'Slow_queries') AS slow_queries_count,
       @@slow_query_log_file              AS slow_log_file;
