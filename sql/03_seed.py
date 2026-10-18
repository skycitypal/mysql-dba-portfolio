#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""生成 eshop 库的测试数据。

产出 sql/03_seed_data.sql（几十 MB，不入库，见 .gitignore）。

用法：
    python sql/03_seed.py
    cmd /c "mysql -h 127.0.0.1 -P 3306 -u root -p --default-character-set=utf8mb4 < D:\\mysql-dba-portfolio\\sql\\03_seed_data.sql"

设计要点（为什么这么造）：

1. create_time 显式写入。表给了 DEFAULT CURRENT_TIMESTAMP，如果不管它，
   几万行会全挤在同一秒，索引页堆在一起，测出来的性能和真实场景不符。
2. 金额对得上。t_order.order_amount = 明细 sum(product_price*quantity)；
   t_payment.amount = 订单金额。造出对不上的数据，后面汇总查询会算出怪结果。
3. 分布偏斜。少数客户下大量单、少数商品是爆款。均匀分布测不出索引的真实效果。
4. 先 TRUNCATE 全部表（子表在前），AUTO_INCREMENT 归零，这样主键可预测，
   关联字段直接按 1..N 生成，不用回查。
"""

import os
import random
import datetime as dt

random.seed(20261019)

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
OUT_PATH = os.path.join(BASE_DIR, '03_seed_data.sql')

# ---------------------------------------------------------------- 规模
N_CUSTOMER = 5000
N_PRODUCT = 1000
N_ORDER = 20000
BATCH = 500          # 每条 INSERT 带多少行

NOW = dt.datetime(2026, 10, 19, 0, 0, 0)
START = NOW - dt.timedelta(days=730)    # 数据铺在过去两年

# ---------------------------------------------------------------- 词库
SURNAME = list('赵钱孙李周吴郑王冯陈褚卫蒋沈韩杨朱秦尤许何吕施张孔曹严华金魏陶姜')
GIVEN = ['伟', '芳', '娜', '敏', '静', '丽', '强', '磊', '洋', '勇', '艳', '杰',
         '娟', '涛', '明', '超', '秀英', '霞', '平', '刚', '桂英', '建国', '春梅']
DOMAINS = ['example.com', 'oyiuyi.cn', 'mail.test', 'shop.demo']

P_ADJ = ['大', '小', '迷你', '经典', '升级', '限定', '纯棉', '加厚', '轻便', '复古', '双肩', '折叠']
P_NOUN = ['肥鱼', '山猪', '礼盒', '茶杯', '背包', '水壶', '抱枕', '台灯', '耳机', '手套',
          '围巾', '笔记本', '雨伞', '钱包', '拖鞋', '收纳箱', '充电宝', '马克杯']

# 订单状态权重：多数已完成，少量待支付/取消
ORDER_STATUS = ([0, 1, 2, 3, 4], [5, 8, 12, 70, 5])
# 每单几件商品
ITEM_COUNT = ([1, 2, 3, 4, 5], [20, 30, 25, 15, 10])


def ts(d):
    """把 datetime 写成 MySQL 认的字符串。"""
    return d.strftime('%Y-%m-%d %H:%M:%S')


def q(v):
    """把 Python 值转成 SQL 字面量。"""
    if v is None:
        return 'NULL'
    if isinstance(v, str):
        return "'" + v.replace('\\', '\\\\').replace("'", "''") + "'"
    if isinstance(v, dt.datetime):
        return "'" + ts(v) + "'"
    return str(v)


def weighted_picker(population, weights):
    """返回一个无参函数，每次调用按权重抽一个元素。

    预先把累积权重算好，避免每次调用都重算（random.choices 每次都要 O(n)）。
    """
    cum = []
    total = 0
    for w in weights:
        total += w
        cum.append(total)
    import bisect

    def pick():
        x = random.random() * total
        return population[bisect.bisect_right(cum, x)]

    return pick


class Writer(object):
    """按表攒行，攒够 BATCH 就吐一条 INSERT。"""

    def __init__(self, fh):
        self.fh = fh
        self.rows = 0
        self.buf = []
        self.cols = None
        self.table = None

    def begin(self, table, cols):
        self.flush()
        self.table = table
        self.cols = cols
        self.buf = []
        self.rows = 0        # 换表要归零，否则统计会累加到上一张表上

    def add(self, values):
        self.buf.append('(' + ', '.join(q(v) for v in values) + ')')
        if len(self.buf) >= BATCH:
            self.flush()

    def flush(self):
        if not self.buf:
            return
        col_list = ', '.join('`%s`' % c for c in self.cols)
        self.fh.write('insert into `%s` (%s) values\n%s;\n'
                      % (self.table, col_list, ',\n'.join(self.buf)))
        self.rows += len(self.buf)
        self.buf = []


def main():
    pick_order_status = weighted_picker(*ORDER_STATUS)
    pick_item_count = weighted_picker(*ITEM_COUNT)

    # ---- 先算好偏斜分布：客户 / 商品的下标权重 ----
    # 排前面的抽中概率高，模拟「少数客户下大量单」「少数商品是爆款」
    cust_weights = [1.0 / (i ** 0.7) for i in range(1, N_CUSTOMER + 1)]
    prod_weights = [1.0 / (i ** 0.9) for i in range(1, N_PRODUCT + 1)]
    pick_customer = weighted_picker(list(range(1, N_CUSTOMER + 1)), cust_weights)
    pick_product = weighted_picker(list(range(1, N_PRODUCT + 1)), prod_weights)

    # ---- 商品：编号、名称、单价一次定好，明细要拿它做快照 ----
    products = {}
    used_no = set()
    for pid in range(1, N_PRODUCT + 1):
        while True:
            no = 'SP%06d' % random.randint(0, 999999)
            if no not in used_no:
                used_no.add(no)
                break
        name = random.choice(P_ADJ) + random.choice(P_NOUN)
        price = round(random.choice([6, 9, 12, 19, 29, 39, 59, 99, 129, 199])
                      * random.uniform(0.85, 1.15), 2)
        products[pid] = (no, name, price)

    stats = {}

    with open(OUT_PATH, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write('-- 由 sql/03_seed.py 生成，请勿手工修改。\n')
        fh.write('-- 规模：客户 %d / 商品 %d / 订单 %d\n\n' % (N_CUSTOMER, N_PRODUCT, N_ORDER))
        fh.write('use `eshop`;\n\n')
        fh.write('-- 子表在前，父表在后\n')
        for t in ('t_payment', 't_order_item', 't_order', 't_product', 't_customer'):
            fh.write('truncate table `%s`;\n' % t)
        fh.write('\n')

        w = Writer(fh)

        # ------------------------------------------------ 客户
        w.begin('t_customer',
                ('customer_login_name', 'customer_name', 'customer_email',
                 'status', 'deleted', 'create_time', 'update_time'))
        used_login = set()
        for _ in range(N_CUSTOMER):
            while True:
                login = random.choice(['u', 'user', 'k', 'shop']) + str(random.randint(100000, 999999))
                if login not in used_login:
                    used_login.add(login)
                    break
            name = random.choice(SURNAME) + random.choice(GIVEN)
            email = '%s@%s' % (login, random.choice(DOMAINS))
            created = START + dt.timedelta(seconds=random.randint(
                0, int((NOW - START).total_seconds())))
            status = 1 if random.random() < 0.03 else 0   # 3% 禁用
            w.add([login, name, email, status, 0, created, created])
        w.flush()
        stats['t_customer'] = w.rows

        # ------------------------------------------------ 商品
        w.begin('t_product',
                ('product_no', 'product_name', 'product_price',
                 'product_stock', 'status', 'deleted', 'create_time', 'update_time'))
        for pid in range(1, N_PRODUCT + 1):
            no, name, price = products[pid]
            stock = random.randint(0, 500)
            created = START + dt.timedelta(seconds=random.randint(
                0, int((NOW - START).total_seconds() * 0.5)))
            status = 1 if random.random() < 0.9 else 0     # 10% 下架
            w.add([no, name, price, stock, status, 0, created, created])
        w.flush()
        stats['t_product'] = w.rows

        # ------------------------------------------------ 订单 + 明细 + 支付
        # 三张表要一起生成，因为金额必须对得上
        w_order = Writer(fh)
        w_item = Writer(fh)
        w_pay = Writer(fh)
        w_order.begin('t_order',
                      ('order_no', 'customer_id', 'order_amount',
                       'status', 'pay_time', 'deleted', 'create_time', 'update_time'))
        w_item.begin('t_order_item',
                     ('order_id', 'product_id', 'product_no', 'product_name',
                      'product_price', 'quantity', 'deleted', 'create_time', 'update_time'))
        w_pay.begin('t_payment',
                    ('payment_no', 'channel_trade_no', 'order_id', 'amount',
                     'channel', 'status', 'pay_time', 'deleted', 'create_time', 'update_time'))

        seq_order = 0
        seq_pay = 0
        order_amounts = {}

        for oid in range(1, N_ORDER + 1):
            cid = pick_customer()
            created = START + dt.timedelta(seconds=random.randint(
                0, int((NOW - START).total_seconds())))
            status = pick_order_status()

            # ---- 明细：同一订单内商品不重复（uk_order_product 要求）----
            n_items = pick_item_count()
            chosen = set()
            guard = 0
            while len(chosen) < n_items and guard < 50:
                chosen.add(pick_product())
                guard += 1
            items = []
            total = 0.0
            for pid in sorted(chosen):
                no, name, price = products[pid]
                qty = random.randint(1, 5)
                items.append([oid, pid, no, name, price, qty, 0, created, created])
                total += price * qty
            total = round(total, 2)

            # ---- 支付时间：已支付及之后的状态才有 ----
            pay_time = None
            if status in (1, 2, 3):
                pay_time = created + dt.timedelta(seconds=random.randint(30, 3600))

            seq_order += 1
            order_no = 'SO%s%06d' % (created.strftime('%Y%m%d'), seq_order)
            w_order.add([order_no, cid, total, status, pay_time, 0, created, created])
            for it in items:
                w_item.add(it)
            order_amounts[oid] = (total, pay_time, status, created)

        w_order.flush()
        w_item.flush()

        # ---- 支付记录：成功的 + 少量失败重试 ----
        for oid in range(1, N_ORDER + 1):
            total, pay_time, status, created = order_amounts[oid]
            if status in (1, 2, 3):
                # 一部分订单先失败一次再成功，模拟重试
                if random.random() < 0.05:
                    seq_pay += 1
                    fail_at = (pay_time or created) - dt.timedelta(seconds=random.randint(10, 120))
                    w_pay.add(['PAY%s%07d' % (fail_at.strftime('%Y%m%d'), seq_pay),
                               None, oid, total, random.randint(0, 2), 2, None, 0, fail_at, fail_at])
                seq_pay += 1
                w_pay.add(['PAY%s%07d' % (pay_time.strftime('%Y%m%d'), seq_pay),
                           'TRADE%s' % random.randint(10 ** 11, 10 ** 12 - 1),
                           oid, total, random.randint(0, 2), 1, pay_time, 0, pay_time, pay_time])
            elif status == 0:
                # 待支付：留一条待支付记录
                if random.random() < 0.3:
                    seq_pay += 1
                    w_pay.add(['PAY%s%07d' % (created.strftime('%Y%m%d'), seq_pay),
                               None, oid, total, random.randint(0, 2), 0, None, 0, created, created])
        w_pay.flush()
        stats['t_order'] = w_order.rows
        stats['t_order_item'] = w_item.rows
        stats['t_payment'] = w_pay.rows

    size_mb = os.path.getsize(OUT_PATH) / 1048576.0
    print('已生成 %s' % OUT_PATH)
    print('文件大小：%.1f MB' % size_mb)
    total = 0
    for k in ('t_customer', 't_product', 't_order', 't_order_item', 't_payment'):
        print('  %-14s %7d 行' % (k, stats[k]))
        total += stats[k]
    print('  %-14s %7d 行' % ('合计', total))


if __name__ == '__main__':
    main()
