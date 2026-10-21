-- ============================================================
-- 04_queries.sql  —  实3：业务查询与「有索引 / 没索引」对比
--
-- 执行（不要加 -t：EXPLAIN ANALYZE 是树形输出，加了 -t 边框会错位）：
--   cmd /c "mysql -h 127.0.0.1 -P 3306 -u root -p --default-character-set=utf8mb4 < D:\mysql-dba-portfolio\sql\04_queries.sql > D:\mysql-dba-portfolio\evidence\04-queries-output.txt"
--
-- 实测结论（2026-10-22，原始输出见 evidence/04-queries-output.txt）：
--   走索引   0.188 ms，读 20 行
--   全表扫描 6.5   ms，读 20000 行后排序
--   约 35 倍差距
-- ============================================================

use `eshop`;


-- ---------------------------------------------------------------
-- 第一步：下单最多的前 5 个客户
-- 用途：挑一个订单量够大的客户，让后面的差异更明显
-- 实测：customer_id = 1 有 534 笔，是第 2 名（317 笔）的 1.7 倍
-- ---------------------------------------------------------------
select customer_id, count(*) as order_cnt
from t_order
group by customer_id
order by order_cnt desc
limit 5;


-- ---------------------------------------------------------------
-- 第二步：客户 1 的最近 20 笔订单 —— 正常走索引
-- 预期：Index lookup ... (reverse)，只读 20 行就停
-- ---------------------------------------------------------------
explain analyze
select id, order_no, order_amount, create_time
from t_order
where customer_id = 1 and deleted = 0
order by create_time desc
limit 20;


-- ---------------------------------------------------------------
-- 第三步：同一个查询，让优化器装作没有这个索引
-- 预期：Table scan on t_order + Sort，把 20000 行读满
-- ---------------------------------------------------------------
explain analyze
select id, order_no, order_amount, create_time
from t_order ignore index (idx_customer_deleted_ct)
where customer_id = 1 and deleted = 0
order by create_time desc
limit 20;
