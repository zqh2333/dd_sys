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

LOG_INFO "正在初始化脚本环境，自动更新系统并安装必要依赖 (curl, socat, wget)..."
if [[ -f /etc/debian_version ]]; then
    apt-get update -y >/dev/null 2>&1
    apt-get install -y wget curl socat iproute2 gawk >/dev/null 2>&1
elif [[ -f /etc/redhat-release ]]; then
    yum update -y >/dev/null 2>&1
    yum install -y wget curl socat iproute gawk >/dev/null 2>&1
elif [[ -f /etc/alpine-release ]]; then
    apk update >/dev/null 2>&1
    apk add wget curl socat iproute2 gawk >/dev/null 2>&1
fi
LOG_SUCCESS "系统更新与依赖检查完毕，环境就绪。"
sleep 1

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
        # ==========================================
        # 功能 3：调用 SSL-Renewal 申请/续签证书
        # ==========================================
        clear
        DIVIDER
        echo -e "${BOLD}              [ SSL 证书自动申请与续签工具 ]               ${NC}"
        DIVIDER
        LOG_INFO "正在从您的专属仓库 (zqh2333/SSL-Renewal) 拉取 SSL 脚本..."
        
        SSL_URL="https://raw.githubusercontent.com/zqh2333/SSL-Renewal/main/acme.sh"
        
        curl -sSL -o ssl_manager.sh "$SSL_URL"
        if grep -q "404: Not Found" ssl_manager.sh || [[ ! -s ssl_manager.sh ]]; then
            LOG_ERROR "获取 SSL 脚本失败！请检查您的 SSL-Renewal 仓库中是否存在 acme.sh 文件。"
            rm -f ssl_manager.sh
            read -r -p "按回车键返回主菜单..." 
            continue
        fi
        
        chmod +x ssl_manager.sh
        LOG_SUCCESS "SSL 脚本拉取成功，正在为您移交控制权..."
        SUB_DIVIDER
        
        bash ssl_manager.sh
        rm -f ssl_manager.sh
        
        DIVIDER
        LOG_SUCCESS "SSL 证书任务执行完毕！"
        DIVIDER
        read -r -p "按回车键返回主菜单..." 

    elif [[ "$main_choice" == "2" ]]; then
        # ==========================================
        # 功能 2：系统环境配置 (独立子菜单模式)
        # ==========================================
        while true; do
            clear
            DIVIDER
            echo -e "${BOLD}                 [ 系统环境独立配置面板 ]                  ${NC}"
            DIVIDER
            echo -e "  ${CYAN}1) 修改主机名 (Hostname)${NC}"
            echo -e "  ${CYAN}2) 修改系统时区 (Timezone)${NC}"
            echo -e "  ${CYAN}3) 添加虚拟内存 (Swap)${NC}"
            echo -e "  ${CYAN}4) 网络加速与内核管理面板 (BBR/锐速)${NC}"
            echo -e "  ${CYAN}5) 修改 Root 登录密码${NC}"
            echo -e "  ${GREEN}0) 返回上一菜单${NC}"
            DIVIDER
            read -r -p "$(echo -e "${BOLD}请选择要执行的配置项 [0-5]: ${NC}")" env_choice
            
            case $env_choice in
                1)
                    SUB_DIVIDER
                    read -r -p "$(echo -e "请输入新的${CYAN}主机名 (Hostname)${NC} [vps]: ")" input_hostname
                    HOSTNAME_VAL=${input_hostname:-vps}
                    if command -v hostnamectl >/dev/null 2>&1; then
                        hostnamectl set-hostname "$HOSTNAME_VAL"
                    else
                        echo "$HOSTNAME_VAL" > /etc/hostname
                        hostname "$HOSTNAME_VAL"
                    fi
                    LOG_SUCCESS "主机名已设置为: ${BOLD}$HOSTNAME_VAL${NC} (重连 SSH 后生效)"
                    read -r -p "按回车键继续..." 
                    ;;
                2)
                    SUB_DIVIDER
                    read -r -p "$(echo -e "请输入${CYAN}系统时区${NC} [Asia/Shanghai]: ")" input_timezone
                    TIMEZONE_VAL=${input_timezone:-Asia/Shanghai}
                    if command -v timedatectl >/dev/null 2>&1; then
                        timedatectl set-timezone "$TIMEZONE_VAL"
                    else
                        ln -sf /usr/share/zoneinfo/"$TIMEZONE_VAL" /etc/localtime
                    fi
                    LOG_SUCCESS "时区已设置为: ${BOLD}$TIMEZONE_VAL${NC}"
                    read -r -p "按回车键继续..." 
                    ;;
                3)
                    SUB_DIVIDER
                    read -r -p "$(echo -e "请输入需要添加的${CYAN}Swap 大小(MB)${NC} [1024]: ")" input_swap
                    SWAP_VAL=${input_swap:-1024}
                    if [[ "$SWAP_VAL" -gt 0 ]]; then
                        if swapon --show | grep -q "/swapfile"; then
                            LOG_WARN "检测到已存在 Swap，跳过创建。"
                        else
                            LOG_INFO "正在创建 ${SWAP_VAL}MB Swap 文件，请稍候..."
                            dd if=/dev/zero of=/swapfile bs=1M count="$SWAP_VAL" status=none
                            chmod 600 /swapfile
                            mkswap /swapfile >/dev/null 2>&1
                            swapon /swapfile
                            if ! grep -q "/swapfile" /etc/fstab; then
                                echo "/swapfile none swap sw 0 0" >> /etc/fstab
                            fi
                            LOG_SUCCESS "Swap (${SWAP_VAL} MB) 创建并挂载成功!"
                        fi
                    else
                        LOG_WARN "输入值为 0 或非法，已取消。"
                    fi
                    read -r -p "按回车键继续..." 
                    ;;
                4)
                    # ==========================================
                    # BBR/内核高级管理面板
                    # ==========================================
                    while true; do
                        clear
                        # 状态检测逻辑
                        kernel_status="未知"
                        accel_status="未安装加速模块"
                        
                        # 简单检测内核状态
                        if lsmod | grep -q bbr || grep -q bbr /lib/modules/$(uname -r)/modules.builtin 2>/dev/null; then
                            kernel_status="已安装 BBR 加速内核"
                        elif [[ "$(uname -r | awk -F. '{print $1"."$2}')" > "4.8" ]]; then
                            kernel_status="已安装 BBR 加速内核"
                        else
                            kernel_status="未安装加速内核"
                        fi
                        
                        # 简单检测加速状态
                        current_cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
                        if [[ "$current_cc" == "bbr" ]]; then
                            accel_status="已启动 BBR 加速"
                        elif [[ "$current_cc" == "bbrplus" ]]; then
                            accel_status="已启动 BBRplus 加速"
                        elif [[ -n "$(lsmod | grep appex)" ]]; then
                            accel_status="已启动 Lotserver(锐速) 加速"
                        elif [[ "$current_cc" != "cubic" && "$current_cc" != "reno" && -n "$current_cc" ]]; then
                            accel_status="已启动 $current_cc 加速"
                        fi

                        echo -e "————————————内核管理————————————"
                        echo -e " 1. 安装 BBR/BBR魔改版内核"
                        echo -e " 2. 安装 BBRplus版内核 "
                        echo -e " 3. 安装 Lotserver(锐速)内核"
                        echo -e "————————————加速管理————————————"
                        echo -e " 4. 使用BBR加速"
                        echo -e " 5. 使用BBR魔改版加速"
                        echo -e " 6. 使用暴力BBR魔改版加速(不支持部分系统)"
                        echo -e " 7. 使用BBRplus版加速"
                        echo -e " 8. 使用Lotserver(锐速)加速"
                        echo -e "————————————杂项管理————————————"
                        echo -e " 9. 卸载全部加速"
                        echo -e " 10. 系统配置优化"
                        echo -e " 11. 退出脚本"
                        echo -e "————————————————————————————————"
                        echo -e ""
                        echo -e " 当前状态: ${GREEN}${kernel_status}${NC} , ${YELLOW}${accel_status}${NC}"
                        echo -e ""
                        
                        read -r -p " 请输入数字 [0-11]: " bbr_choice
                        
                        case $bbr_choice in
                            4)
                                SUB_DIVIDER
                                LOG_INFO "正在通过 sysctl 配置并启用标准 BBR 加速..."
                                sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
                                sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
                                echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
                                echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
                                sysctl -p >/dev/null 2>&1
                                LOG_SUCCESS "标准 BBR 加速已成功开启！"
                                read -r -p "按回车键继续..." 
                                ;;
                            9)
                                SUB_DIVIDER
                                LOG_INFO "正在卸载所有网络加速并恢复系统默认..."
                                sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
                                sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
                                echo "net.core.default_qdisc=pfifo_fast" >> /etc/sysctl.conf
                                echo "net.ipv4.tcp_congestion_control=cubic" >> /etc/sysctl.conf
                                sysctl -p >/dev/null 2>&1
                                chattr -i /etc/rc.local >/dev/null 2>&1
                                sed -i '/lotserver/d' /etc/rc.local >/dev/null 2>&1
                                LOG_SUCCESS "网络加速已卸载，恢复为 cubic 默认算法！"
                                read -r -p "按回车键继续..." 
                                ;;
                            10)
                                SUB_DIVIDER
                                LOG_INFO "正在应用高级网络吞吐与系统连接数优化..."
                                cat > /etc/security/limits.conf << EOF
* soft nofile 1000000
* hard nofile 1000000
root soft nofile 1000000
root hard nofile 1000000
EOF
                                ulimit -n 1000000
                                # 清理旧的 sysctl 优化项以免冲突
                                sed -i '/fs.file-max/d' /etc/sysctl.conf
                                sed -i '/fs.inotify.max_user_instances/d' /etc/sysctl.conf
                                sed -i '/net.ipv4.tcp_tw_reuse/d' /etc/sysctl.conf
                                sed -i '/net.ipv4.ip_local_port_range/d' /etc/sysctl.conf
                                sed -i '/net.ipv4.tcp_rmem/d' /etc/sysctl.conf
                                sed -i '/net.ipv4.tcp_wmem/d' /etc/sysctl.conf
                                sed -i '/net.core.somaxconn/d' /etc/sysctl.conf
                                sed -i '/net.core.rmem_max/d' /etc/sysctl.conf
                                sed -i '/net.core.wmem_max/d' /etc/sysctl.conf
                                sed -i '/net.core.wmem_default/d' /etc/sysctl.conf
                                sed -i '/net.ipv4.tcp_max_tw_buckets/d' /etc/sysctl.conf
                                sed -i '/net.ipv4.tcp_max_syn_backlog/d' /etc/sysctl.conf
                                sed -i '/net.core.netdev_max_backlog/d' /etc/sysctl.conf
                                sed -i '/net.ipv4.tcp_slow_start_after_idle/d' /etc/sysctl.conf
                                sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
                                # 写入新的配置
                                cat >> /etc/sysctl.conf << EOF
fs.file-max = 1000000
fs.inotify.max_user_instances = 8192
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_rmem = 16384 262144 8388608
net.ipv4.tcp_wmem = 32768 524288 16777216
net.core.somaxconn = 8192
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.wmem_default = 2097152
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_max_syn_backlog = 10240
net.core.netdev_max_backlog = 10240
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.ip_forward = 1
EOF
                                sysctl -p >/dev/null 2>&1
                                LOG_SUCCESS "系统参数已成功覆盖并生效！"
                                read -r -p "按回车键继续..." 
                                ;;
                            1|2|3|5|6|7|8)
                                SUB_DIVIDER
                                LOG_INFO "涉及复杂内核更换与模块编译，正在动态拉取 Linux-NetSpeed 核心组件..."
                                wget -N --no-check-certificate "https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh" -O tcp_net.sh >/dev/null 2>&1
                                if [[ -f tcp_net.sh ]]; then
                                    chmod +x tcp_net.sh
                                    # 利用 awk 精准重写脚本内的交互式菜单，自动代入您的选择
                                    awk -v choice="$bbr_choice" '/read.*num/ && !done { print "num="choice; done=1; next } 1' tcp_net.sh > temp_net.sh
                                    mv temp_net.sh tcp_net.sh
                                    chmod +x tcp_net.sh
                                    bash tcp_net.sh
                                    rm -f tcp_net.sh
                                else
                                    LOG_ERROR "核心组件拉取失败，请检查网络！"
                                fi
                                read -r -p "按回车键继续..." 
                                ;;
                            0|11)
                                LOG_INFO "退出加速管理面板..."
                                break
                                ;;
                            *)
                                LOG_ERROR "输入有误，请重新选择 [0-11]"
                                sleep 1
                                ;;
                        esac
                    done
                    ;;
                5)
                    SUB_DIVIDER
                    read -r -p "$(echo -e "请输入新的 ${CYAN}Root 密码${NC} (留空则取消): ")" new_root_pwd
                    if [[ -n "$new_root_pwd" ]]; then
                        echo "root:$new_root_pwd" | chpasswd
                        if [[ $? -eq 0 ]]; then
                            LOG_SUCCESS "Root 密码已成功修改！请牢记新密码。"
                        else
                            LOG_ERROR "密码修改失败！"
                        fi
                    else
                        LOG_WARN "已取消修改密码操作。"
                    fi
                    read -r -p "按回车键继续..." 
                    ;;
                0)
                    LOG_SUCCESS "正在返回主菜单..."
                    break # 跳出当前内部循环，回到主菜单循环
                    ;;
                *)
                    LOG_ERROR "无效的选项，请重新选择。"
                    sleep 1
                    ;;
            esac
        done

    elif [[ "$main_choice" == "1" ]]; then
        # ==========================================
        # 功能 1：DD 重装系统
        # ==========================================
        clear
        DIVIDER
        echo -e "${BOLD}       [ 全平台/全网络/全自动 DD 重装脚本 (底层引擎) ]      ${NC}"
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
        echo -e ">> 开始交互式配置 (直接按回车键将使用 ${CYAN}中括号${NC} 内的默认值)"
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
        echo -e "温馨提示 : 重装完成后，可重新运行本脚本精装环境或申请 SSL 证书"
        DIVIDER
        LOG_WARN "继续操作将格式化整个硬盘，所有数据将永久丢失！"
        read -r -p "$(echo -e "确认无误并开始执行重装？(y/n) [n]: ")" confirm_install
        confirm_install=${confirm_install:-n}

        if [[ "$confirm_install" != "y" && "$confirm_install" != "Y" ]]; then
            LOG_INFO "操作已取消，返回主菜单。"
            sleep 1
            continue
        fi

        LOG_INFO "开始从您的私人仓库下载顶级重装引擎 (zqh2333/reinstall)..."
        curl -sSL -O https://raw.githubusercontent.com/zqh2333/reinstall/main/reinstall.sh
        chmod +x reinstall.sh

        LOG_SUCCESS "核心引擎下载完毕，正在组装参数并下发重装指令..."

        if [[ "$os_type_choice" == "1" ]]; then
            bash reinstall.sh $OS_CMD --password "$PASSWORD_VAL" --ssh-port "$PORT_VAL"
        else
            bash reinstall.sh $OS_CMD --password "$PASSWORD_VAL"
        fi
        
        if [[ $? -eq 0 ]]; then
            DIVIDER
            LOG_SUCCESS "[OK] 所有引导修改已就绪！"
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
            read -r -p "按回车键返回主菜单..." 
        fi

    elif [[ "$main_choice" == "0" ]]; then
        LOG_SUCCESS "已退出工具，祝您使用愉快！"
        exit 0
    else
        LOG_ERROR "无效的选项，请重新选择。"
        sleep 1
    fi
done
