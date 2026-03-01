#!/bin/bash

# ==========================================
# 检查是否为 root 用户
# ==========================================
if [[ $EUID -ne 0 ]]; then
    echo "错误: 请使用 root 用户运行此脚本"
    exit 1
fi

echo "正在初始化脚本环境..."
if [[ -f /etc/debian_version ]]; then
    apt-get update -y >/dev/null 2>&1
    apt-get install -y wget curl iproute2 >/dev/null 2>&1
elif [[ -f /etc/redhat-release ]]; then
    yum install -y wget curl iproute >/dev/null 2>&1
elif [[ -f /etc/alpine-release ]]; then
    apk add wget curl iproute2 >/dev/null 2>&1
fi

clear
echo "========================================================="
echo "        全平台 DD 重装与系统环境配置工具 (二合一版)      "
echo "========================================================="
echo "  1) 🚀 一键 DD 重装系统 (支持 Linux / Windows 互刷)"
echo "  2) 🛠️ 一键配置系统环境 (修改主机名/时区/Swap/开启BBR)"
echo "========================================================="
read -r -p "请输入序号选择功能 [1]: " main_choice
main_choice=${main_choice:-1}

if [[ "$main_choice" == "2" ]]; then
    # ==========================================
    # 功能 2：系统环境配置
    # ==========================================
    clear
    echo "========================================================="
    echo "                 系统环境一键配置工具                    "
    echo "========================================================="
    
    # 1. 主机名
    read -r -p "请输入新的主机名 (Hostname) [vps]: " input_hostname
    HOSTNAME_VAL=${input_hostname:-vps}
    
    # 2. 时区
    read -r -p "请输入系统时区 [Asia/Shanghai]: " input_timezone
    TIMEZONE_VAL=${input_timezone:-Asia/Shanghai}
    
    # 3. Swap 大小
    read -r -p "请输入需要添加的 Swap 大小(MB)，输入 0 为不添加 [1024]: " input_swap
    SWAP_VAL=${input_swap:-1024}
    
    # 4. BBR
    read -r -p "是否开启 BBR 网络加速 (y/n) [y]: " input_bbr
    input_bbr=${input_bbr:-y}

    echo "---------------------------------------------------------"
    echo "正在应用配置，请稍候..."

    # 设置主机名
    if command -v hostnamectl >/dev/null 2>&1; then
        hostnamectl set-hostname "$HOSTNAME_VAL"
    else
        echo "$HOSTNAME_VAL" > /etc/hostname
        hostname "$HOSTNAME_VAL"
    fi
    echo "✅ 主机名已设置为: $HOSTNAME_VAL"

    # 设置时区
    if command -v timedatectl >/dev/null 2>&1; then
        timedatectl set-timezone "$TIMEZONE_VAL"
    else
        ln -sf /usr/share/zoneinfo/"$TIMEZONE_VAL" /etc/localtime
    fi
    echo "✅ 时区已设置为: $TIMEZONE_VAL"

    # 设置 Swap
    if [[ "$SWAP_VAL" -gt 0 ]]; then
        if swapon --show | grep -q "/swapfile"; then
            echo "⚠️ 检测到已存在 Swap，跳过创建。"
        else
            echo "正在创建 ${SWAP_VAL}MB Swap 文件，这可能需要几十秒时间..."
            dd if=/dev/zero of=/swapfile bs=1M count="$SWAP_VAL" status=none
            chmod 600 /swapfile
            mkswap /swapfile >/dev/null 2>&1
            swapon /swapfile
            if ! grep -q "/swapfile" /etc/fstab; then
                echo "/swapfile none swap sw 0 0" >> /etc/fstab
            fi
            echo "✅ Swap ($SWAP_VAL MB) 创建并挂载成功!"
        fi
    fi

    # 设置 BBR
    if [[ "$input_bbr" == "y" || "$input_bbr" == "Y" ]]; then
        if lsmod | grep -q bbr; then
            echo "✅ BBR 已经是开启状态，无需重复配置。"
        else
            echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
            echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
            sysctl -p >/dev/null 2>&1
            echo "✅ BBR 网络加速已开启!"
        fi
    fi

    echo "========================================================="
    echo "🎉 环境配置全部完成！建议断开 SSH 重新连接以使主机名等显示生效。"
    echo "========================================================="
    exit 0

elif [[ "$main_choice" == "1" ]]; then
    # ==========================================
    # 功能 1：DD 重装系统
    # ==========================================
    clear
    echo "========================================================="
    echo "        全平台/全网络/全自动 DD 重装脚本 (底层引擎)      "
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

    echo "✅ 已自动探测当前网络 (重装引擎将接管复杂网络)："
    echo "   - 公网 IP  : $MAIN_IP"
    echo "   - 网关     : $GATEWAY"
    echo "   - 子网掩码 : $NETMASK"
    echo "========================================================="
    echo "▶ 开始交互式配置 (直接按回车键将使用中括号内的默认值)"
    echo "---------------------------------------------------------"

    echo "请选择要重装的目标系统类型："
    echo "  1) Linux (支持 Debian/Ubuntu/CentOS/Alpine 等)"
    echo "  2) Windows (官方原版 ISO，自动注入 VirtIO 驱动)"
    read -r -p "请输入序号 [1]: " os_type_choice
    os_type_choice=${os_type_choice:-1}

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

    echo "---------------------------------------------------------"
    read -r -p "请输入 Root/Administrator 密码 [qwertyui]: " input_password
    PASSWORD_VAL=${input_password:-qwertyui}

    if [[ "$os_type_choice" == "1" ]]; then
        read -r -p "请输入重装后的 SSH 端口 [22]: " input_port
        PORT_VAL=${input_port:-22}
    fi

    clear
    echo "========================================================="
    echo "最终确认：您的重装配置信息如下"
    echo "========================================================="
    echo "目标系统 : $OS_NAME"
    if [[ "$os_type_choice" == "1" ]]; then
        echo "登录账号 : root"
        echo "登录密码 : $PASSWORD_VAL"
        echo "连接端口 : $PORT_VAL"
    else
        echo "登录账号 : Administrator"
        echo "登录密码 : $PASSWORD_VAL"
        echo "连接端口 : 默认 3389"
    fi
    echo "底层驱动 : 自动匹配 BIOS/EFI，分区表 ID 防写错"
    echo "温馨提示 : 重装完成后，可重新运行本脚本选择[选项2]配置Swap与BBR"
    echo "========================================================="
    echo "⚠️ 警告：继续操作将格式化整个硬盘，所有数据将永久丢失！"
    read -r -p "确认无误并开始执行重装？(y/n) [n]: " confirm_install
    confirm_install=${confirm_install:-n}

    if [[ "$confirm_install" != "y" && "$confirm_install" != "Y" ]]; then
        echo "操作已取消，系统未做任何修改。"
        exit 0
    fi

    echo "开始下载顶级重装引擎 (reinstall.sh)..."
    curl -sSL -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh
    chmod +x reinstall.sh

    echo "引擎下载完毕，开始组装参数并下发重装指令..."

    if [[ "$os_type_choice" == "1" ]]; then
        bash reinstall.sh $OS_CMD --password "$PASSWORD_VAL" --ssh-port "$PORT_VAL"
    else
        bash reinstall.sh $OS_CMD --password "$PASSWORD_VAL"
    fi
    
    # 捕获上一条底层命令的退出状态，成功则触发重启
    if [[ $? -eq 0 ]]; then
        echo "========================================================="
        echo "🎉 所有指令已成功下发！引导修改已就绪。"
        echo "系统将在 3 秒后自动重启并真正进入后台格式化安装流程..."
        if [[ "$os_type_choice" == "2" ]]; then
            echo "【Windows】脱机下载 ISO 及注入驱动通常需 20-40 分钟，请通过 VNC 观察。"
        else
            echo "【Linux】通常需 5-15 分钟。稍后请使用新端口和密码重新连接。"
        fi
        echo "========================================================="
        sleep 3
        reboot
    else
        echo "❌ 底层引擎执行失败，请检查上方报错信息。已取消系统重启。"
        exit 1
    fi
else
    echo "无效的选择，已退出。"
    exit 1
fi
