-- ============================================================
-- 02_schema.sql  —  业务库 eshop 的建表脚本
--
-- 用途：从零建出整个库。别人 clone 下来跑一遍就有全部表。
--
-- 执行：
--   cmd /c "mysql -h 127.0.0.1 -P 3306 -u root -p --default-character-set=utf8mb4 < D:\mysql-dba-portfolio\sql\02_schema.sql"
--
-- 这份脚本可以重复执行：先删表再建。注意这会清空这几张表的数据，
-- 等实2 造完数据之后就不要随手重跑了。
-- ============================================================

create database if not exists `eshop`
	default character set utf8mb4
	default collate utf8mb4_0900_ai_ci;

use `eshop`;

-- 删表顺序：先子表、后父表。目前还没有外键，这个顺序只是习惯，
-- 等以后加了外键就必须遵守。
drop table if exists `t_payment`;
drop table if exists `t_order_item`;
drop table if exists `t_order`;
drop table if exists `t_product`;
drop table if exists `t_customer`;


-- ---------------------------------------------------------------
-- 表 1 / 5：客户
-- ---------------------------------------------------------------
create table `t_customer`(
	`id` bigint not null auto_increment comment '主键 ID',
	`customer_login_name` varchar(50) not null comment '客户登录名',
	`customer_name` varchar(50) comment '客户昵称',
	`customer_email` varchar(128) comment '客户邮箱',
	`status` tinyint not null default 0 comment '状态: 0-正常, 1-禁用',
	`deleted` tinyint not null default 0 comment '删除标记: 0-未删除, 1-已删除',
	`create_time` timestamp(6) not null default current_timestamp(6) comment '创建时间',
	`update_time` timestamp(6) not null default current_timestamp(6) on update current_timestamp(6) comment '更新时间',

	primary key (`id`), unique key `uk_customer_login_name` (`customer_login_name`)
) engine = innodb default charset=utf8mb4 comment='客户表';


-- ---------------------------------------------------------------
-- 表 2 / 5：商品
-- ---------------------------------------------------------------
create table `t_product`(
	`id` bigint not null auto_increment comment '主键ID',
	`product_no` varchar(64) not null comment '商品编号',
	`product_name` varchar(200) not null comment '商品名称',
	`product_price` decimal(10,2) not null comment '商品价格',
	`product_stock` int unsigned not null default 0 comment '商品库存',
	`status` tinyint not null default 0 comment '商品状态:0-下架,1-上架',
	`deleted` tinyint not null default 0 comment '删除标记:0-未删除,1-已删除',
	`create_time` timestamp(6) not null default current_timestamp(6) comment '创建时间',
	`update_time` timestamp(6) not null default current_timestamp(6) on update current_timestamp(6) comment '更新时间',

	primary key (`id`), unique key `uk_product_no` (`product_no`)
) engine = innodb default charset = utf8mb4 comment = '商品表';


-- ---------------------------------------------------------------
-- 表 3 / 5：订单
-- ---------------------------------------------------------------
create table `t_order`(
	`id` bigint not null auto_increment comment '主键ID',
	`order_id` varchar(64) not null comment '业务单号',
	`customer_id` bigint not null comment '客户ID',
	`order_amount` decimal(10,2) not null comment '订单总额',
	`status` tinyint not null default 0 comment '订单状态:0-待支付,1-已支付,2-已发货,3-已完成,4-已取消',
	`pay_time` timestamp(6) default null comment '支付时间, 未支付时为 NULL',
	`deleted` tinyint not null default 0 comment '删除标记:0-未删除,1-已删除',
	`create_time` timestamp(6) not null default current_timestamp(6) comment '创建时间',
	`update_time` timestamp(6) not null default current_timestamp(6) on update current_timestamp(6) comment '更新时间',
	
	primary key (`id`),
	unique key `uk_order_id` (`order_id`),
	key `idx_customer_deleted_ct` (`customer_id`, `deleted`, `create_time`)
) engine = innodb default charset = utf8mb4 comment = '订单表';
