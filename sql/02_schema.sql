create database if not exists `eshop`
	default character set utf8mb4
	default collate utf8mb4_0900_ai_ci;

use `eshop`;

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