-- ============================================================
-- 01_u1_explain.sql  —  索引实操：用 EXPLAIN 看 MySQL 有没有用上索引
-- 配套讲义：../docs/课程/01-索引.md
--
-- 这里用 FORMAT=TRADITIONAL，输出是带 type / key / rows 三列的表格，
-- 和之前跑出来的树格式（TREE）互为对照。
--
-- 用法（PowerShell，输出直接打在屏幕上）：
--   cmd /c "mysql -h 127.0.0.1 -P 3306 -u root -p --default-character-set=utf8mb4 < D:\mysql-dba-portfolio\sql\01_u1_explain.sql"
--
-- 用法（把输出存成文件，注意路径写全、evidence 目录要先存在）：
--   cmd /c "mysql -h 127.0.0.1 -P 3306 -u root -p --default-character-set=utf8mb4 < D:\mysql-dba-portfolio\sql\01_u1_explain.sql > D:\mysql-dba-portfolio\evidence\01-u1-explain-traditional.txt"
--
-- 为什么用文件而不是命令行里塞 -e：见 ../docs/错误与排查记录.md 的 E6。
-- 文件里的引号不需要任何转义，也不会被选项解析器吃掉。
-- ============================================================

-- 表在 sakila 库里，先切过去
USE sakila;

-- 本机 EXPLAIN 的默认格式是什么（新版默认是 TREE）
SELECT @@explain_format AS explain_format_default;

-- 1) 主键等值查询：应该是最快的一档
EXPLAIN FORMAT=TRADITIONAL SELECT * FROM actor WHERE actor_id = 3;

-- 2) 走普通索引：last_name 上有 idx_actor_last_name
EXPLAIN FORMAT=TRADITIONAL SELECT * FROM actor WHERE last_name = 'CHASE';

-- 3) 没有索引的列：应该看到全表扫描
EXPLAIN FORMAT=TRADITIONAL SELECT * FROM actor WHERE first_name = 'ED';
