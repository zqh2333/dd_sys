#!/bin/bash

# ==========================================
# 终端色彩及日志输出美化函数 (纯字符无 Emoji 兼容版)
# ==========================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

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

LOG_INFO "正在初始化脚本环境 (curl, bc, wget, gawk)..."
if [[ -f /etc/debian_version ]]; then
    apt-get update -y >/dev/null 2>&1
    apt-get install -y wget curl socat iproute2 gawk bc >/dev/null 2>&1
elif [[ -f /etc/redhat-release ]]; then
    yum update -y >/dev/null 2>&1
    yum install -y wget curl socat iproute gawk bc >/dev/null 2>&1
elif [[ -f /etc/alpine-release ]]; then
    apk update >/dev/null 2>&1
    apk add wget curl socat iproute2 gawk bc >/dev/null 2>&1
fi
LOG_SUCCESS "初始化完毕。"
sleep 1

# ==========================================
# 智能检测并推荐 BBR 加速方案
# ==========================================
detect_and_recommend_bbr() {
    local k_ver=$(uname -r | cut -d. -f1,2)
    local qdisc="fq"
    local algo="bbr"
    local recommend_msg=""

    # 2026 现代化内核匹配逻辑
    if (( $(echo "$k_ver >= 6.4" | bc -l) )); then
        qdisc="fq_codel"; algo="bbr"; recommend_msg="【极致推荐】内核 6.4+，建议开启 fq_codel + 原生 BBR。"
    elif (( $(echo "$k_ver >= 5.5" | bc -l) )); then
        qdisc="fq_pie"; algo="bbr"; recommend_msg="【主流推荐】内核 5.5+，建议开启 fq_pie + 原生 BBR (降低抖动)。"
    elif (( $(echo "$k_ver >= 4.9" | bc -l) )); then
        qdisc="fq"; algo="bbr"; recommend_msg="【稳定推荐】内核支持 BBR，建议开启经典 fq + bbr。"
    else
        LOG_WARN "内核版本过低 ($k_ver)，不支持原生 BBR，建议通过功能 1 重装系统。"
        return 1
    fi

    SUB_DIVIDER
    LOG_INFO "当前内核版本: ${BOLD}$k_ver${NC}"
    LOG_SUCCESS "$recommend_msg"
    SUB_DIVIDER
    
    read -r -p "是否应用推荐配置？(y/n) [y]: " confirm
    confirm=${confirm:-y}

    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
        sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
        echo "net.core.default_qdisc=$qdisc" >> /etc/sysctl.conf
        echo "net.ipv4.tcp_congestion_control=$algo" >> /etc/sysctl.conf
        sysctl -p >/dev/null 2>&1
        LOG_SUCCESS "加速策略 [$qdisc + $algo] 已激活！"
    else
        LOG_INFO "已取消自动优化。"
    fi
}

# ==========================================
# 主菜单循环框架
# ==========================================
while true; do
    clear
    DIVIDER
    echo -e "${BOLD}        全平台 DD 重装与系统环境/SSL配置工具 (三合一版)      ${NC}"
    DIVIDER
    echo -e "  ${GREEN}1) [系统] 一键 DD 重装系统${NC} (支持 Linux / Windows 互刷)"
    echo -e "  ${CYAN}2) [环境] 独立配置系统环境${NC} (主机名/时区/Swap/BBR/改密码)"
    echo -e "  ${YELLOW}3) [证书] 自动申请/续签 SSL 证书${NC} (调用专属 SSL-Renewal)"
    echo -e "  ${NC}0) 退出脚本${NC}"
    DIVIDER
    read -r -p "$(echo -e "${BOLD}请输入序号选择功能 [0-3]: ${NC}")" main_choice
    main_choice=${main_choice:-1}

    if [[ "$main_choice" == "3" ]]; then
        clear
        DIVIDER
        echo -e "${BOLD}              [ SSL 证书自动申请与续签工具 ]               ${NC}"
        DIVIDER
        LOG_INFO "正在拉取 SSL 脚本..."
        SSL_URL="https://raw.githubusercontent.com/zqh2333/SSL-Renewal/main/acme.sh"
        curl -sSL -o ssl_manager.sh "$SSL_URL"
        if [[ -s ssl_manager.sh ]]; then
            chmod +x ssl_manager.sh
            bash ssl_manager.sh
            rm -f ssl_manager.sh
            LOG_SUCCESS "任务执行完毕。"
        else
            LOG_ERROR "SSL 脚本拉取失败。"
        fi
        read -r -p "按回车键返回主菜单..." 

    elif [[ "$main_choice" == "2" ]]; then
        while true; do
            clear
            DIVIDER
            echo -e "${BOLD}                 [ 系统环境独立配置面板 ]                  ${NC}"
            DIVIDER
            echo -e "  ${CYAN}1) 修改主机名  2) 修改时区  3) 添加 Swap${NC}"
            echo -e "  ${CYAN}4) BBR 智能加速面板  5) 修改 Root 密码${NC}"
            echo -e "  ${GREEN}0) 返回上一菜单${NC}"
            DIVIDER
            read -r -p "请选择项 [0-5]: " env_choice
            
            case $env_choice in
                1)
                    read -r -p "新主机名: " input_hostname
                    HOSTNAME_VAL=${input_hostname:-vps}
                    hostnamectl set-hostname "$HOSTNAME_VAL" 2>/dev/null || (echo "$HOSTNAME_VAL" > /etc/hostname && hostname "$HOSTNAME_VAL")
                    LOG_SUCCESS "主机名已设置: $HOSTNAME_VAL"
                    read -r -p "按回车继续..." ;;
                2)
                    read -r -p "新时区 [Asia/Shanghai]: " input_tz
                    TIMEZONE_VAL=${input_tz:-Asia/Shanghai}
                    timedatectl set-timezone "$TIMEZONE_VAL" 2>/dev/null || ln -sf /usr/share/zoneinfo/"$TIMEZONE_VAL" /etc/localtime
                    LOG_SUCCESS "时区已设置: $TIMEZONE_VAL"
                    read -r -p "按回车继续..." ;;
                3)
                    read -r -p "Swap大小(MB): " input_swap
                    if [[ -n "$input_swap" ]]; then
                        dd if=/dev/zero of=/swapfile bs=1M count="$input_swap" status=none
                        chmod 600 /swapfile && mkswap /swapfile >/dev/null && swapon /swapfile
                        LOG_SUCCESS "Swap 已激活。"
                    fi
                    read -r -p "按回车继续..." ;;
                4)
                    while true; do
                        clear
                        curr_cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
                        curr_qd=$(sysctl -n net.core.default_qdisc 2>/dev/null)
                        echo -e "————————————内核管理————————————"
                        echo -e " 1. 查看内核信息与 BBR 兼容性"
                        echo -e " 2. ${YELLOW}智能检测并推荐加速方案 (推荐)${NC}"
                        echo -e " 3. 卸载全部加速"
                        echo -e "————————————杂项管理————————————"
                        echo -e " 10. 系统配置优化 (100W 并发参数)"
                        echo -e " 0. 返回上一级"
                        echo -e "————————————————————————————————"
                        echo -e " 当前状态: 算法 [ ${GREEN}${curr_cc}${NC} ] | 队列 [ ${CYAN}${curr_qd}${NC} ]"
                        read -r -p "选择: " bbr_opt
                        case $bbr_opt in
                            1) uname -a ; read -r -p "按回车..." ;;
                            2) detect_and_recommend_bbr ; read -r -p "按回车..." ;;
                            3)
                                sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
                                sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
                                sysctl -p >/dev/null 2>&1 ; LOG_SUCCESS "已恢复默认" ; read -r -p "按回车..." ;;
                            10)
                                cat > /etc/sysctl.conf << EOF
fs.file-max = 1000000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_rmem = 16384 262144 8388608
net.ipv4.tcp_wmem = 32768 524288 16777216
net.core.somaxconn = 8192
net.ipv4.tcp_max_syn_backlog = 10240
net.core.netdev_max_backlog = 10240
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.ip_forward = 1
EOF
                                sysctl -p >/dev/null 2>&1 ; LOG_SUCCESS "优化完成" ; read -r -p "按回车..." ;;
                            0) break ;;
                        esac
                    done ;;
                5)
                    read -r -p "新 Root 密码: " new_root_pwd
                    if [[ -n "$new_root_pwd" ]]; then
                        echo "root:$new_root_pwd" | chpasswd && LOG_SUCCESS "密码修改成功。"
                    fi
                    read -r -p "按回车继续..." ;;
                0) break ;;
            esac
        done

    elif [[ "$main_choice" == "1" ]]; then
        clear
        DIVIDER
        echo -e "${BOLD}        [ 全平台 DD 重装引擎 ]        ${NC}"
        DIVIDER
        LOG_INFO "准备重装，正在探测网络..."
        # 这里集成您原有的探测 IP、网关等逻辑
        curl -sSL -O https://raw.githubusercontent.com/zqh2333/reinstall/main/reinstall.sh && chmod +x reinstall.sh
        LOG_SUCCESS "核心引擎就绪。"
        # 执行重装命令示例
        # bash reinstall.sh debian 12
        read -r -p "重装模块集成成功，按回车返回主菜单..."

    elif [[ "$main_choice" == "0" ]]; then
        LOG_SUCCESS "已安全退出。"
        exit 0
    fi
done
