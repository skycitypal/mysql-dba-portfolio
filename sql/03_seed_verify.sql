-- ============================================================
-- 03_seed_verify.sql  —  造数之后的验证
--
-- 执行（先跑 03_seed_data.sql 灌数据，再跑这个）：
--   cmd /c "mysql -t -h 127.0.0.1 -P 3306 -u root -p --default-character-set=utf8mb4 < D:\mysql-dba-portfolio\sql\03_seed_verify.sql > D:\mysql-dba-portfolio\evidence\03-seed-verify-output.txt"
--
-- 注意 `-t`：强制输出成带边框的表格。不加的话是制表符分隔，
-- 列一多就错位，肉眼很难对上是哪一列。
-- 例外：`EXPLAIN FORMAT=TREE` 的输出里带换行，加 `-t` 反而会把边框算歪，
-- 那种查询不要加 `-t`（见 docs/课程/01-索引.md 的 U1 复盘）。
-- ============================================================

use `eshop`;

-- 1) 各表行数
select 't_customer' as tbl, count(*) as cnt from t_customer
union all
select 't_product',  count(*) from t_product
union all
select 't_order',    count(*) from t_order
union all
select 't_order_item', count(*) from t_order_item
union all
select 't_payment',  count(*) from t_payment;


-- 2) 让 InnoDB 重新采样索引统计信息
--    刚灌完数据时 Cardinality 还是旧值（甚至是 0），因为统计不是实时更新的。
--    ANALYZE TABLE 会立刻重新采样，Cardinality 才反映真实数据。
analyze table t_customer, t_product, t_order, t_order_item, t_payment;


-- 3) 每个索引的 Cardinality
select table_name, index_name, seq_in_index, column_name, cardinality
from information_schema.statistics
where table_schema = 'eshop'
order by table_name, index_name, seq_in_index;


-- 4) 订单数据的时间跨度
select min(create_time) as earliest,
       max(create_time) as latest,
       count(*)        as cnt
from t_order;
