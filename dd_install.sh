#!/bin/bash

# ==========================================
# 检查是否为 root 用户
# ==========================================
if [[ $EUID -ne 0 ]]; then
    echo "错误: 请使用 root 用户运行此脚本"
    exit 1
fi

echo "正在检查并安装必要依赖 (wget, curl, iproute2)..."
if [[ -f /etc/debian_version ]]; then
    apt-get update -y >/dev/null 2>&1
    apt-get install -y wget curl iproute2 >/dev/null 2>&1
elif [[ -f /etc/redhat-release ]]; then
    yum install -y wget curl iproute >/dev/null 2>&1
elif [[ -f /etc/alpine-release ]]; then
    apk add wget curl iproute2 >/dev/null 2>&1
else
    echo "未知系统类型，尝试直接继续..."
fi

clear
echo "========================================================="
echo "        全平台/全网络/全自动 DD 重装脚本 (终极交互版)      "
echo "========================================================="

# ==========================================
# 自动识别当前网络配置
# ==========================================
MAIN_IP=$(ip -4 route get 8.8.8.8 | grep -oP 'src \K\S+')
GATEWAY=$(ip -4 route show default | grep -oP 'via \K\S+' | head -n 1)
INTERFACE=$(ip -4 route get 8.8.8.8 | grep -oP 'dev \K\S+' | head -n 1)

if [[ -n "$INTERFACE" ]]; then
    SUBNET_PREFIX=$(ip -o -f inet addr show "$INTERFACE" | awk '{print $4}' | cut -d/ -f2 | head -n 1)
    if [[ -n "$SUBNET_PREFIX" ]]; then
        mask=$((0xffffffff << (32 - SUBNET_PREFIX)))
        NETMASK="$(( (mask >> 24) & 0xff )).$(( (mask >> 16) & 0xff )).$(( (mask >> 8) & 0xff )).$(( mask & 0xff ))"
    else
        NETMASK="自动分配"
    fi
else
    MAIN_IP="自动获取"
    GATEWAY="自动获取"
    NETMASK="自动获取"
fi

echo "✅ 已自动识别当前网络配置 (底层引擎将接管复杂网络)："
echo "   - 公网 IP  : $MAIN_IP"
echo "   - 网关     : $GATEWAY"
echo "   - 子网掩码 : $NETMASK"
echo "========================================================="
echo "▶ 开始交互式配置 (直接按回车键将使用中括号内的默认值)"
echo "---------------------------------------------------------"

# ==========================================
# 1. 选择系统大类
# ==========================================
echo "请选择要重装的目标系统类型："
echo "  1) Linux (支持 Debian/Ubuntu/CentOS/Alpine 等 19 种)"
echo "  2) Windows (官方原版 ISO，自动注入 VirtIO 驱动)"
read -r -p "请输入序号 [1]: " os_type_choice
os_type_choice=${os_type_choice:-1}

# ==========================================
# 2. 详细系统选择
# ==========================================
if [[ "$os_type_choice" == "1" ]]; then
    echo "---------------------------------------------------------"
    echo "请选择 Linux 发行版："
    echo "  1) Debian 12 (默认推荐，稳定极低占用)"
    echo "  2) Debian 11"
    echo "  3) Ubuntu 22.04"
    echo "  4) Ubuntu 20.04"
    echo "  5) Alpine Linux (极少内存占用，适合低配小鸡)"
    echo "  6) AlmaLinux 9"
    read -r -p "请输入序号 [1]: " linux_choice
    linux_choice=${linux_choice:-1}

    case $linux_choice in
        1) OS_CMD="debian 12" ; OS_NAME="Debian 12" ;;
        2) OS_CMD="debian 11" ; OS_NAME="Debian 11" ;;
        3) OS_CMD="ubuntu 22.04" ; OS_NAME="Ubuntu 22.04" ;;
        4) OS_CMD="ubuntu 20.04" ; OS_NAME="Ubuntu 20.04" ;;
        5) OS_CMD="alpine" ; OS_NAME="Alpine Linux" ;;
        6) OS_CMD="alma 9" ; OS_NAME="AlmaLinux 9" ;;
        *) OS_CMD="debian 12" ; OS_NAME="Debian 12" ;;
    esac
elif [[ "$os_type_choice" == "2" ]]; then
    echo "---------------------------------------------------------"
    echo "请选择 Windows 版本："
    echo "  1) Windows 10 Enterprise LTSC 2021 (默认推荐)"
    echo "  2) Windows 11 Pro"
    echo "  3) Windows Server 2022"
    echo "  4) Windows Server 2019"
    read -r -p "请输入序号 [1]: " win_choice
    win_choice=${win_choice:-1}

    case $win_choice in
        1) OS_CMD="windows 10" ; OS_NAME="Windows 10 LTSC 2021" ;;
        2) OS_CMD="windows 11" ; OS_NAME="Windows 11 Pro" ;;
        3) OS_CMD="windows 2022" ; OS_NAME="Windows Server 2022" ;;
        4) OS_CMD="windows 2019" ; OS_NAME="Windows Server 2019" ;;
        *) OS_CMD="windows 10" ; OS_NAME="Windows 10 LTSC 2021" ;;
    esac
else
    echo "输入错误，默认使用 Debian 12。"
    OS_CMD="debian 12"
    OS_NAME="Debian 12"
fi

# ==========================================
# 3. 基础参数配置
# ==========================================
echo "---------------------------------------------------------"
# 主机名 (Hostname)
read -r -p "请输入主机名 (Hostname) [vps]: " input_hostname
HOSTNAME_VAL=${input_hostname:-vps}

# 密码 (Password)
read -r -p "请输入 Root/Administrator 密码 [qwertyui]: " input_password
PASSWORD_VAL=${input_password:-qwertyui}

# 端口 (Port)
read -r -p "请输入重装后的 SSH/RDP 端口 [22]: " input_port
PORT_VAL=${input_port:-22}

# 时区 (Timezone)
read -r -p "请输入系统时区 [Asia/Shanghai]: " input_timezone
TIMEZONE_VAL=${input_timezone:-Asia/Shanghai}

# ==========================================
# 4. 高级参数配置 (Swap & BBR)
# ==========================================
echo "---------------------------------------------------------"
# Swap 设置
read -r -p "请输入需要设置的 Swap 大小(MB)，输入 0 为不设置 [1024]: " input_swap
SWAP_VAL=${input_swap:-1024}

# BBR 加速 (仅限 Linux)
if [[ "$os_type_choice" == "1" ]]; then
    read -r -p "是否自动开启 BBR 网络加速 (y/n) [y]: " input_bbr
    input_bbr=${input_bbr:-y}
    if [[ "$input_bbr" == "y" || "$input_bbr" == "Y" ]]; then
        BBR_FLAG="--bbr"
        BBR_NAME="是 (已开启)"
    else
        BBR_FLAG=""
        BBR_NAME="否"
    fi
else
    BBR_FLAG=""
    BBR_NAME="不适用 (Windows)"
fi

# ==========================================
# 5. 最终确认
# ==========================================
clear
echo "========================================================="
echo "最终确认：您的重装配置信息如下"
echo "========================================================="
echo "目标系统 : $OS_NAME"
echo "主机名   : $HOSTNAME_VAL"
if [[ "$os_type_choice" == "1" ]]; then
    echo "登录账号 : root"
else
    echo "登录账号 : Administrator"
fi
echo "登录密码 : $PASSWORD_VAL"
echo "连接端口 : $PORT_VAL"
echo "系统时区 : $TIMEZONE_VAL"
echo "Swap容量 : ${SWAP_VAL} MB"
echo "BBR加速  : $BBR_NAME"
echo "底层驱动 : 自动匹配 BIOS/EFI，分区表 ID 防写错"
echo "========================================================="
echo "⚠️ 警告：继续操作将格式化整个硬盘，所有数据将永久丢失！"
read -r -p "确认无误并开始执行重装？(y/n) [n]: " confirm_install
confirm_install=${confirm_install:-n}

if [[ "$confirm_install" != "y" && "$confirm_install" != "Y" ]]; then
    echo "操作已取消，系统未做任何修改。"
    exit 0
fi

# ==========================================
# 6. 下载并调用引擎执行
# ==========================================
echo "开始下载顶级重装引擎 (reinstall.sh)..."
curl -sSL -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh
chmod +x reinstall.sh

echo "引擎下载完毕，开始组装参数并下发重装指令..."

# 组装基础参数
BUILD_ARGS="$OS_CMD --password \"$PASSWORD_VAL\" --port \"$PORT_VAL\" --hostname \"$HOSTNAME_VAL\" --timezone \"$TIMEZONE_VAL\" --swap \"$SWAP_VAL\" $BBR_FLAG --yes"

# 执行重装引擎
bash reinstall.sh $BUILD_ARGS

echo "========================================================="
echo "所有指令已成功下发！系统将自动断开连接、重启并进入后台安装环境。"
if [[ "$os_type_choice" == "2" ]]; then
    echo "【Windows 安装】由于需脱机下载官方 ISO 及注入驱动，通常需要 20-40 分钟。"
    echo "【提示】强烈建议登录云服务商控制台，通过 VNC 网页终端观察 Windows 安装进度。"
else
    echo "【Linux 安装】通常需要 5-15 分钟。"
    echo "【提示】稍后请使用设置的新端口和新密码重新 SSH 连接。"
fi
echo "========================================================="
