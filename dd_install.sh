#!/bin/sh
# ==========================================
# 阶段一：跨平台基础环境自举 (纯 sh 语法，无脑兼容各大纯净系统)
# ==========================================
if ! command -v bash >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1 || ! command -v wget >/dev/null 2>&1 || ! command -v awk >/dev/null 2>&1 || ! command -v bc >/dev/null 2>&1 || ! command -v unzip >/dev/null 2>&1; then
    echo "[INFO] 检测到基础环境不全，正在自动安装必要组件 (bash, curl, wget, awk, bc, openssl, unzip)..."
    if [ -f /etc/alpine-release ]; then
        apk update >/dev/null 2>&1 && apk add --no-cache bash curl wget socat iproute2 gawk bc openssl unzip >/dev/null 2>&1
    elif [ -f /etc/debian_version ]; then
        apt-get update -y >/dev/null 2>&1 && apt-get install -y bash curl wget socat iproute2 gawk bc openssl unzip >/dev/null 2>&1
    elif [ -f /etc/redhat-release ]; then
        yum clean all >/dev/null 2>&1 && yum install -y bash curl wget socat iproute gawk bc openssl unzip >/dev/null 2>&1
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
MAGENTA='\033[1;35m'
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

LOG_SUCCESS "系统环境就绪，交互逻辑已极致优化。"
sleep 0.5

while true; do
    clear
    DIVIDER
    echo -e "${BOLD}        全平台 DD 重装与系统环境/SSL配置工具 (终极版)        ${NC}"
    DIVIDER
    echo -e "  ${GREEN}1) [系统] 一键 DD 重装系统${NC} (支持 Linux / Windows 互刷)"
    echo -e "  ${CYAN}2) [环境] 独立配置系统环境${NC} (主机名/时区/Swap/BBR/改密码)"
    echo -e "  ${YELLOW}3) [证书] 自动申请/续签 SSL 证书${NC} (调用专属 SSL-Renewal)"
    echo -e "  ${MAGENTA}4) [测试] IP 质量与解锁综合检测${NC} (IP风险/流媒体/AI/邮局)"
    echo -e "  ${CYAN}5) [节点] 优质 SNI 连通性测试与全局探测${NC} (VLESS-Reality必备)"
    echo -e "  ${GREEN}6) [维护] 每日定时重启与时区校准${NC} (防假死/清理内存碎片)"
    echo -e "  ${RED}0) 退出脚本${NC}"
    DIVIDER
    
    read -r -p "$(echo -e "${BOLD}请输入序号选择功能 [0-6]: ${NC}")" main_choice
    main_choice=${main_choice:-1}

    if [[ "$main_choice" == "6" ]]; then
        clear
        DIVIDER
        echo -e "${BOLD}       [ 每日定时重启与时区强制校准 (清理内存/防假死) ]       ${NC}"
        DIVIDER
        
        LOG_INFO "1. 正在强制锁定服务器系统时区为 Asia/Shanghai (北京时间)..."
        if command -v timedatectl >/dev/null 2>&1; then
            timedatectl set-timezone Asia/Shanghai
        else
            ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
        fi
        current_time=$(date +"%Y-%m-%d %H:%M:%S %Z")
        LOG_SUCCESS "时区校准完成！当前系统时间: ${CYAN}${current_time}${NC}"
        
        SUB_DIVIDER
        LOG_INFO "2. 正在检测系统定时任务组件 (Cron)..."
        if ! command -v crontab >/dev/null 2>&1 || ! pgrep -x "cron" >/dev/null 2>&1 && ! pgrep -x "crond" >/dev/null 2>&1; then
            LOG_WARN "未检测到运行中的 Cron 组件，正在为您自动拉取并配置依赖..."
            if [ -f /etc/alpine-release ]; then
                apk update >/dev/null 2>&1 && apk add --no-cache busybox-suid dcron >/dev/null 2>&1
                rc-update add crond default >/dev/null 2>&1
                rc-service crond start >/dev/null 2>&1
            elif [ -f /etc/debian_version ]; then
                apt-get update -y >/dev/null 2>&1 && apt-get install -y cron >/dev/null 2>&1
                systemctl enable cron >/dev/null 2>&1
                systemctl start cron >/dev/null 2>&1
            elif [ -f /etc/redhat-release ]; then
                yum install -y cronie >/dev/null 2>&1
                systemctl enable crond >/dev/null 2>&1
                systemctl start crond >/dev/null 2>&1
            fi
            LOG_SUCCESS "Cron 组件补齐并启动成功！"
        else
            LOG_SUCCESS "Cron 定时服务已存在且运行正常。"
        fi

        SUB_DIVIDER
        LOG_INFO "3. 每日定时准时释放 (重启) 任务配置"
        
        # 获取当前的重启任务状态
        current_reboot=$(crontab -l 2>/dev/null | grep -E "/sbin/reboot|reboot" | grep -v "^#" | head -n 1)
        if [ -n "$current_reboot" ]; then
            curr_min=$(echo "$current_reboot" | awk '{print $1}')
            curr_hr=$(echo "$current_reboot" | awk '{print $2}')
            printf -v display_time "%02d:%02d" "$curr_hr" "$curr_min"
            echo -e " 当前已设定的任务: ${GREEN}每天 ${BOLD}${display_time}${NC}${GREEN} (北京时间) 自动重启${NC}"
            SUB_DIVIDER
            read -r -p "$(echo -e "👉 请选择操作: [${GREEN}直接回车${NC}]修改时间 | [${RED}d${NC}]删除任务 | [${YELLOW}n${NC}]返回菜单 : ")" modify_reboot
            
            if [[ "$modify_reboot" == "d" || "$modify_reboot" == "D" ]]; then
                reboot_cmd_path=$(command -v reboot || echo "/sbin/reboot")
                crontab -l 2>/dev/null | grep -v "$reboot_cmd_path" | grep -v "/sbin/reboot" | grep -v "reboot" > /tmp/cron_backup
                crontab /tmp/cron_backup
                rm -f /tmp/cron_backup
                LOG_SUCCESS "定时重启任务已成功删除！"
                sleep 1.5
                continue
            elif [[ "$modify_reboot" == "n" || "$modify_reboot" == "N" ]]; then
                continue
            fi
        else
            echo -e " 当前设定状态: ${YELLOW}未设置任何自动重启任务${NC}"
            SUB_DIVIDER
        fi

        read -r -p "$(echo -e "👉 请输入重启时间的${CYAN}小时${NC} (0-23) [默认: 3]: ")" reboot_hour
        reboot_hour=${reboot_hour:-3}
        read -r -p "$(echo -e "👉 请输入重启时间的${CYAN}分钟${NC} (0-59) [默认: 0]: ")" reboot_minute
        reboot_minute=${reboot_minute:-0}

        # 输入合法性强校验
        if ! [[ "$reboot_hour" =~ ^[0-9]+$ ]] || [ "$reboot_hour" -lt 0 ] || [ "$reboot_hour" -gt 23 ]; then
            reboot_hour=3
        fi
        if ! [[ "$reboot_minute" =~ ^[0-9]+$ ]] || [ "$reboot_minute" -lt 0 ] || [ "$reboot_minute" -gt 59 ]; then
            reboot_minute=0
        fi

        # 写入 Cron 规则
        LOG_INFO "正在清理历史重启规则并写入新配置..."
        reboot_cmd_path=$(command -v reboot || echo "/sbin/reboot")
        crontab -l 2>/dev/null | grep -v "$reboot_cmd_path" | grep -v "/sbin/reboot" | grep -v "reboot" > /tmp/cron_backup
        echo "$reboot_minute $reboot_hour * * * $reboot_cmd_path" >> /tmp/cron_backup
        crontab /tmp/cron_backup
        rm -f /tmp/cron_backup

        printf -v final_display_time "%02d:%02d" "$reboot_hour" "$reboot_minute"
        LOG_SUCCESS "大功告成！服务器将于每天北京时间 ${BOLD}${final_display_time}${NC} 自动重启。"
        sleep 2

    elif [[ "$main_choice" == "5" ]]; then
        while true; do
            clear
            DIVIDER
            echo -e "${BOLD}        [ 节点 SNI 域名连通性与 TLS 1.3 探测工具 ]        ${NC}"
            DIVIDER
            echo -e "  ${CYAN}--- 🇯🇵 亚太/本土优选 ---${NC}"
            echo -e "   1) www.nintendo.co.jp   (任天堂)"
            echo -e "   2) www.playstation.com  (索尼)"
            echo -e "   3) www.u-tokyo.ac.jp    (东大)"
            echo -e "   4) www.mercari.com      (煤炉)"
            echo -e "  ${CYAN}--- 🌍 欧美/微软/Apple系万金油 ---${NC}"
            echo -e "   5) www.apple.com        (苹果)"
            echo -e "   6) www.microsoft.com    (微软)"
            echo -e "   7) aws.com              (亚马逊)"
            echo -e "   8) bing.com             (必应)"
            echo -e "   9) amd.com              (AMD)"
            echo -e "  10) snap.licdn.com       (领英静态)"
            echo -e "  ${CYAN}--- 高级自定义与其他 ---${NC}"
            echo -e "  11) ⌨️ 手动输入自定义域名"
            echo -e "  88) 🚀 ${RED}[核武器] XTLS官方扫描器 + RealityChecker 深度质检${NC}"
            echo -e "  99) ⚡ ${GREEN}[一键极速测试] 批量跑完内置库的 32 款全网高优 SNI${NC}"
            echo -e "   0) 返回主菜单"
            DIVIDER
            
            read -r -p "$(echo -e "${BOLD}请输入序号 [0-99]: ${NC}")" sni_choice
            
            DOMAIN=""
            case $sni_choice in
                1) DOMAIN="www.nintendo.co.jp" ;;
                2) DOMAIN="www.playstation.com" ;;
                3) DOMAIN="www.u-tokyo.ac.jp" ;;
                4) DOMAIN="www.mercari.com" ;;
                5) DOMAIN="www.apple.com" ;;
                6) DOMAIN="www.microsoft.com" ;;
                7) DOMAIN="aws.com" ;;
                8) DOMAIN="bing.com" ;;
                9) DOMAIN="amd.com" ;;
                10) DOMAIN="snap.licdn.com" ;;
                11) 
                    read -r -p "$(echo -e "请输入需要测试的 ${CYAN}SNI 域名${NC}: ")" DOMAIN
                    if [[ -z "$DOMAIN" ]]; then
                        LOG_WARN "未输入域名，已取消。"
                        sleep 1
                        continue
                    fi
                    ;;
                88)
                    clear
                    DIVIDER
                    echo -e "${BOLD}     [ RealiTLScanner 盲扫 + RealityChecker 质检引擎 ]     ${NC}"
                    DIVIDER
                    LOG_INFO "正在获取 RealiTLScanner 最新版本..."
                    
                    arch=$(uname -m)
                    case $arch in
                        x86_64) dl_arch="amd64|64" ;;
                        aarch64) dl_arch="arm64" ;;
                        *) LOG_ERROR "不支持的架构: $arch" ; sleep 2 ; continue ;;
                    esac

                    if [ ! -x "./RealiTLScanner" ]; then
                        api_url="https://api.github.com/repos/XTLS/RealiTLScanner/releases/latest"
                        dl_url=$(curl -sSL "$api_url" | grep -oP '"browser_download_url": "\K[^"]*' | grep -i "linux" | grep -iE "($dl_arch)" | grep -v "sha256" | head -n 1)

                        if [ -z "$dl_url" ]; then
                            LOG_ERROR "获取下载链接失败，请检查网络或 GitHub 限制。"
                            sleep 2
                            continue
                        fi

                        LOG_INFO "正在下载: $dl_url"
                        wget -qO scanner_pkg "$dl_url"
                        
                        if head -c 4 scanner_pkg | grep -q "PK"; then
                            unzip -qo scanner_pkg -d scanner_tmp
                            find scanner_tmp -type f -name "*RealiTLScanner*" -exec mv {} ./RealiTLScanner \; 2>/dev/null
                            rm -rf scanner_tmp scanner_pkg
                        elif head -c 4 scanner_pkg | grep -q $'\x1f\x8b'; then
                            mkdir -p scanner_tmp
                            tar -xzf scanner_pkg -C scanner_tmp
                            find scanner_tmp -type f -name "*RealiTLScanner*" -exec mv {} ./RealiTLScanner \; 2>/dev/null
                            rm -rf scanner_tmp scanner_pkg
                        else
                            mv scanner_pkg ./RealiTLScanner
                        fi
                        
                        chmod +x ./RealiTLScanner 2>/dev/null
                        if [ ! -x "./RealiTLScanner" ]; then
                            LOG_ERROR "解析二进制文件失败！"
                            rm -f ./RealiTLScanner scanner_pkg
                            sleep 2
                            continue
                        fi
                        LOG_SUCCESS "RealiTLScanner 部署完成！"
                    else
                        LOG_INFO "检测到已安装 RealiTLScanner，准备就绪。"
                    fi

                    SUB_DIVIDER
                    echo -e " ${YELLOW}推荐极客玩法:${NC}"
                    echo -e "  - 输入 ${CYAN}1.1.1.1${NC} : 扫 Cloudflare IP 背后藏着的万千 SNI"
                    echo -e "  - 输入 ${CYAN}1.2.3.0/24${NC} : 暴力横扫整个 IP 段内的可用 SNI"
                    echo -e "  - 输入 ${CYAN}www.microsoft.com${NC} : 开启无限爬虫模式，顺藤摸瓜找同类域名"
                    echo -e "  - 输入 ${CYAN}https://xxx.com${NC} : 自动爬取网页源码里的所有域名进行测试"
                    SUB_DIVIDER
                    
                    read -r -p "$(echo -e "👉 请输入${GREEN}扫描目标${NC} [默认: 1.1.1.1]: ")" scan_target
                    scan_target=${scan_target:-1.1.1.1}
                    
                    read -r -p "$(echo -e "👉 请输入${GREEN}并发线程数${NC} (越大小鸡越累) [默认: 100]: ")" scan_threads
                    scan_threads=${scan_threads:-100}
                    
                    read -r -p "$(echo -e "👉 请输入单次探测${GREEN}超时时间${NC}(秒) [默认: 5]: ")" scan_timeout
                    scan_timeout=${scan_timeout:-5}

                    clear
                    DIVIDER
                    LOG_INFO "引擎轰鸣中... 目标: ${scan_target} | 线程: ${scan_threads} | 超时: ${scan_timeout}s"
                    LOG_WARN "扫描过程会持续输出。若找到足够多满意的域名，请随时按 ${RED}Ctrl+C${NC} 停止扫描！"
                    DIVIDER
                    sleep 3
                    
                    rm -f out.csv
                    
                    trap 'echo -e "\n${YELLOW}[INFO] 用户手动中断了扫描操作，准备自动整理并质检战利品...${NC}"' SIGINT
                    
                    if [[ "$scan_target" == http* ]]; then
                        ./RealiTLScanner -url "$scan_target" -thread "$scan_threads" -timeout "$scan_timeout" -out out.csv
                    else
                        ./RealiTLScanner -addr "$scan_target" -thread "$scan_threads" -timeout "$scan_timeout" -out out.csv
                    fi
                    
                    trap - SIGINT
                    
                    echo -e "\n"
                    DIVIDER
                    LOG_SUCCESS "初扫结束，正在无缝唤醒 RealityChecker 进行二次质检分析..."
                    sleep 1
                    
                    if [ -s "out.csv" ]; then
                        rc_arch_name=""
                        case $(uname -m) in
                            x86_64) rc_arch_name="amd64" ;;
                            aarch64) rc_arch_name="arm64" ;;
                        esac

                        if [ ! -x "./reality-checker" ] && [ -n "$rc_arch_name" ]; then
                            rc_url="https://github.com/V2RaySSR/RealityChecker/releases/latest/download/reality-checker-linux-${rc_arch_name}.zip"
                            wget -qO rc_tmp.zip "$rc_url"
                            unzip -qo rc_tmp.zip -d rc_tmp_dir
                            find rc_tmp_dir -type f -name "*reality-checker*" -exec mv {} ./reality-checker \; 2>/dev/null
                            chmod +x reality-checker 2>/dev/null
                            rm -rf rc_tmp_dir rc_tmp.zip
                        fi

                        if [ -x "./reality-checker" ]; then
                            clear
                            DIVIDER
                            echo -e "${BOLD}       [ RealityChecker 自动深度质检报告 ]       ${NC}"
                            DIVIDER
                            ./reality-checker csv out.csv
                            echo -e "\n${YELLOW}💡 原始盲扫数据已自动保留在 $(pwd)/out.csv 中。${NC}"
                        else
                            LOG_ERROR "RealityChecker 组件加载失败，已为您降级为基础表格显示："
                            echo "+-----------------+------------------------------------------+-----------------------+"
                            echo "| 目标 IP         | 验证通过的证书域名 (SNI)                 | 证书签发机构          |"
                            echo "+-----------------+------------------------------------------+-----------------------+"
                            awk -F, 'NR>1 { 
                                ip=$1; 
                                domain=$3;
                                if(length(domain) > 40) domain = substr(domain, 1, 37) "...";
                                issuer=$4; 
                                gsub(/"/, "", issuer);
                                if(length(issuer) > 21) issuer = substr(issuer, 1, 18) "...";
                                printf "| %-15s | %-40s | %-21s |\n", ip, domain, issuer 
                            }' out.csv
                            echo "+-----------------+------------------------------------------+-----------------------+"
                            echo -e "${YELLOW}结果保存在 $(pwd)/out.csv 中。${NC}"
                        fi
                    else
                        LOG_WARN "本次扫描未找到任何符合要求的 SNI，可能是目标被封禁或不匹配。"
                    fi
                    
                    read -r -p "按回车键返回菜单..."
                    continue
                    ;;
                99)
                    clear
                    echo -e "\n正在执行深度批量检测，分析握手时间、证书与 CDN，请耐心等待...\n"
                    
                    DOMAIN_LIST="www.nintendo.co.jp www.playstation.com www.u-tokyo.ac.jp www.kyoto-u.ac.jp www.honda.co.jp www.toyota.co.jp www.mercari.com www.apple.com swdist.apple.com www.microsoft.com update.microsoft.com www.amazon.com amd.com apps.mzstatic.com aws.com azure.microsoft.com beacon.gtv-pub.com bing.com catalog.gamepass.com cdn-dynmedia-1.microsoft.com cdn.bizibly.com devblogs.microsoft.com fpinit.itunes.apple.com go.microsoft.com gray-config-prod.api.arc-cdn.net gray.video-player.arcpublishing.com r.bing.com services.digitaleast.mobi snap.licdn.com tag-logger.demandbase.com tag.demandbase.com ts1.tc.mm.bing.net"
                    
                    start_time=$SECONDS
                    total_domains=0
                    success_domains=0
                    unsuited_count=0
                    unnatural_count=0
                    unnatural_list=""
                    
                    # 绘制表头
                    echo "+--------------------------+----------+----------+----------+------+------+--------+----------+"
                    echo "| 最终域名                 | 基础条件 | 握手时间 | 证书时间 | CDN  | 热门 | 推荐   | 页面状态 |"
                    echo "+--------------------------+----------+----------+----------+------+------+--------+----------+"
                    
                    for d in $DOMAIN_LIST; do
                        total_domains=$((total_domains + 1))
                        tmp_headers=$(mktemp)
                        
                        curl_out=$(LC_ALL=C curl -I -s -w "%{time_appconnect} %{http_code}" --tlsv1.3 --connect-timeout 3 https://"$d" -D "$tmp_headers" -o /dev/null)
                        curl_exit=$?
                        
                        if [ $curl_exit -ne 0 ] || [ -z "$curl_out" ]; then
                            unsuited_count=$((unsuited_count + 1))
                            rm -f "$tmp_headers"
                            continue
                        fi
                        
                        success_domains=$((success_domains + 1))
                        read time_app http_code <<< "$curl_out"
                        
                        # 1. 解析握手时间
                        hs_time_ms=$(awk -v t="$time_app" 'BEGIN {printf "%.0f", t * 1000}')
                        hs_col="\033[0m"
                        if [ -z "$hs_time_ms" ] || [ "$hs_time_ms" = "0" ]; then 
                            hs_time_ms="-"
                        else
                            if [ "$hs_time_ms" -gt 400 ]; then hs_col="\033[31m"
                            elif [ "$hs_time_ms" -gt 200 ]; then hs_col="\033[33m"
                            else hs_col="\033[32m"; fi
                            hs_time_ms="${hs_time_ms}ms"
                        fi
                        
                        # 2. 解析证书有效天数
                        cert_days="-"
                        cert_col="\033[0m"
                        if command -v openssl >/dev/null 2>&1; then
                            end_date=$(echo | openssl s_client -servername "$d" -connect "$d:443" 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
                            if [ -n "$end_date" ]; then
                                if [ "$(uname)" = "Darwin" ]; then
                                    end_sec=$(date -j -f "%b %d %T %Y %Z" "$end_date" +%s 2>/dev/null)
                                else
                                    end_sec=$(date -d "$end_date" +%s 2>/dev/null)
                                fi
                                if [ -n "$end_sec" ]; then
                                    now_sec=$(date +%s)
                                    diff_sec=$((end_sec - now_sec))
                                    cert_days=$((diff_sec / 86400))
                                fi
                            fi
                        fi
                        if [ "$cert_days" != "-" ]; then
                            if [ "$cert_days" -lt 30 ]; then cert_col="\033[31m"
                            elif [ "$cert_days" -lt 60 ]; then cert_col="\033[33m"
                            else cert_col="\033[32m"; fi
                            cert_days="${cert_days}天"
                        fi
                        
                        # 3. CDN 检测
                        cdn_val="无"
                        if grep -qiE 'cloudflare|akamai|fastly|cloudfront|cdn' "$tmp_headers"; then
                            cdn_val="高"
                        fi
                        rm -f "$tmp_headers"
                        
                        # 4. 状态码与非自然统计
                        stat_col="\033[0m"
                        if [[ "$http_code" == "200" ]]; then
                            stat_col="\033[32m"
                        elif [[ "$http_code" == "404" ]]; then
                            stat_col="\033[34m"
                        else
                            stat_col="\033[31m"
                            unnatural_count=$((unnatural_count + 1))
                            unnatural_list="${unnatural_list}  - 1个状态码 ${http_code} (${d})\n"
                        fi
                        
                        # 5. 推荐星级计算
                        rec_val="**"
                        if [ "$cdn_val" = "无" ] && [ "${hs_time_ms%ms}" != "-" ] && [ "${hs_time_ms%ms}" -lt 250 ]; then
                            rec_val="****"
                        elif [ "${hs_time_ms%ms}" != "-" ] && [ "${hs_time_ms%ms}" -lt 400 ]; then
                            rec_val="***"
                        fi
                        
                        # ================= 表格 UI 对齐引擎 =================
                        domain_sub=$d
                        if [ ${#domain_sub} -gt 24 ]; then
                            domain_sub="${domain_sub:0:21}..."
                        fi
                        str_d=$(printf " %-24s " "$domain_sub")
                        str_b="   ✓    "
                        
                        # 握手时间动态填充
                        len_h=${#hs_time_ms}; pad_h=$((8 - len_h)); pl_h=$((pad_h / 2)); pr_h=$((pad_h - pl_h))
                        str_h=$(printf "%*s%b%*s" "$pl_h" "" "${hs_col}${hs_time_ms}\033[0m" "$pr_h" "")
                        
                        # 证书天数动态填充
                        v_width_c=0
                        if [[ "$cert_days" == *"天" ]]; then v_width_c=$((${#cert_days} + 1)); else v_width_c=${#cert_days}; fi
                        pad_c=$((8 - v_width_c)); pl_c=$((pad_c / 2)); pr_c=$((pad_c - pl_c))
                        str_c=$(printf "%*s%b%*s" "$pl_c" "" "${cert_col}${cert_days}\033[0m" "$pr_c" "")
                        
                        # CDN动态填充
                        if [ "$cdn_val" = "无" ]; then str_cdn=" \033[32m无\033[0m "; else str_cdn=" \033[31m高\033[0m "; fi
                        
                        str_hot="  - "
                        
                        # 推荐星级填充
                        len_r=${#rec_val}; pad_r=$((6 - len_r)); pl_r=$((pad_r / 2)); pr_r=$((pad_r - pl_r))
                        str_rec=$(printf "%*s%b%*s" "$pl_r" "" "\033[33m${rec_val}\033[0m" "$pr_r" "")
                        
                        # 状态码填充
                        len_s=${#http_code}; pad_s=$((8 - len_s)); pl_s=$((pad_s / 2)); pr_s=$((pad_s - pl_s))
                        str_s=$(printf "%*s%b%*s" "$pl_s" "" "${stat_col}${http_code}\033[0m" "$pr_s" "")
                        
                        # 渲染行
                        echo "|${str_d}|${str_b}|${str_h}|${str_c}|${str_cdn}|${str_hot}|${str_rec}|${str_s}|"
                        echo "+--------------------------+----------+----------+----------+------+------+--------+----------+"
                    done
                    
                    end_time=$SECONDS
                    total_time_s=$((end_time - start_time))
                    
                    success_rate=0
                    if [ "$total_domains" -gt 0 ]; then
                        success_rate=$((success_domains * 100 / total_domains))
                    fi
                    
                    echo -e "\n${BOLD}批量检测报告${NC}"
                    echo "总耗时: ${total_time_s}s"
                    echo "检测域名: ${total_domains} 个"
                    echo "成功率: ${success_rate}%"
                    echo ""
                    if [ "$unsuited_count" -gt 0 ]; then
                        echo "不适合的域名 (${unsuited_count}个): 网络不可达或不支持 TLS 1.3"
                        echo ""
                    fi
                    
                    # 长报告需要确认返回，防止一闪而过
                    read -r -p "按回车键返回主菜单..." 
                    continue
                    ;;
                0)
                    break
                    ;;
                *)
                    LOG_ERROR "无效的选项，请重新输入。"
                    sleep 1
                    continue
                    ;;
            esac
            
            # 单个域名详细测试逻辑
            SUB_DIVIDER
            LOG_INFO "正在测试 SNI 域名: ${BOLD}$DOMAIN${NC}"

            echo -e "\n${CYAN}[1/3] 解析域名 IP 地址${NC}"
            if ping -c 1 -W 2 "$DOMAIN" > /dev/null 2>&1; then
                LOG_SUCCESS "域名解析正常"
            else
                LOG_ERROR "无法解析域名 $DOMAIN，请检查域名是否正确或尝试其他域名。"
                read -r -p "按回车键继续..." 
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
                read -r -p "按回车键继续..." 
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

            read -r -p "按回车键继续..." 
        done

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
        
        # 报告类需要停留
        read -r -p "按回车键返回主菜单..." 

    elif [[ "$main_choice" == "3" ]]; then
        clear
        DIVIDER
        echo -e "${BOLD}              [ SSL 证书自动申请与续签工具 ]               ${NC}"
        DIVIDER
        
        if [ -d "$HOME/.acme.sh" ] || command -v acme.sh >/dev/null 2>&1; then
            LOG_INFO "检测到系统已安装过 acme.sh 环境，正在直接调用您的专属脚本..."
        else
            LOG_INFO "正在从您的专属仓库 (zqh2333/SSL-Renewal) 拉取 SSL 脚本..."
        fi

        SSL_URL="https://raw.githubusercontent.com/zqh2333/SSL-Renewal/main/acme.sh"
        curl -sSL -o ssl_manager.sh "$SSL_URL"
        
        if grep -q "404: Not Found" ssl_manager.sh || [[ ! -s ssl_manager.sh ]]; then
            LOG_ERROR "获取 SSL 脚本失败！请检查您的 SSL-Renewal 仓库中是否存在 acme.sh 文件。"
            rm -f ssl_manager.sh
            sleep 2
            continue
        fi
        
        chmod +x ssl_manager.sh
        LOG_SUCCESS "SSL 脚本拉取成功，正在为您移交控制权..."
        SUB_DIVIDER
        bash ssl_manager.sh
        rm -f ssl_manager.sh
        DIVIDER
        LOG_SUCCESS "SSL 证书任务执行完毕！"
        sleep 2

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
                        LOG_SUCCESS "主机名已成功设置为: ${BOLD}$input_hostname${NC}"
                    else
                        LOG_INFO "未发生改变，已跳过。"
                    fi
                    sleep 1.5
                    ;;
                2)
                    SUB_DIVIDER
                    current_time=$(date +"%Y-%m-%d %H:%M:%S %Z")
                    LOG_INFO "当前系统时间与时区: ${CYAN}${current_time}${NC}"
                    read -r -p "$(echo -e "请输入新${CYAN}系统时区${NC} [默认: Asia/Shanghai, 输入 n 跳过]: ")" input_timezone
                    
                    if [[ "$input_timezone" == "n" || "$input_timezone" == "N" ]]; then
                        LOG_INFO "已保留现状。"
                    else
                        TIMEZONE_VAL=${input_timezone:-Asia/Shanghai}
                        if command -v timedatectl >/dev/null 2>&1; then
                            timedatectl set-timezone "$TIMEZONE_VAL"
                        else
                            ln -sf /usr/share/zoneinfo/"$TIMEZONE_VAL" /etc/localtime
                        fi
                        LOG_SUCCESS "时区已成功设置为: ${BOLD}$TIMEZONE_VAL${NC}"
                    fi
                    sleep 1.5
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
                            LOG_INFO "检测到系统存在旧的 Swap (${current_swap} MB)，正在为您自动卸载并重建..."
                            swapoff -a >/dev/null 2>&1
                            rm -f /swapfile
                            sed -i '/swap/d' /etc/fstab
                        fi

                        LOG_INFO "正在为您创建 ${SWAP_VAL}MB 的 Swap 文件，请稍候..."
                        dd if=/dev/zero of=/swapfile bs=1M count="$SWAP_VAL" status=none
                        chmod 600 /swapfile
                        mkswap /swapfile >/dev/null 2>&1
                        swapon /swapfile
                        if ! grep -q "/swapfile" /etc/fstab; then
                            echo "/swapfile none swap sw 0 0" >> /etc/fstab
                        fi
                        LOG_SUCCESS "Swap (${SWAP_VAL} MB) 创建并永久挂载成功!"
                        sleep 2
                    else
                        LOG_WARN "输入值非法，已取消。"
                        sleep 1.5
                    fi
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
                        echo -e "  ${GREEN}1) [推荐] 一键智能极致优化${NC} (自动检测环境/强刷BBR/优化TCP并发)"
                        echo -e "  ${YELLOW}2) [进阶] 安装第三方魔改内核${NC} (调用外部脚本，适合旧版系统)"
                        echo -e "  ${RED}9) [清理] 恢复系统网络默认值${NC}"
                        echo -e "  ${NC}0) 返回上一级${NC}"
                        DIVIDER
                        
                        read -r -p "$(echo -e "${BOLD}请输入序号 [1]: ${NC}")" bbr_choice
                        bbr_choice=${bbr_choice:-1}

                        case $bbr_choice in
                            1)
                                SUB_DIVIDER
                                if [[ "$current_cc" == *"bbr"* ]]; then
                                    LOG_INFO "系统已开启 BBR，正在为您强制刷新并覆盖高并发 TCP 优化参数..."
                                else
                                    LOG_INFO "正在执行智能网络优化流程..."
                                fi
                                
                                if [[ "$virt_type" == *"openvz"* || "$virt_type" == *"lxc"* || "$virt_type" == *"OpenVZ"* ]]; then
                                    LOG_WARN "检测到容器虚拟化 ($virt_type)，将尝试强制要求宿主机支持原生 BBR..."
                                fi

                                if [[ $(echo "$kernel_version >= 4.9" | bc 2>/dev/null || echo 1) -eq 1 ]]; then
                                    sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
                                    sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
                                    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
                                    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
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
                                    LOG_SUCCESS "配置大功告成！原生 BBR 与高并发参数已生效。"
                                else
                                    LOG_WARN "高并发参数已生效，但 BBR 开启失败 (极可能宿主机不支持)。"
                                fi
                                sleep 2
                                ;;
                                
                            2)
                                SUB_DIVIDER
                                LOG_WARN "警告: 在新系统或 OpenVZ 上强换魔改内核极易导致系统失联变砖！"
                                read -r -p "确认要继续吗？(y/n) [n]: " confirm_kernel
                                if [[ "$confirm_kernel" == "y" || "$confirm_kernel" == "Y" ]]; then
                                    LOG_INFO "正在拉取核心组件..."
                                    wget -N --no-check-certificate "https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh" -O tcp_net.sh >/dev/null 2>&1
                                    if [[ -f tcp_net.sh ]]; then
                                        chmod +x tcp_net.sh
                                        bash tcp_net.sh
                                        rm -f tcp_net.sh
                                    fi
                                else
                                    LOG_INFO "已取消操作。"
                                    sleep 1
                                fi
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
                                LOG_SUCCESS "已完全恢复系统默认网络配置。"
                                sleep 2
                                ;;
                                
                            0) break ;;
                            *) LOG_ERROR "输入有误" ; sleep 1 ;;
                        esac
                    done
                    ;;
                5)
                    SUB_DIVIDER
                    read -r -p "$(echo -e "请输入新的 ${CYAN}Root 密码${NC} (留空则跳过): ")" new_root_pwd
                    if [[ -n "$new_root_pwd" ]]; then
                        echo "root:$new_root_pwd" | chpasswd
                        if [[ $? -eq 0 ]]; then
                            LOG_SUCCESS "Root 密码已成功修改！请务必牢记新密码。"
                        else
                            LOG_ERROR "密码修改失败！"
                        fi
                        sleep 2
                    else
                        LOG_INFO "已跳过修改操作。"
                        sleep 1
                    fi
                    ;;
                0)
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
            sleep 1.5
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
            sleep 2
        fi

    elif [[ "$main_choice" == "0" ]]; then
        clear
        LOG_SUCCESS "已退出全平台配置工具，祝您使用愉快！"
        exit 0
    else
        LOG_ERROR "无效的选项，请输入 0-6 之间的数字。"
        sleep 1
    fi
done
