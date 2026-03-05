# Juicity-Plus

juicity 一键管理脚本，自动搭建 juicity 代理服务，生成分享链接和客户端配置。

---

## 特性

- 一键安装，全程无需手动填写配置
- 自动生成 UUID、密码、随机端口
- 自动签发 TLS 证书（SNI 伪装为 www.bing.com）
- 安装完成后直接输出分享链接和客户端 JSON 配置
- 自动配置防火墙（支持 ufw / iptables）
- 支持 BBR 加速一键开启
- VPS 重启后服务自动恢复（systemd 托管）
- 支持 Debian / Ubuntu / CentOS / Rocky Linux

---

## 使用方法

**wget 方式：**

```bash
wget -O juicity-plus.sh https://raw.githubusercontent.com/Alvin9999-newpac/Juicity-Plus/main/juicity-plus.sh && chmod +x juicity-plus.sh && bash juicity-plus.sh
```

**curl 方式：**

```bash
curl -fsSL -o juicity-plus.sh https://raw.githubusercontent.com/Alvin9999-newpac/Juicity-Plus/main/juicity-plus.sh && chmod +x juicity-plus.sh && bash juicity-plus.sh
```

---

## 菜单说明

```
 ================================================
   Juicity 管理脚本
   https://github.com/Alvin9999-newpac/Juicity-Plus
 ================================================
 BBR 加速：  已启用
 服务状态：  运行中
 ------------------------------------------------
 1. 安装 / 重装
 2. 查看节点 & 配置
 3. 重启服务
 4. 一键开启 BBR
 5. 查看实时日志
 6. 卸载
 0. 退出
 ================================================
```

| 选项 | 说明 |
|------|------|
| 1 | 自动下载最新版 juicity，生成账号并启动服务 |
| 2 | 查看当前节点信息、分享链接、客户端 JSON 配置 |
| 3 | 重启 juicity 服务 |
| 4 | 一键开启 BBR 网络加速（需内核 4.9+） |
| 5 | 实时查看 juicity 运行日志（Ctrl+C 退出） |
| 6 | 卸载 juicity 及所有配置文件 |

---

## 安装效果示例

安装完成后自动输出：

```
 ========== 节点信息 ==========

 [账号信息]
  服务器  : 1.2.3.4
  端口    : 38291
  UUID    : xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
  密码    : Xk9mPqR2sLwN4vZj
  协议    : QUIC (juicity)
  证书    : 自签名（allow_insecure=true）

 [分享链接]
  juicity://uuid:password@1.2.3.4:38291?congestion_control=bbr&sni=www.bing.com&allow_insecure=1

 [客户端 JSON 配置]
{
  "listen": ":1080",
  "server": "1.2.3.4:38291",
  "uuid": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "password": "Xk9mPqR2sLwN4vZj",
  "sni": "www.bing.com",
  "allow_insecure": true,
  "congestion_control": "bbr",
  "log_level": "info"
}

 [支持的客户端]
  官方客户端  : https://github.com/juicity/juicity/releases
  NekoBox     : https://github.com/MatsuriDayo/NekoBoxForAndroid（Android）
  NekoRay     : https://github.com/MatsuriDayo/nekoray（Windows/Linux）
  注意        : Clash Meta / Mihomo 不支持 juicity 协议
```

---

## 客户端使用

### 官方客户端

1. 从 [juicity releases](https://github.com/juicity/juicity/releases) 下载对应平台的 `juicity-client`
2. 将安装输出的 JSON 配置保存为 `client.json`
3. 执行：
   ```bash
   juicity-client run -c client.json
   ```
4. 本地 SOCKS5 代理地址：`127.0.0.1:1080`

### NekoRay（Windows / Linux）

1. 下载 [NekoRay](https://github.com/MatsuriDayo/nekoray/releases)
2. 复制分享链接，在 NekoRay 中选择「从剪贴板导入」即可

### NekoBox（Android）

1. 下载 [NekoBoxForAndroid](https://github.com/MatsuriDayo/NekoBoxForAndroid/releases)
2. 复制分享链接，点击右下角 `+` → 「从剪贴板导入」

> **注意：** Clash Meta / Mihomo 暂不支持 juicity 协议，请勿使用。

---

## 系统要求

| 项目 | 要求 |
|------|------|
| 操作系统 | Debian 10+ / Ubuntu 20.04+ / CentOS 7+ / Rocky Linux 8+ |
| 架构 | x86_64 / aarch64 |
| 内存 | 128MB 以上 |
| 权限 | root |

---

## 协议说明

juicity 基于 QUIC 协议，相比 TCP 代理具有以下优势：

- 内置多路复用，无队头阻塞问题
- 弱网环境下连接更稳定
- 原生支持 BBR 拥塞控制

---

## 常用命令

```bash
# 查看服务状态
systemctl status juicity

# 查看日志
journalctl -u juicity -f

# 手动启动 / 停止 / 重启
systemctl start juicity
systemctl stop juicity
systemctl restart juicity

# 查看配置文件
cat /etc/juicity/server.json
```

---

## 相关项目

- [juicity](https://github.com/juicity/juicity) — 本脚本所使用的代理核心
- [Mieru-Plus](https://github.com/Alvin9999-newpac/Mieru-Plus) — 同类一键脚本（TCP/UDP）
- [Sing-Box-Plus](https://github.com/Alvin9999-newpac/Sing-Box-Plus) — 同类一键脚本

---

## License

MIT
