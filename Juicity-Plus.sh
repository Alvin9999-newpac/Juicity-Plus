#!/usr/bin/env bash
# ============================================================
#  Juicity 管理脚本
#  项目地址：https://github.com/Alvin9999-newpac/Juicity-Plus
# ============================================================

set -Eeuo pipefail
stty erase ^H 2>/dev/null || true

# ──────────── 颜色 ────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; PLAIN='\033[0m'

ok()   { echo -e " ${GREEN}[OK]${PLAIN}  $*"; }
warn() { echo -e " ${YELLOW}[!!]${PLAIN}  $*"; }
err()  { echo -e " ${RED}[ERR]${PLAIN} $*"; }
info() { echo -e " ${CYAN}--${PLAIN}   $*"; }

press_enter() { echo; read -rp " 按 Enter 返回主菜单..." _; }

# ──────────── 常量 ────────────
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/juicity"
CONFIG_FILE="${CONFIG_DIR}/server.json"
CRED_FILE="${CONFIG_DIR}/.credentials"
CERT_FILE="${CONFIG_DIR}/cert.pem"
KEY_FILE="${CONFIG_DIR}/key.pem"
SERVICE_FILE="/etc/systemd/system/juicity.service"

# ──────────── 系统检测 ────────────
detect_arch() {
  case "$(uname -m)" in
    x86_64)  ARCH="x86_64" ;;
    aarch64) ARCH="aarch64" ;;
    armv7l)  ARCH="armv7" ;;
    *) err "不支持的架构：$(uname -m)"; exit 1 ;;
  esac
}

# ──────────── 状态查询 ────────────
get_version() {
  [[ -f "${INSTALL_DIR}/juicity-server" ]] \
    && "${INSTALL_DIR}/juicity-server" -v 2>/dev/null | awk '{print $3}' | head -1 \
    || echo "未安装"
}

get_status() {
  systemctl is-active juicity 2>/dev/null | grep -q "^active" \
    && echo "运行中" || echo "未运行"
}

get_bbr() {
  sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}' \
    | grep -q "bbr" && echo "已启用" || echo "未启用"
}

get_ip() {
  curl -fsSL --max-time 5 https://api.ipify.org 2>/dev/null \
    || curl -fsSL --max-time 5 https://ifconfig.me 2>/dev/null \
    || echo "未知"
}

# ──────────── 防火墙放行 ────────────
open_port() {
  local port=$1
  if command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -q "active"; then
    ufw allow "${port}/udp" &>/dev/null && ok "ufw 放行 ${port}/udp"
  fi
  if command -v iptables &>/dev/null; then
    iptables -C INPUT -p udp --dport "$port" -j ACCEPT 2>/dev/null \
      || iptables -I INPUT -p udp --dport "$port" -j ACCEPT
    command -v netfilter-persistent &>/dev/null \
      && netfilter-persistent save &>/dev/null || true
    ok "iptables 放行 ${port}/udp"
  fi
}

# ──────────── 主菜单 ────────────
show_menu() {
  clear
  local VER STATUS BBR SC BC
  VER=$(get_version); STATUS=$(get_status); BBR=$(get_bbr)
  [[ "$STATUS" == "运行中" ]] && SC="$GREEN" || SC="$RED"
  [[ "$BBR"    == "已启用" ]] && BC="$GREEN" || BC="$YELLOW"

  echo -e "${BOLD}${CYAN}"
  echo " ================================================"
  echo "   Juicity 管理脚本 v1.0.0"
  echo "   https://github.com/Alvin9999-newpac/Juicity-Plus"
  echo -e " ================================================${PLAIN}"
  printf " %-12s ${BC}%s${PLAIN}\n"   "BBR 加速："  "$BBR"
  printf " %-12s ${SC}%s${PLAIN}\n"   "服务状态："  "$STATUS"
  printf " %-12s ${CYAN}%s${PLAIN}\n" "当前版本："  "$VER"
  echo " ------------------------------------------------"
  echo -e " ${BOLD}1.${PLAIN} 安装 / 重装"
  echo -e " ${BOLD}2.${PLAIN} 查看节点 & 配置"
  echo -e " ${BOLD}3.${PLAIN} 重启服务"
  echo -e " ${BOLD}4.${PLAIN} 一键开启 BBR"
  echo -e " ${BOLD}5.${PLAIN} 查看实时日志"
  echo -e " ${BOLD}6.${PLAIN} 卸载"
  echo -e " ${BOLD}0.${PLAIN} 退出"
  echo " ================================================"
  echo
  read -rp " 请输入选项 [0-6]: " CHOICE
}

# ──────────── 配置展示 ────────────
_show_config() {
  [[ ! -f "$CRED_FILE" ]] && { warn "未找到凭据，请先安装"; return; }
  source "$CRED_FILE"
  local IP; IP=$(get_ip)

  # 生成证书 SHA256 hash（用于客户端 pinned_certchain_sha256）
  local CERT_HASH=""
  if [[ -f "$CERT_FILE" ]]; then
    CERT_HASH=$(openssl x509 -in "$CERT_FILE" -outform DER 2>/dev/null \
      | openssl dgst -sha256 -binary 2>/dev/null \
      | openssl base64 -A 2>/dev/null || echo "")
  fi

  echo -e "\n${BOLD}${GREEN} ========== 节点信息 ==========${PLAIN}"
  echo
  echo -e " ${BOLD}[账号信息]${PLAIN}"
  echo   "  服务器  : ${IP}"
  echo   "  端口    : ${PORT}"
  echo   "  UUID    : ${UUID}"
  echo   "  密码    : ${PASS}"
  echo   "  协议    : QUIC (juicity)"
  echo   "  证书    : 自签名（allow_insecure=true）"

  echo
  echo -e " ${BOLD}[分享链接]${PLAIN}"
  local SHARE="juicity://${UUID}:${PASS}@${IP}:${PORT}?congestion_control=bbr&sni=www.bing.com&allow_insecure=1"
  [[ -n "$CERT_HASH" ]] && SHARE="${SHARE}&pinned_certchain_sha256=${CERT_HASH}"
  echo "  ${SHARE}"

  echo
  echo -e " ${BOLD}[客户端 JSON 配置]${PLAIN}"
  cat <<EOF
{
  "listen": ":1080",
  "server": "${IP}:${PORT}",
  "uuid": "${UUID}",
  "password": "${PASS}",
  "sni": "www.bing.com",
  "allow_insecure": true,
  "congestion_control": "bbr",
  "log_level": "info"
}
EOF

  echo
  echo -e " ${BOLD}[支持的客户端]${PLAIN}"
  echo   "  官方客户端  : https://github.com/juicity/juicity/releases"
  echo   "  NekoBox     : https://github.com/MatsuriDayo/NekoBoxForAndroid（Android）"
  echo   "  NekoRay     : https://github.com/MatsuriDayo/nekoray（Windows/Linux）"
  echo   "  注意        : Clash Meta / Mihomo 不支持 juicity 协议"

  echo -e "\n${BOLD}${GREEN} ==============================${PLAIN}\n"
}

# ──────────── 1. 安装 ────────────
do_install() {
  clear
  echo -e "${BOLD}${CYAN}===== 安装 Juicity =====${PLAIN}\n"
  detect_arch

  # 检查依赖
  for dep in curl openssl unzip python3; do
    command -v "$dep" &>/dev/null || {
      info "安装依赖 ${dep}..."
      apt-get install -y "$dep" &>/dev/null \
        || yum install -y "$dep" &>/dev/null || true
    }
  done

  # 获取最新版本
  info "获取最新版本..."
  local TAG
  TAG=$(curl -fsSL --max-time 10 \
    "https://api.github.com/repos/juicity/juicity/releases/latest" \
    | grep '"tag_name"' | head -1 | sed 's/.*"\(v[^"]*\)".*/\1/')
  [[ -z "$TAG" ]] && { err "获取版本失败，请检查网络"; press_enter; return; }
  ok "最新版本：${TAG}"

  # 下载解压
  local PKG="juicity-linux-${ARCH}.zip"
  local URL="https://github.com/juicity/juicity/releases/download/${TAG}/${PKG}"
  local TMP; TMP=$(mktemp -d); trap "rm -rf $TMP" RETURN

  info "下载 ${PKG}..."
  curl -fSL --progress-bar -o "${TMP}/${PKG}" "$URL" \
    || { err "下载失败"; press_enter; return; }

  info "解压安装..."
  unzip -o "${TMP}/${PKG}" -d "$TMP" &>/dev/null
  install -m 755 "${TMP}/juicity-server" "${INSTALL_DIR}/juicity-server"
  ok "安装完成：$(get_version)"

  # 生成自签证书
  mkdir -p "$CONFIG_DIR"
  info "生成自签名 TLS 证书..."
  openssl req -newkey rsa:2048 -nodes -keyout "$KEY_FILE" \
    -x509 -days 3650 -out "$CERT_FILE" \
    -subj "/CN=www.bing.com" &>/dev/null
  ok "证书生成完成"

  # 自动生成账号
  info "自动生成账号..."
  local UUID PASS PORT
  UUID=$(python3 -c "from uuid import uuid4; print(uuid4())")
  PASS=$(python3 -c "import random,string; print(''.join(random.choices(string.ascii_letters+string.digits, k=16)))")
  PORT=$(( RANDOM % 40000 + 10000 ))

  # 写服务端配置
  cat > "$CONFIG_FILE" <<EOF
{
  "listen": ":${PORT}",
  "users": {
    "${UUID}": "${PASS}"
  },
  "certificate": "${CERT_FILE}",
  "private_key": "${KEY_FILE}",
  "congestion_control": "bbr",
  "log_level": "info",
  "disable_outbound_udp443": true
}
EOF
  ok "服务端配置写入完成"

  # 保存凭据
  cat > "$CRED_FILE" <<EOF
UUID=${UUID}
PASS=${PASS}
PORT=${PORT}
EOF
  chmod 600 "$CRED_FILE"

  # 创建 systemd 服务
  cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Juicity Proxy Server
After=network.target

[Service]
Type=simple
ExecStart=${INSTALL_DIR}/juicity-server run -c ${CONFIG_FILE}
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable juicity &>/dev/null

  # 防火墙
  open_port "$PORT"

  # 启动
  systemctl start juicity
  sleep 2
  ok "服务状态：$(get_status)"

  _show_config
  press_enter
}

# ──────────── 2. 查看节点 ────────────
do_show() {
  clear
  echo -e "${BOLD}${CYAN}===== 节点信息 & 分享配置 =====${PLAIN}\n"
  [[ ! -f "${INSTALL_DIR}/juicity-server" ]] && { err "juicity 未安装"; press_enter; return; }
  _show_config
  press_enter
}

# ──────────── 3. 重启 ────────────
do_restart() {
  clear
  echo -e "${BOLD}${CYAN}===== 重启服务 =====${PLAIN}\n"
  [[ ! -f "${INSTALL_DIR}/juicity-server" ]] && { err "juicity 未安装"; press_enter; return; }
  systemctl restart juicity
  sleep 2; ok "重启完成，状态：$(get_status)"
  press_enter
}

# ──────────── 4. BBR ────────────
do_bbr() {
  clear
  echo -e "${BOLD}${CYAN}===== 开启 BBR =====${PLAIN}\n"
  [[ "$(get_bbr)" == "已启用" ]] && { ok "BBR 已启用"; press_enter; return; }

  local MAJOR MINOR
  MAJOR=$(uname -r | cut -d. -f1); MINOR=$(uname -r | cut -d. -f2)
  if [[ $MAJOR -lt 4 ]] || { [[ $MAJOR -eq 4 ]] && [[ $MINOR -lt 9 ]]; }; then
    err "内核 $(uname -r) 版本过低，需 4.9+"; press_enter; return
  fi

  grep -q "tcp_bbr" /etc/modules-load.d/modules.conf 2>/dev/null \
    || echo "tcp_bbr" >> /etc/modules-load.d/modules.conf
  modprobe tcp_bbr 2>/dev/null || true
  grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf \
    || echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
  grep -q "tcp_congestion_control=bbr" /etc/sysctl.conf \
    || echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
  sysctl -p &>/dev/null
  ok "BBR 已开启：$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')"
  press_enter
}

# ──────────── 5. 日志 ────────────
do_logs() {
  clear
  echo -e "${BOLD}${CYAN}===== 实时日志（Ctrl+C 退出）=====${PLAIN}\n"
  [[ ! -f "${INSTALL_DIR}/juicity-server" ]] && { err "juicity 未安装"; press_enter; return; }
  journalctl -u juicity -f --no-hostname -o cat
}

# ──────────── 6. 卸载 ────────────
do_uninstall() {
  clear
  echo -e "${BOLD}${RED}===== 卸载 Juicity =====${PLAIN}\n"
  [[ ! -f "${INSTALL_DIR}/juicity-server" ]] && { warn "juicity 未安装"; press_enter; return; }
  read -rp " 确认卸载？[y/N]: " _c
  [[ "${_c,,}" != "y" ]] && { press_enter; return; }

  systemctl stop juicity &>/dev/null || true
  systemctl disable juicity &>/dev/null || true
  rm -f "$SERVICE_FILE"
  systemctl daemon-reload
  rm -f "${INSTALL_DIR}/juicity-server"
  rm -rf "$CONFIG_DIR"
  ok "Juicity 已卸载"
  press_enter
}

# ──────────── 入口 ────────────
[[ $EUID -ne 0 ]] && { echo -e "${RED}请用 root 权限运行：sudo bash $0${PLAIN}"; exit 1; }

while true; do
  show_menu
  case "$CHOICE" in
    1) do_install   ;;
    2) do_show      ;;
    3) do_restart   ;;
    4) do_bbr       ;;
    5) do_logs      ;;
    6) do_uninstall ;;
    0) echo -e "\n 再见！\n"; exit 0 ;;
    *) warn "无效选项"; sleep 1 ;;
  esac
done
