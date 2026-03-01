#!/bin/bash

# 检查是否为 root 用户
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
else
    echo "未知系统类型，尝试直接继续..."
fi

clear
echo "========================================================="
echo "               全自动多系统 DD 重装脚本                  "
echo "========================================================="

# 自动识别当前网络配置
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

echo "✅ 已自动识别当前网络配置："
echo "   - 公网 IP  : $MAIN_IP"
echo "   - 网关     : $GATEWAY"
echo "   - 子网掩码 : $NETMASK"
echo "========================================================="
echo "▶ 开始交互式配置 (直接按回车键将使用中括号内的默认值)"
echo "---------------------------------------------------------"

# 1. 选择目标系统
echo "请选择需要重装的目标系统："
echo "  1) Debian 12 (默认推荐)"
echo "  2) Debian 11"
echo "  3) Ubuntu 22.04"
echo "  4) Ubuntu 20.04"
echo "  5) AlmaLinux 9"
echo "  6) RockyLinux 9"
read -r -p "请输入序号 [1]: " os_choice
os_choice=${os_choice:-1}

case $os_choice in
    1) OS_FLAG="-debian 12" ; OS_NAME="Debian 12" ;;
    2) OS_FLAG="-debian 11" ; OS_NAME="Debian 11" ;;
    3) OS_FLAG="-ubuntu 22.04" ; OS_NAME="Ubuntu 22.04" ;;
    4) OS_FLAG="-ubuntu 20.04" ; OS_NAME="Ubuntu 20.04" ;;
    5) OS_FLAG="-almalinux 9" ; OS_NAME="AlmaLinux 9" ;;
    6) OS_FLAG="-rockylinux 9" ; OS_NAME="RockyLinux 9" ;;
    *) OS_FLAG="-debian 12" ; OS_NAME="Debian 12" ;;
esac

# 2. 设置主机名
read -r -p "请输入主机名 (Hostname) [vps]: " input_hostname
HOSTNAME_VAL=${input_hostname:-vps}

# 3. 设置 Root 密码 (默认已修改为 qwertyui)
read -r -p "请输入 Root 密码 [qwertyui]: " input_password
PASSWORD_VAL=${input_password:-qwertyui}

# 4. 设置 SSH 端口
read -r -p "请输入 SSH 端口 [22]: " input_port
PORT_VAL=${input_port:-22}

# 5. 设置系统时区
read -r -p "请输入系统时区 [Asia/Shanghai]: " input_timezone
TIMEZONE_VAL=${input_timezone:-Asia/Shanghai}

# 6. BBR 加速开关
read -r -p "是否自动开启 BBR 网络加速 (y/n) [y]: " input_bbr
input_bbr=${input_bbr:-y}
if [[ "$input_bbr" == "y" || "$input_bbr" == "Y" ]]; then
    BBR_FLAG="-bbr"
    BBR_NAME="是"
else
    BBR_FLAG=""
    BBR_NAME="否"
fi

# 7. Swap 机制通知
echo "说明: 底层重装机制会在格式化硬盘时，根据当前物理内存自动规划并创建合理的 Swap 分区大小。"
read -r -p "按回车继续..." dummy_swap

clear
echo "========================================================="
echo "最终确认：您的重装配置信息如下"
echo "========================================================="
echo "目标系统 : $OS_NAME"
echo "主机名   : $HOSTNAME_VAL"
echo "Root密码 : $PASSWORD_VAL"
echo "SSH端口  : $PORT_VAL"
echo "系统时区 : $TIMEZONE_VAL"
echo "BBR加速  : $BBR_NAME"
echo "底层机制 : 自动处理 DHCP 并保留网卡静态信息"
echo "========================================================="
echo "⚠️ 警告：继续操作将格式化整个硬盘，所有数据将永久丢失！"
read -r -p "确认无误并开始执行重装？(y/n) [n]: " confirm_install
confirm_install=${confirm_install:-n}

if [[ "$confirm_install" != "y" && "$confirm_install" != "Y" ]]; then
    echo "操作已取消，系统未做任何修改。"
    exit 0
fi

echo "开始下载并部署底层重装核心组件..."
wget --no-check-certificate -qO InstallNET.sh 'https://raw.githubusercontent.com/leitbogioro/Tools/master/network_reinstall.sh'
chmod a+x InstallNET.sh

echo "核心组件下载完毕，正在生成新系统引导并准备重启..."
# 直接调用组装好的所有参数，执行实际的系统烧录
bash InstallNET.sh ${OS_FLAG} -pwd "${PASSWORD_VAL}" -port "${PORT_VAL}" -hostname "${HOSTNAME_VAL}" -timezone "${TIMEZONE_VAL}" ${BBR_FLAG}

echo "所有指令已成功下发！系统即将断开连接并进入后台重装流程。"
echo "预计需要 10 - 20 分钟（视服务器性能和网络而定），请稍后使用设置的新密码和端口重新 SSH 连接。"
