# MySQL root 密码重置步骤（本机专用）

> 状态：**✅ 已于 2026-10-06 执行完成**（S1–S8 全部走通）
> 本文档只写步骤，不含任何密码明文。

## 目标机器事实（已实测，不用重查）

| 项 | 值 |
|---|---|
| 服务名 | `MySQL267`（Running，启动类型 Automatic） |
| mysqld | `C:\Program Files\MySQL\MySQL Server 26.7\bin\mysqld.exe` |
| 服务启动命令行 | `mysqld.exe --defaults-file="D:\MySQL\MySQL Server 26.7\my.ini" MySQL267` |
| 客户端 | `C:\Program Files\MySQL\MySQL Server 26.7\bin\mysql.exe` |
| 端口 | 3306 |
| datadir | `D:/MySQL/MySQL Server 26.7/Data` |
| 版本 | 26.7.0 Community Server |
| 选项支持 | ✅ 已用 `mysqld --verbose --help` 确认 `--skip-grant-tables`、`--skip-networking`、`--enable-named-pipe`、`--shared-memory`、`--init-file` 全部存在 |

## 风险（动手前必须知道）

1. 整个过程 MySQL 不可用，约 **3–5 分钟**。
2. `--skip-grant-tables` 期间**不校验任何密码** —— 谁连上都是全权限。所以本文同时加 `--skip-networking`，只留一条本地命名管道，不留 TCP 口。
3. 新密码一生效，**所有记住旧密码的地方全部失效**：Navicat / Workbench / DBeaver 里保存的连接、其它软件、脚本。
   这一步**不可逆**（只能再改一次，改不回旧值）。
4. **绝不要**把 `--skip-grant-tables` 留在运行状态过夜。
5. 本流程**不改任何配置文件**，唯一被改的是 `mysql.user` 里 root 的认证串。

## 动手前先花 1 分钟：也许不用重置

旧密码很可能已经存在某处：① Navicat / MySQL Workbench / DBeaver 的**已保存连接**（Workbench 里可直接查看）；
② 密码管理器；③ 装机时的笔记；④ 某个连数据库的软件自己的配置文件。
找得到就跳过本文。

---

# 步骤

## S0. 准备

- 关掉所有正在用 MySQL 的程序（Navicat / Workbench / 任何连库的服务）。
- **以管理员身份**开 PowerShell（开始菜单 → 搜索 PowerShell → 右键 → 以管理员身份运行）。停服务必须管理员。
- 确认提权成功：

```powershell
([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
```

预期输出 `True`。是 `False` 就重新开。

## S1. 停服务

```powershell
Stop-Service MySQL267
Get-Service MySQL267 | Select-Object Name, Status
```

预期 `Status : Stopped`。若停不下来：

```powershell
Get-Process mysqld -ErrorAction SilentlyContinue      # 看谁还占着
Stop-Service MySQL267 -Force
```

## S2. 以「无鉴权」模式手动启动 mysqld

**新开一个 PowerShell 窗口**跑下面这段，跑完这个窗口会一直占用（这是正常的），**不要关它**：

```powershell
$bin = 'C:\Program Files\MySQL\MySQL Server 26.7\bin'
$ini = 'D:\MySQL\MySQL Server 26.7\my.ini'
& "$bin\mysqld.exe" --defaults-file="$ini" --skip-grant-tables --skip-networking --enable-named-pipe --socket=MySQL --console
```

每个开关为什么加：

| 开关 | 作用 |
|---|---|
| `--defaults-file="$ini"` | 必须用**和正式服务一样的配置**，否则 datadir / 端口都不对 |
| `--skip-grant-tables` | 不加载权限表 → 免密登录（重置的关键） |
| `--skip-networking` | 关掉 TCP，堵死「本机任意程序免密连 root」这条路 |
| `--enable-named-pipe --socket=MySQL` | TCP 关掉后，另留一条**本地命名管道**给自己用 |
| `--console` | 日志直接打在窗口里，不写 error log，出错看得见 |

预期：窗口打印若干 `[System] ... ready for connections` 后停住。**保持开着。**

## S3. 免密连上（再开一个管理员 PowerShell）

```powershell
$env:Path += ';C:\Program Files\MySQL\MySQL Server 26.7\bin'
mysql --protocol=PIPE -u root -e "SELECT VERSION() AS ver, CURRENT_USER() AS who;"
```

预期：**不提示密码**，直接出结果。

### 连不上时的降级阶梯（按顺序试）

1. 管道权限问题 → 重新执行 S2，在命令末尾追加：
   `--named-pipe-full-access-group=*everyone*`
2. 还是不行 → 改用共享内存。S2 里把 `--enable-named-pipe --socket=MySQL` 换成
   `--shared-memory --shared-memory-base-name=MYSQL`，然后：
   ```powershell
   mysql --protocol=MEMORY -u root -e "SELECT 1;"
   ```
3. 最后手段（**有风险，仅当上面都失败**）→ S2 去掉 `--skip-networking` 和管道选项，
   改成只绑本机：`--skip-grant-tables --bind-address=127.0.0.1 --port=3306`，然后
   `mysql -h 127.0.0.1 -P 3306 -u root`。
   ⚠️ 此时**本机任何程序都能免密连 root**，做完立刻进入 S6，别拖。

## S4. 关键一步：先刷新权限表，再改密码

⚠️ `--skip-grant-tables` 下**不能**直接执行 `ALTER USER`，会报
`The MySQL server is running with the --skip-grant-tables option so it cannot execute this statement`。
必须**先** `FLUSH PRIVILEGES;` 让服务把权限表读回来，**同一个会话里**接着才能做账号管理。

推荐走交互模式（避免密码留在 PowerShell 命令历史里）：

```powershell
mysql --protocol=PIPE -u root
```

进入 `mysql>` 提示符后逐条执行：

```sql
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY '你的新密码';
```

退出：`EXIT;`

> 想省事也可以一行搞定（但密码会进 `ConsoleHost_history.txt`）：
> `mysql --protocol=PIPE -u root -e "FLUSH PRIVILEGES; ALTER USER 'root'@'localhost' IDENTIFIED BY '你的新密码';"`

密码建议：12 位以上、大小写 + 数字 + 符号。

## S5. 顺手建一个日常账号（DBA 习惯：不长期用 root）

仍在那个 `mysql>` 会话里：

```sql
CREATE USER 'dba_demo'@'localhost' IDENTIFIED BY '另一个强密码';
GRANT ALL PRIVILEGES ON *.* TO 'dba_demo'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EXIT;
```

> `ALL ... WITH GRANT OPTION` 等价于 root。真实环境要按**最小权限**拆 ——
> 教学项目先用它省事，阶段 2 写巡检脚本时我们再改成最小权限版本（那时会用到
> `SELECT` / `PROCESS` / `REPLICATION CLIENT` / `SYSTEM_VARIABLES_ADMIN` 这几项）。

## S6. 关掉临时的 mysqld

回到 S2 那个窗口，按 **Ctrl+C**。然后确认进程真没了：

```powershell
Get-Process mysqld -ErrorAction SilentlyContinue
```

预期：无输出。

## S7. 正常启动服务

```powershell
Start-Service MySQL267
Get-Service MySQL267 | Select-Object Name, Status
```

预期 `Running`。

## S8. 用新密码验证（这步不成功 = 没生效）

```powershell
mysql -h 127.0.0.1 -P 3306 -u root -p -e "SELECT VERSION() AS ver, CURRENT_USER() AS who, @@skip_networking AS tcp_off;"
```

预期：输入新密码后出结果，且 `tcp_off = 0`（证明已回到正常模式、TCP 已恢复）。

---

# 回退

- **新密码改错 / 又忘了**：重跑 S1–S4 再改一次，没有次数限制。
- **服务起不来**：先看错误日志（路径由 my.ini 的 `log_error` 决定，没配就在 datadir 下的 `<主机名>.err`）；
  急着看报错可以直接 `& "$bin\mysqld.exe" --defaults-file="$ini" --console` 前台跑一次。
- 本流程不改配置文件，**没有「配置回退」这一项**。

# 备选路线：`--init-file`（更省事，但密码会短暂落盘）

```powershell
# 1. 写临时文件（内容只有一行；密码必须是纯 ASCII）
'ALTER USER ''root''@''localhost'' IDENTIFIED BY ''你的新密码'';' | Set-Content -Encoding ascii 'D:\mysql-dba-portfolio\_tmp_reset.sql'
# 2. 停服务后带 --init-file 启动
$bin = 'C:\Program Files\MySQL\MySQL Server 26.7\bin'
$ini = 'D:\MySQL\MySQL Server 26.7\my.ini'
& "$bin\mysqld.exe" --defaults-file="$ini" --init-file='D:\mysql-dba-portfolio\_tmp_reset.sql' --console
# 3. Ctrl+C 后删掉临时文件，再 Start-Service
Remove-Item 'D:\mysql-dba-portfolio\_tmp_reset.sql'
```

- 优点：不用 `--skip-grant-tables`，不用管道 / 共享内存那一套。
- 缺点：**密码明文写在磁盘上的一个文件里**（哪怕只有几分钟）。
  这正是默认走 S1–S8 的原因。

# 实测记录（2026-10-06，已执行）

S1–S8 全部走通，root 密码重置成功。过程中踩到两个坑，都记在下面 —— 它们是实测数据，不是推理。

## 坑 1：`ERROR 2061 Authentication requires secure connection`

**现象**：S4 改完密码、`EXIT` 后，用 `mysql --protocol=PIPE -u root -p` 登录，报：

```
ERROR 2061 (HY000): Authentication plugin 'caching_sha2_password' reported error: Authentication requires secure connection.
```

**根因**：`ALTER USER ... IDENTIFIED BY` 在 MySQL 8.0+ 默认把账号认证插件设为 `caching_sha2_password`，
该插件**拒绝在非安全通道上传输密码**。命名管道（`--protocol=PIPE`）不被它认可为安全通道；
而 S4 之前能免密连，只是 `--skip-grant-tables` 根本不校验密码 —— `FLUSH PRIVILEGES` 一生效，
新连接就必须走真实认证，于是撞上 2061。

**两个解法**：

| 解法 | 命令 | 适用 |
|---|---|---|
| 带 RSA 公钥 | `mysql --protocol=PIPE -u root -p --get-server-public-key` | 任何非安全通道（命名管道 / 无 TLS 的 TCP） |
| 回到正常服务走 TCP | `mysql -h 127.0.0.1 -P 3306 -u root -p` | **推荐**；客户端默认 `--ssl-mode=PREFERRED` 会自动协商 TLS，之后不必再带参数 |

## 坑 2：`ERROR 1045 ... (using password: NO)`

**现象**：执行 `mysql --protocol=PIPE -u root --get-server-public-key`（**漏了 `-p`**）报：

```
ERROR 1045 (28000): Access denied for user 'root'@'localhost' (using password: NO)
```

**根因**：MySQL 客户端**不写 `-p` ≠ "提示我输密码"，而是"用空密码登录"**。
括号里的 `using password: NO` 就是判据 —— 它明说客户端压根没发密码。

**诊断口诀**：见到 `Access denied` 先看括号。
- `using password: NO` → 你根本没提供密码（漏 `-p`）
- `using password: YES` → 提供了但不对（密码错 / 认证插件不匹配）

## 记录：这条流程的边界

- 起 `--skip-grant-tables` 时**必须**同时 `--skip-networking`，否则窗口期内本机任意程序都能免密连 root。
- 本流程**没有改任何配置文件**，唯一变更的是 `mysql.user` 里 root 的认证串 —— 所以回退就是"再改一次密码"。
- 密码明文没有写进任何文档、脚本或本文件。

# 后续完善方向（已提出，暂缓）

- 把日常账号 `dba_demo` 收敛成最小权限集，并写成 `sql/00_grants.sql` 纳入作品集。
- 补一个「忘了 dba_demo 密码」的恢复流程（同一套 skip-grant-tables 即可）。
