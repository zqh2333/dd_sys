#!/bin/bash

# ==========================================
# 终端色彩及日志输出美化函数
# ==========================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # 恢复默认颜色

LOG_INFO() { echo -e "${CYAN}[INFO]${NC} $1"; }
LOG_SUCCESS() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
LOG_WARN() { echo -e "${YELLOW}[WARN]${NC} $1"; }
LOG_ERROR() { echo -e "${RED}[ERROR]${NC} $1"; }
DIVIDER() { echo -e "${BLUE}=========================================================${NC}"; }
SUB_DIVIDER() { echo -e "${CYAN}---------------------------------------------------------${NC}"; }

# ==========================================
# 检查是否为 root 用户
# ==========================================
if [[ $EUID -ne 0 ]]; then
    LOG_ERROR "权限不足！请使用 root 用户运行此脚本。"
    exit 1
fi

LOG_INFO "正在初始化脚本环境，检查必要依赖..."
if [[ -f /etc/debian_version ]]; then
    apt-get update -y >/dev/null 2>&1
    apt-get install -y wget curl iproute2 >/dev/null 2>&1
elif [[ -f /etc/redhat-release ]]; then
    yum install -y wget curl iproute >/dev/null 2>&1
elif [[ -f /etc/alpine-release ]]; then
    apk add wget curl iproute2 >/dev/null 2>&1
fi
LOG_SUCCESS "环境依赖就绪。"
sleep 1

clear
DIVIDER
echo -e "${BOLD}       🚀 全平台 DD 重装与系统环境配置工具 (二合一版)      ${NC}"
DIVIDER
echo -e "  ${GREEN}1) 🚀 一键 DD 重装系统${NC} (支持 Linux / Windows 互刷)"
echo -e "  ${CYAN}2) 🛠️ 一键配置系统环境${NC} (修改主机名/时区/Swap/开启BBR)"
DIVIDER
read -r -p "$(echo -e "${BOLD}请输入序号选择功能 [1]: ${NC}")" main_choice
main_choice=${main_choice:-1}

if [[ "$main_choice" == "2" ]]; then
    # ==========================================
    # 功能 2：系统环境配置
    # ==========================================
    clear
    DIVIDER
    echo -e "${BOLD}                 🛠️ 系统环境一键配置工具                    ${NC}"
    DIVIDER
    
    read -r -p "$(echo -e "请输入新的${CYAN}主机名 (Hostname)${NC} [vps]: ")" input_hostname
    HOSTNAME_VAL=${input_hostname:-vps}
    
    read -r -p "$(echo -e "请输入${CYAN}系统时区${NC} [Asia/Shanghai]: ")" input_timezone
    TIMEZONE_VAL=${input_timezone:-Asia/Shanghai}
    
    read -r -p "$(echo -e "请输入需要添加的${CYAN}Swap 大小(MB)${NC}，输入 0 为不添加 [1024]: ")" input_swap
    SWAP_VAL=${input_swap:-1024}
    
    read -r -p "$(echo -e "是否开启 ${CYAN}BBR 网络加速${NC} (y/n) [y]: ")" input_bbr
    input_bbr=${input_bbr:-y}

    SUB_DIVIDER
    LOG_INFO "正在应用您的专属配置，请稍候..."

    # 设置主机名
    if command -v hostnamectl >/dev/null 2>&1; then
        hostnamectl set-hostname "$HOSTNAME_VAL"
    else
        echo "$HOSTNAME_VAL" > /etc/hostname
        hostname "$HOSTNAME_VAL"
    fi
    LOG_SUCCESS "主机名已设置为: ${BOLD}$HOSTNAME_VAL${NC}"

    # 设置时区
    if command -v timedatectl >/dev/null 2>&1; then
        timedatectl set-timezone "$TIMEZONE_VAL"
    else
        ln -sf /usr/share/zoneinfo/"$TIMEZONE_VAL" /etc/localtime
    fi
    LOG_SUCCESS "时区已设置为: ${BOLD}$TIMEZONE_VAL${NC}"

    # 设置 Swap
    if [[ "$SWAP_VAL" -gt 0 ]]; then
        if swapon --show | grep -q "/swapfile"; then
            LOG_WARN "检测到已存在 Swap，跳过创建。"
        else
            LOG_INFO "正在创建 ${SWAP_VAL}MB Swap 文件，这可能需要几十秒时间..."
            dd if=/dev/zero of=/swapfile bs=1M count="$SWAP_VAL" status=none
            chmod 600 /swapfile
            mkswap /swapfile >/dev/null 2>&1
            swapon /swapfile
            if ! grep -q "/swapfile" /etc/fstab; then
                echo "/swapfile none swap sw 0 0" >> /etc/fstab
            fi
            LOG_SUCCESS "Swap (${SWAP_VAL} MB) 创建并挂载成功!"
        fi
    fi

    # 设置 BBR
    if [[ "$input_bbr" == "y" || "$input_bbr" == "Y" ]]; then
        if lsmod | grep -q bbr; then
            LOG_SUCCESS "BBR 已经是开启状态，无需重复配置。"
        else
            echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
            echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
            sysctl -p >/dev/null 2>&1
            LOG_SUCCESS "BBR 网络加速已开启!"
        fi
    fi

    DIVIDER
    echo -e "${GREEN}🎉 环境配置全部完成！建议断开 SSH 重新连接以使主机名等显示生效。${NC}"
    DIVIDER
    exit 0

elif [[ "$main_choice" == "1" ]]; then
    # ==========================================
    # 功能 1：DD 重装系统
    # ==========================================
    clear
    DIVIDER
    echo -e "${BOLD}       🚀 全平台/全网络/全自动 DD 重装脚本 (底层引擎)      ${NC}"
    DIVIDER

    LOG_INFO "正在探测当前网络拓扑结构..."
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

    LOG_SUCCESS "网络探测完成 (重装引擎将接管复杂网络)："
    echo -e "   - 公网 IP  : ${BOLD}$MAIN_IP${NC}"
    echo -e "   - 网关     : ${BOLD}$GATEWAY${NC}"
    echo -e "   - 子网掩码 : ${BOLD}$NETMASK${NC}"
    DIVIDER
    echo -e "▶ 开始交互式配置 (直接按回车键将使用 ${CYAN}中括号${NC} 内的默认值)"
    SUB_DIVIDER

    echo "请选择要重装的目标系统类型："
    echo -e "  ${GREEN}1) Linux${NC} (支持 Debian/Ubuntu/CentOS/Alpine 等)"
    echo -e "  ${BLUE}2) Windows${NC} (官方原版 ISO，自动注入 VirtIO 驱动)"
    read -r -p "$(echo -e "请输入序号 [1]: ")" os_type_choice
    os_type_choice=${os_type_choice:-1}

    if [[ "$os_type_choice" == "1" ]]; then
        SUB_DIVIDER
        echo "请选择 Linux 发行版："
        echo "  1) Debian 12 (默认推荐，稳定极低占用)"
        echo "  2) Debian 11"
        echo "  3) Ubuntu 22.04"
        echo "  4) Ubuntu 20.04"
        echo "  5) Alpine Linux (极少内存占用，适合低配小鸡)"
        echo "  6) AlmaLinux 9"
        read -r -p "$(echo -e "请输入序号 [1]: ")" linux_choice
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
        SUB_DIVIDER
        echo "请选择 Windows 版本："
        echo "  1) Windows 10 Enterprise LTSC 2021 (默认推荐)"
        echo "  2) Windows 11 Pro"
        echo "  3) Windows Server 2022"
        echo "  4) Windows Server 2019"
        read -r -p "$(echo -e "请输入序号 [1]: ")" win_choice
        win_choice=${win_choice:-1}

        case $win_choice in
            1) OS_CMD="windows 10" ; OS_NAME="Windows 10 LTSC 2021" ;;
            2) OS_CMD="windows 11" ; OS_NAME="Windows 11 Pro" ;;
            3) OS_CMD="windows 2022" ; OS_NAME="Windows Server 2022" ;;
            4) OS_CMD="windows 2019" ; OS_NAME="Windows Server 2019" ;;
            *) OS_CMD="windows 10" ; OS_NAME="Windows 10 LTSC 2021" ;;
        esac
    else
        LOG_WARN "输入错误，默认使用 Debian 12。"
        OS_CMD="debian 12"
        OS_NAME="Debian 12"
    fi

    SUB_DIVIDER
    read -r -p "$(echo -e "请输入 ${CYAN}Root/Administrator 密码${NC} [qwertyui]: ")" input_password
    PASSWORD_VAL=${input_password:-qwertyui}

    if [[ "$os_type_choice" == "1" ]]; then
        read -r -p "$(echo -e "请输入重装后的 ${CYAN}SSH 端口${NC} [22]: ")" input_port
        PORT_VAL=${input_port:-22}
    fi

    clear
    DIVIDER
    echo -e "${BOLD}最终确认：您的重装配置信息如下${NC}"
    DIVIDER
    echo -e "目标系统 : ${GREEN}$OS_NAME${NC}"
    if [[ "$os_type_choice" == "1" ]]; then
        echo -e "登录账号 : ${CYAN}root${NC}"
        echo -e "登录密码 : ${YELLOW}$PASSWORD_VAL${NC}"
        echo -e "连接端口 : ${CYAN}$PORT_VAL${NC}"
    else
        echo -e "登录账号 : ${CYAN}Administrator${NC}"
        echo -e "登录密码 : ${YELLOW}$PASSWORD_VAL${NC}"
        echo -e "连接端口 : 默认 3389"
    fi
    echo -e "底层驱动 : 自动匹配 BIOS/EFI，分区表 ID 防写错"
    echo -e "温馨提示 : 重装完成后，可重新运行本脚本选择[选项2]精装系统环境"
    DIVIDER
    LOG_WARN "继续操作将格式化整个硬盘，所有数据将永久丢失！"
    read -r -p "$(echo -e "确认无误并开始执行重装？(y/n) [n]: ")" confirm_install
    confirm_install=${confirm_install:-n}

    if [[ "$confirm_install" != "y" && "$confirm_install" != "Y" ]]; then
        LOG_INFO "操作已取消，系统未做任何修改。"
        exit 0
    fi

    LOG_INFO "开始从你的私人仓库下载顶级重装引擎 (zqh2333/reinstall)..."
    # 这里已经替换为你 fork 后的仓库地址
    curl -sSL -O https://raw.githubusercontent.com/zqh2333/reinstall/main/reinstall.sh
    chmod +x reinstall.sh

    LOG_SUCCESS "核心引擎下载完毕，正在组装参数并下发重装指令..."

    if [[ "$os_type_choice" == "1" ]]; then
        bash reinstall.sh $OS_CMD --password "$PASSWORD_VAL" --ssh-port "$PORT_VAL"
    else
        bash reinstall.sh $OS_CMD --password "$PASSWORD_VAL"
    fi
    
    # 捕获上一条底层命令的退出状态，成功则触发重启
    if [[ $? -eq 0 ]]; then
        DIVIDER
        LOG_SUCCESS "🎉 所有引导修改已就绪！"
        LOG_INFO "系统将在 3 秒后自动重启并真正进入后台格式化安装流程..."
        if [[ "$os_type_choice" == "2" ]]; then
            echo -e "【Windows】脱机下载 ISO 及注入驱动通常需 ${YELLOW}20-40 分钟${NC}，请通过 VNC 观察。"
        else
            echo -e "【Linux】通常需 ${YELLOW}5-15 分钟${NC}。稍后请使用新端口和密码重新连接。"
        fi
        DIVIDER
        sleep 3
        reboot
    else
        LOG_ERROR "底层引擎执行失败，请检查上方报错信息。已取消系统重启。"
        exit 1
    fi
else
    LOG_ERROR "无效的选择，已退出。"
    exit 1
fi
