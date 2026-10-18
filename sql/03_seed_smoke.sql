use `eshop`;

insert into `t_customer` (`customer_login_name`, `customer_name`, `customer_email`, `status`)
values
    ('daofeng', '道峰', 'd@oyiuyi.cn',  0),
    ('yupei',   '玉佩', 'yp@oyiuyi.cn', 0);

insert into `t_product` (`product_no`, `product_name`, `product_price`, `product_stock`, `status`)
values
    ('ck00000', '大肥鱼',   6,    1,    1),
    ('ck00001', '小山猪',   12,   2,    1);

select * from `t_customer`;
select * from `t_product`;