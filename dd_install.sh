#!/bin/sh
# ==========================================
# 阶段一：跨平台基础环境自举 (纯 sh 语法，无脑兼容各大纯净系统)
# ==========================================
if ! command -v bash >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1 || ! command -v wget >/dev/null 2>&1 || ! command -v awk >/dev/null 2>&1 || ! command -v bc >/dev/null 2>&1; then
    echo "[INFO] 检测到基础环境不全，正在自动安装必要组件 (bash, curl, wget, awk, bc)..."
    if [ -f /etc/alpine-release ]; then
        apk update >/dev/null 2>&1 && apk add --no-cache bash curl wget socat iproute2 gawk bc >/dev/null 2>&1
    elif [ -f /etc/debian_version ]; then
        apt-get update -y >/dev/null 2>&1 && apt-get install -y bash curl wget socat iproute2 gawk bc >/dev/null 2>&1
    elif [ -f /etc/redhat-release ]; then
        yum clean all >/dev/null 2>&1 && yum install -y bash curl wget socat iproute gawk bc >/dev/null 2>&1
    fi
fi

# ==========================================
# 阶段二：核心魔法 - 解释器升维
# ==========================================
if [ -z "$BASH_VERSION" ]; then
    exec bash "$0" "$@"
fi

# ==========================================
# 阶段三：主业务逻辑 (完全运行于 Bash 环境)
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

if [ "$(id -u)" != "0" ]; then
    LOG_ERROR "权限不足！请使用 root 用户运行此脚本。"
    exit 1
fi

LOG_SUCCESS "系统环境就绪，校验完毕。"
sleep 1

while true; do
    clear
    DIVIDER
    echo -e "${BOLD}        全平台 DD 重装与系统环境/SSL配置工具 (终极版)        ${NC}"
    DIVIDER
    echo -e "  ${GREEN}1) [系统] 一键 DD 重装系统${NC} (支持 Linux / Windows 互刷)"
    echo -e "  ${CYAN}2) [环境] 独立配置系统环境${NC} (主机名/时区/Swap/BBR/改密码)"
    echo -e "  ${YELLOW}3) [证书] 自动申请/续签 SSL 证书${NC} (调用专属 SSL-Renewal)"
    echo -e "  ${BLUE}4) [测试] IP 质量与解锁综合检测${NC} (IP风险/流媒体/AI/邮局)"
    echo -e "  ${CYAN}5) [节点] 优质 SNI 连通性测试${NC} (VLESS-Reality必备)"
    echo -e "  ${RED}0) 退出脚本${NC}"
    DIVIDER
    
    read -r -p "$(echo -e "${BOLD}请输入序号选择功能 [0-5]: ${NC}")" main_choice
    main_choice=${main_choice:-1}

    if [[ "$main_choice" == "5" ]]; then
        clear
        DIVIDER
        echo -e "${BOLD}        [ 节点 SNI 域名连通性与 TLS 1.3 探测工具 ]        ${NC}"
        DIVIDER
        read -r -p "$(echo -e "请输入需要测试的 ${CYAN}SNI 域名${NC} (例如: www.nintendo.co.jp): ")" input_domain
        
        if [[ -z "$input_domain" ]]; then
            LOG_WARN "未输入域名，已取消测试。"
            read -r -p "按回车键返回主菜单..." 
            continue
        fi

        DOMAIN="$input_domain"
        LOG_INFO "正在测试 SNI 域名: ${BOLD}$DOMAIN${NC}"
        SUB_DIVIDER

        echo -e "\n${CYAN}[1/3] 解析域名 IP 地址${NC}"
        if ping -c 1 -W 2 "$DOMAIN" > /dev/null 2>&1; then
            LOG_SUCCESS "域名解析正常"
        else
            LOG_ERROR "无法解析域名 $DOMAIN，请检查域名是否正确或尝试其他域名。"
            read -r -p "按回车键返回主菜单..." 
            continue
        fi

        echo -e "\n${CYAN}[2/3] 测试 TLS 1.3 和 HTTP/2 支持情况${NC}"
        CURL_OUTPUT=$(curl -I -v -s -o /dev/null --http2 --tlsv1.3 --connect-timeout 5 https://"$DOMAIN" 2>&1)

        if echo "$CURL_OUTPUT" | grep -qi "ALPN, offering h2"; then
             if echo "$CURL_OUTPUT" | grep -qi "ALPN, server accepted to use h2"; then
                 LOG_SUCCESS "支持 HTTP/2 (h2)"
             else
                 LOG_WARN "未检测到服务端接受 HTTP/2 (h2)，部分环境可能影响伪装效果"
             fi
        else
             LOG_WARN "本机 curl 未尝试或不支持 HTTP/2，请确保 curl 版本较新"
        fi

        if echo "$CURL_OUTPUT" | grep -qi "TLSv1.3"; then
            LOG_SUCCESS "支持 TLS 1.3"
        else
            LOG_ERROR "目标网站不支持 TLS 1.3，绝对不能用于 VLESS-Reality！"
            read -r -p "按回车键返回主菜单..." 
            continue
        fi

        echo -e "\n${CYAN}[3/3] 测试从当前 VPS 访问该域名的延迟与连通性${NC}"
        HTTP_CODE=$(curl -I -s -o /dev/null -w "%{http_code}" --connect-timeout 5 https://"$DOMAIN")

        if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "301" || "$HTTP_CODE" == "302" ]]; then
            LOG_SUCCESS "连通性极佳，HTTP 状态码: $HTTP_CODE"
            TIME_TOTAL=$(curl -o /dev/null -s -w "%{time_total}\n" https://"$DOMAIN")
            echo -e " ${GREEN}⏱️ 握手总耗时: ${TIME_TOTAL} 秒${NC}"
            DIVIDER
            LOG_SUCCESS "结论: 测试完成！如果以上全部为绿色，则该域名非常适合作为您的 Reality SNI！"
        else
            LOG_ERROR "连通性不佳或被拦截，HTTP 状态码: $HTTP_CODE"
            LOG_WARN "强烈建议换一个域名！"
            DIVIDER
        fi

        read -r -p "按回车键返回主菜单..." 

    elif [[ "$main_choice" == "4" ]]; then
        clear
        DIVIDER
        echo -e "${BOLD}       [ IP 质量 / 风险评估 / 流媒体与 AI 解锁检测 ]       ${NC}"
        DIVIDER
        LOG_INFO "正在拉取权威 IP 综合检测组件 (IPQuality)..."
        
        curl -sSL -o ipcheck.sh "https://raw.githubusercontent.com/xykt/IPQuality/main/ip.sh"
        
        if [[ -s ipcheck.sh ]]; then
            chmod +x ipcheck.sh
            LOG_SUCCESS "组件拉取成功，即将为您呈现多维度综合检测报告！"
            SUB_DIVIDER
            bash ipcheck.sh
            rm -f ipcheck.sh
            DIVIDER
            LOG_SUCCESS "IP 综合检测执行完毕！"
        else
            LOG_ERROR "获取检测脚本失败，请检查服务器网络与 GitHub 的连接。"
            rm -f ipcheck.sh
        fi
        
        DIVIDER
        read -r -p "按回车键返回主菜单..." 

    elif [[ "$main_choice" == "3" ]]; then
        clear
        DIVIDER
        echo -e "${BOLD}              [ SSL 证书自动申请与续签工具 ]               ${NC}"
        DIVIDER
        
        # --- SSL 存在检测逻辑 ---
        if [ -d "$HOME/.acme.sh" ] || command -v acme.sh >/dev/null 2>&1; then
            LOG_WARN "检测到系统已安装过 acme.sh 证书环境。"
            read -r -p "是否继续拉取专属脚本并覆盖执行？(y/n) [n]: " override_ssl
            override_ssl=${override_ssl:-n}
            if [[ "$override_ssl" != "y" && "$override_ssl" != "Y" ]]; then
                LOG_INFO "已取消 SSL 配置任务，保留现有环境。"
                read -r -p "按回车键返回主菜单..." 
                continue
            fi
        fi

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
        while true; do
            clear
            DIVIDER
            echo -e "${BOLD}                  [ 系统环境独立配置面板 ]                   ${NC}"
            DIVIDER
            echo -e "  ${CYAN}1) 修改主机名 (Hostname)${NC}"
            echo -e "  ${CYAN}2) 修改系统时区 (Timezone)${NC}"
            echo -e "  ${CYAN}3) 添加虚拟内存 (Swap自动推荐)${NC}"
            echo -e "  ${YELLOW}4) 网络加速与内核管理面板 (BBR智能推荐)${NC}"
            echo -e "  ${CYAN}5) 修改 Root 登录密码${NC}"
            echo -e "  ${GREEN}0) 返回上一菜单${NC}"
            DIVIDER
            
            read -r -p "$(echo -e "${BOLD}请选择要执行的配置项 [0-5]: ${NC}")" env_choice
            
            case $env_choice in
                1)
                    SUB_DIVIDER
                    # --- 主机名检测逻辑 ---
                    current_host=$(hostname 2>/dev/null || cat /etc/hostname 2>/dev/null)
                    LOG_INFO "当前系统主机名为: ${CYAN}${current_host}${NC}"
                    read -r -p "$(echo -e "请输入新的${CYAN}主机名 (Hostname)${NC} [直接回车保持原样]: ")" input_hostname
                    
                    if [[ -n "$input_hostname" && "$input_hostname" != "$current_host" ]]; then
                        if command -v hostnamectl >/dev/null 2>&1; then
                            hostnamectl set-hostname "$input_hostname"
                        else
                            echo "$input_hostname" > /etc/hostname
                            hostname "$input_hostname"
                        fi
                        LOG_SUCCESS "主机名已设置为: ${BOLD}$input_hostname${NC} (重连 SSH 后生效)"
                    else
                        LOG_INFO "未检测到输入或未发生改变，已跳过主机名修改。"
                    fi
                    read -r -p "按回车键继续..." 
                    ;;
                2)
                    SUB_DIVIDER
                    # --- 时区检测逻辑 ---
                    current_time=$(date +"%Y-%m-%d %H:%M:%S %Z")
                    LOG_INFO "当前系统时间与时区: ${CYAN}${current_time}${NC}"
                    read -r -p "$(echo -e "请输入新${CYAN}系统时区${NC} [默认: Asia/Shanghai, 输入 n 跳过]: ")" input_timezone
                    
                    if [[ "$input_timezone" == "n" || "$input_timezone" == "N" ]]; then
                        LOG_INFO "已取消时区修改，保留现状。"
                    else
                        TIMEZONE_VAL=${input_timezone:-Asia/Shanghai}
                        if command -v timedatectl >/dev/null 2>&1; then
                            timedatectl set-timezone "$TIMEZONE_VAL"
                        else
                            ln -sf /usr/share/zoneinfo/"$TIMEZONE_VAL" /etc/localtime
                        fi
                        LOG_SUCCESS "时区已成功设置为: ${BOLD}$TIMEZONE_VAL${NC}"
                    fi
                    read -r -p "按回车键继续..." 
                    ;;
                3)
                    SUB_DIVIDER
                    phy_ram=$(free -m | awk '/^Mem:/{print $2}')
                    
                    if [ -z "$phy_ram" ] || ! [[ "$phy_ram" =~ ^[0-9]+$ ]]; then
                        phy_ram=1024
                        rec_swap=1024
                    elif [ "$phy_ram" -le 2048 ]; then
                        rec_swap=$((phy_ram * 2))
                    elif [ "$phy_ram" -le 8192 ]; then
                        rec_swap=$phy_ram
                    else
                        rec_swap=4096
                    fi
                    
                    echo -e " 探测到物理内存: ${CYAN}${phy_ram} MB${NC}"
                    echo -e " 智能推荐 Swap : ${GREEN}${rec_swap} MB${NC}"
                    SUB_DIVIDER
                    
                    read -r -p "$(echo -e "请输入需要添加的${CYAN}Swap 大小(MB)${NC} [默认: ${GREEN}${rec_swap}${NC}]: ")" input_swap
                    SWAP_VAL=${input_swap:-$rec_swap}
                    
                    if [[ "$SWAP_VAL" -gt 0 ]] && [[ "$SWAP_VAL" =~ ^[0-9]+$ ]]; then
                        current_swap=$(free -m | awk '/^Swap:/{print $2}')
                        if [[ "$current_swap" -gt 0 ]]; then
                            LOG_WARN "系统当前已存在 ${current_swap} MB 的 Swap 挂载。"
                            read -r -p "是否要卸载原有 Swap 并强行按照新配置重建？(y/n) [n]: " override_swap
                            override_swap=${override_swap:-n}
                            
                            if [[ "$override_swap" == "y" || "$override_swap" == "Y" ]]; then
                                LOG_INFO "正在为您卸载并清理旧的 Swap 配置..."
                                swapoff -a >/dev/null 2>&1
                                rm -f /swapfile
                                sed -i '/swap/d' /etc/fstab
                            else
                                LOG_INFO "已取消重建，保留原有 Swap 配置。"
                                read -r -p "按回车键继续..." 
                                continue
                            fi
                        fi

                        LOG_INFO "正在为您创建 ${SWAP_VAL}MB 的 Swap 文件，请稍候 (视硬盘性能可能需要十几秒)..."
                        dd if=/dev/zero of=/swapfile bs=1M count="$SWAP_VAL" status=none
                        chmod 600 /swapfile
                        mkswap /swapfile >/dev/null 2>&1
                        swapon /swapfile
                        if ! grep -q "/swapfile" /etc/fstab; then
                            echo "/swapfile none swap sw 0 0" >> /etc/fstab
                        fi
                        LOG_SUCCESS "Swap (${SWAP_VAL} MB) 创建并永久挂载成功!"
                    else
                        LOG_WARN "输入值非法，已取消创建。"
                    fi
                    read -r -p "按回车键继续..." 
                    ;;
                4)
                    while true; do
                        clear
                        DIVIDER
                        echo -e "${BOLD}              [ 网络加速与智能内核优化面板 ]               ${NC}"
                        DIVIDER
                        
                        kernel_version=$(uname -r | awk -F. '{print $1"."$2}')
                        kernel_full=$(uname -r)
                        current_cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
                        
                        if [ -f /proc/user_beancounters ]; then
                            virt_type="OpenVZ"
                        elif command -v systemd-detect-virt >/dev/null 2>&1; then
                            virt_type=$(systemd-detect-virt)
                        else
                            virt_type="KVM/Unknown"
                        fi

                        if [[ "$current_cc" == "bbr" ]]; then
                            accel_status="${GREEN}已开启官方 BBR${NC}"
                        elif [[ "$current_cc" == "bbrplus" ]]; then
                            accel_status="${GREEN}已开启 BBRplus${NC}"
                        elif [[ -n "$(lsmod 2>/dev/null | grep appex)" ]]; then
                            accel_status="${GREEN}已开启 锐速(Lotserver)${NC}"
                        else
                            accel_status="${YELLOW}未完全优化 (当前: ${current_cc:-无})${NC}"
                        fi

                        echo -e " 架构类型: ${CYAN}${virt_type}${NC}"
                        echo -e " 当前内核: ${CYAN}${kernel_full}${NC}"
                        echo -e " 加速状态: ${accel_status}"
                        DIVIDER
                        echo -e "  ${GREEN}1) [推荐] 一键智能极致优化${NC} (自动检测环境/开启BBR/优化TCP并发)"
                        echo -e "  ${YELLOW}2) [进阶] 安装第三方魔改内核${NC} (调用外部脚本，适合旧版系统)"
                        echo -e "  ${RED}9) [清理] 恢复系统网络默认值${NC}"
                        echo -e "  ${NC}0) 返回上一级${NC}"
                        DIVIDER
                        
                        read -r -p "$(echo -e "${BOLD}请输入序号 [1]: ${NC}")" bbr_choice
                        bbr_choice=${bbr_choice:-1}

                        case $bbr_choice in
                            1)
                                SUB_DIVIDER
                                # --- 优化：防御重复覆盖，防止盲目清空参数 ---
                                if [[ "$current_cc" == *"bbr"* ]]; then
                                    LOG_WARN "检测到系统当前已经开启了 BBR 相关的网络加速。"
                                    read -r -p "是否强制清空旧参数，重新注入高并发 TCP 优化配置？(y/n) [n]: " override_bbr
                                    override_bbr=${override_bbr:-n}
                                    if [[ "$override_bbr" != "y" && "$override_bbr" != "Y" ]]; then
                                        LOG_INFO "已取消网络参数重置。"
                                        read -r -p "按回车键继续..." 
                                        continue
                                    fi
                                fi

                                LOG_INFO "开始执行智能网络优化流程..."
                                
                                if [[ "$virt_type" == *"openvz"* || "$virt_type" == *"lxc"* || "$virt_type" == *"OpenVZ"* ]]; then
                                    LOG_WARN "检测到容器虚拟化 ($virt_type)，无法修改底层内核限制。"
                                    LOG_INFO "将尝试直接开启原生 BBR (需宿主机支持)..."
                                else
                                    LOG_INFO "检测到独立内核环境 ($virt_type)，安全校验通过。"
                                fi

                                if [[ $(echo "$kernel_version >= 4.9" | bc 2>/dev/null || echo 1) -eq 1 ]]; then
                                    LOG_INFO "正在配置 TCP BBR 拥塞控制算法..."
                                    sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
                                    sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
                                    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
                                    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
                                else
                                    LOG_WARN "内核版本 ($kernel_version) 较老，无法保证 BBR 原生支持！建议使用菜单 2 升级内核。"
                                fi

                                LOG_INFO "正在注入高级网络吞吐量优化参数..."
                                
                                for key in fs.file-max net.ipv4.tcp_tw_reuse net.ipv4.ip_local_port_range net.ipv4.tcp_rmem net.ipv4.tcp_wmem net.core.somaxconn net.ipv4.tcp_max_syn_backlog net.ipv4.tcp_fastopen; do
                                    sed -i "/^${key}/d" /etc/sysctl.conf
                                done

                                cat >> /etc/sysctl.conf << EOF
fs.file-max = 1000000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.core.somaxconn = 8192
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0
EOF
                                cat > /etc/security/limits.conf << EOF
* soft nofile 1000000
* hard nofile 1000000
root soft nofile 1000000
root hard nofile 1000000
EOF
                                ulimit -n 1000000 2>/dev/null
                                
                                sysctl -p >/dev/null 2>&1
                                current_cc_check=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
                                
                                if [[ "$current_cc_check" == *"bbr"* ]]; then
                                    LOG_SUCCESS "智能优化大功告成！原生 BBR 与高并发参数已生效。"
                                else
                                    LOG_WARN "高并发参数已生效，但 BBR 开启失败 (可能受限于宿主机或极老内核)。"
                                fi
                                read -r -p "按回车键继续..." 
                                ;;
                                
                            2)
                                SUB_DIVIDER
                                LOG_WARN "即将调用第三方脚本。请注意：在较新系统或 OpenVZ 上强换内核极易导致系统失联变砖！"
                                read -r -p "确认要继续吗？(y/n) [n]: " confirm_kernel
                                if [[ "$confirm_kernel" == "y" || "$confirm_kernel" == "Y" ]]; then
                                    LOG_INFO "正在拉取核心组件..."
                                    wget -N --no-check-certificate "https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh" -O tcp_net.sh >/dev/null 2>&1
                                    if [[ -f tcp_net.sh ]]; then
                                        chmod +x tcp_net.sh
                                        bash tcp_net.sh
                                        rm -f tcp_net.sh
                                    else
                                        LOG_ERROR "获取组件失败，请检查网络。"
                                    fi
                                else
                                    LOG_INFO "已取消操作。"
                                fi
                                read -r -p "按回车键继续..." 
                                ;;
                                
                            9)
                                SUB_DIVIDER
                                LOG_INFO "正在清理所有加速与自定义 TCP 参数..."
                                sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
                                sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
                                sed -i '/fs.file-max/d' /etc/sysctl.conf
                                sed -i '/net.ipv4.tcp_/d' /etc/sysctl.conf
                                sed -i '/net.core.somaxconn/d' /etc/sysctl.conf
                                sed -i '/net.ipv4.ip_local_port_range/d' /etc/sysctl.conf
                                
                                echo "net.core.default_qdisc=pfifo_fast" >> /etc/sysctl.conf
                                echo "net.ipv4.tcp_congestion_control=cubic" >> /etc/sysctl.conf
                                sysctl -p >/dev/null 2>&1
                                LOG_SUCCESS "已完全恢复系统网络默认值。"
                                read -r -p "按回车键继续..." 
                                ;;
                                
                            0) break ;;
                            *) LOG_ERROR "输入有误" ; sleep 1 ;;
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
                        LOG_INFO "检测到空输入，已取消修改密码操作。"
                    fi
                    read -r -p "按回车键继续..." 
                    ;;
                0)
                    LOG_SUCCESS "正在返回主菜单..."
                    break 
                    ;;
                *)
                    LOG_ERROR "无效的选项，请重新选择。"
                    sleep 1
                    ;;
            esac
        done

    elif [[ "$main_choice" == "1" ]]; then
        clear
        DIVIDER
        echo -e "${BOLD}        [ 全平台/全网络/全自动 DD 重装脚本 (底层引擎) ]       ${NC}"
        DIVIDER

        LOG_INFO "正在探测当前网络拓扑结构..."
        MAIN_IP=$(ip -4 route get 8.8.8.8 2>/dev/null | grep -oP 'src \K\S+')
        GATEWAY=$(ip -4 route show default 2>/dev/null | grep -oP 'via \K\S+' | head -n 1)
        INTERFACE=$(ip -4 route get 8.8.8.8 2>/dev/null | grep -oP 'dev \K\S+' | head -n 1)

        if [[ -n "$INTERFACE" ]]; then
            SUBNET_PREFIX=$(ip -o -f inet addr show "$INTERFACE" 2>/dev/null | awk '{print $4}' | cut -d/ -f2 | head -n 1)
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

        LOG_SUCCESS "网络探测完成："
        echo -e "   - 公网 IP  : ${BOLD}${MAIN_IP:-未知}${NC}"
        echo -e "   - 网关     : ${BOLD}${GATEWAY:-未知}${NC}"
        echo -e "   - 子网掩码 : ${BOLD}${NETMASK:-未知}${NC}"
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
            LOG_ERROR "无效的系统类型选择。"
            sleep 1
            continue
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
        DIVIDER
        LOG_WARN "警告：继续操作将格式化整个硬盘，当前系统所有数据将永久丢失！"
        read -r -p "$(echo -e "确认无误并开始执行重装？(y/n) [n]: ")" confirm_install
        confirm_install=${confirm_install:-n}

        if [[ "$confirm_install" != "y" && "$confirm_install" != "Y" ]]; then
            LOG_INFO "操作已取消，返回主菜单。"
            sleep 1
            continue
        fi

        LOG_INFO "开始下载重装引擎..."
        curl -sSL -O https://raw.githubusercontent.com/zqh2333/reinstall/main/reinstall.sh
        chmod +x reinstall.sh

        if [[ "$os_type_choice" == "1" ]]; then
            bash reinstall.sh $OS_CMD --password "$PASSWORD_VAL" --ssh-port "$PORT_VAL"
        else
            bash reinstall.sh $OS_CMD --password "$PASSWORD_VAL"
        fi
        
        if [[ $? -eq 0 ]]; then
            DIVIDER
            LOG_SUCCESS "[OK] 引导修改就绪，系统将在 3 秒后重启..."
            sleep 3
            reboot
        else
            LOG_ERROR "引擎执行失败，请检查网络或配置信息。"
            read -r -p "按回车键返回主菜单..." 
        fi

    elif [[ "$main_choice" == "0" ]]; then
        clear
        LOG_SUCCESS "已退出全平台配置工具，祝您使用愉快！"
        exit 0
    else
        LOG_ERROR "无效的选项，请输入 0-5 之间的数字。"
        sleep 1
    fi
done
