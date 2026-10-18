-- ============================================================
-- 02_verify.sql  —  建表之后的验证
--
-- 确认库和表都建出来了，列和索引与设计一致。
--
-- 执行（先跑 02_schema.sql 建表，再跑这个）：
--   cmd /c "mysql -h 127.0.0.1 -P 3306 -u root -p --default-character-set=utf8mb4 < D:\mysql-dba-portfolio\sql\02_verify.sql"
-- ============================================================

use `eshop`;

-- 1) 库里有几张表
show tables;


-- 2) 表 1：客户
desc t_customer;
show index from t_customer;


-- 3) 表 2：商品
desc t_product;
show index from t_product;


-- 4) 表 3：订单
desc t_order;
show index from t_order;


-- 5) 表 4：订单明细
desc t_order_item;
show index from t_order_item;
