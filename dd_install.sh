#!/bin/sh
# ==========================================
# 阶段一：跨平台基础环境自举 (纯净稳定版)
# ==========================================
need_install=0
for cmd in bash curl wget awk bc openssl unzip tar ping pgrep ip socat; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        need_install=1
        break
    fi
done

if [ "$need_install" -eq 1 ]; then
    echo "[INFO] 正在自动补全脚本所需的必要组件..."
    if [ -f /etc/alpine-release ]; then
        apk update >/dev/null 2>&1 && apk add --no-cache bash curl wget socat iproute2 gawk bc openssl unzip tar iputils procps >/dev/null 2>&1
    elif [ -f /etc/debian_version ]; then
        apt-get update -y >/dev/null 2>&1 && apt-get install -y bash curl wget socat iproute2 gawk bc openssl unzip tar iputils-ping procps >/dev/null 2>&1
    elif [ -f /etc/redhat-release ]; then
        yum clean all >/dev/null 2>&1 && yum install -y bash curl wget socat iproute gawk bc openssl unzip tar iputils procps-ng >/dev/null 2>&1
    fi
fi

# ==========================================
# 阶段二：核心魔法 - 解释器升维
# ==========================================
if [ -z "$BASH_VERSION" ]; then
    exec bash "$0" "$@"
fi

# ==========================================
# 阶段三：主业务逻辑与核心引擎
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

# ---------------------------------------------------------
# [核心引擎] 深度质检与增量收藏模块 (严丝合缝对齐版)
# ---------------------------------------------------------
deep_check_and_save() {
    local test_list="$1"
    clear
    echo -e "\n${BOLD}正在执行深度质检引擎，分析握手时间、证书与 CDN...${NC}\n"
    
    start_time=$SECONDS
    total_domains=0
    success_domains=0
    unsuited_count=0
    unnatural_count=0
    unnatural_list=""
    > /tmp/good_snis.txt
    
    echo -e "+--------------------------+----------+----------+----------+------+------+--------+----------+"
    echo -e "| 最终域名                 | 基础条件 | 握手时间 | 证书时间 | CDN  | 热门 | 推荐   | 页面状态 |"
    echo -e "+--------------------------+----------+----------+----------+------+------+--------+----------+"

    for d in $test_list; do
        [ -z "$d" ] && continue
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
        
        # 1. 握手时间
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
        
        # 2. 证书
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
        
        # 4. 状态码
        stat_col="\033[0m"
        if [[ "$http_code" == "200" ]]; then stat_col="\033[32m"
        elif [[ "$http_code" == "404" ]]; then stat_col="\033[34m"
        else stat_col="\033[31m"; unnatural_count=$((unnatural_count + 1)); unnatural_list="${unnatural_list}  - 状态码 ${http_code} (${d})\n"; fi
        
        # 5. 星级评价
        rec_val="**"
        if [ "$cdn_val" = "无" ] && [ "${hs_time_ms%ms}" != "-" ] && [ "${hs_time_ms%ms}" -lt 250 ]; then
            rec_val="*****"
        elif [ "$cdn_val" = "无" ] && [ "${hs_time_ms%ms}" != "-" ] && [ "${hs_time_ms%ms}" -lt 400 ]; then
            rec_val="****"
        elif [ "${hs_time_ms%ms}" != "-" ] && [ "${hs_time_ms%ms}" -lt 500 ]; then
            rec_val="***"
        fi
        
        # ================= UI 格式化引擎 =================
        domain_sub=$d
        if [ ${#domain_sub} -gt 24 ]; then domain_sub="${domain_sub:0:21}..."; fi
        str_d=$(printf " %-24s " "$domain_sub")
        
        str_b="   ✓      " 
        
        len_h=${#hs_time_ms}; pad_h=$((10 - len_h)); pl_h=$((pad_h / 2)); pr_h=$((pad_h - pl_h))
        str_h=$(printf "%*s%b%*s" "$pl_h" "" "${hs_col}${hs_time_ms}\033[0m" "$pr_h" "")
        
        v_width_c=0
        if [[ "$cert_days" == *"天" ]]; then v_width_c=$((${#cert_days} + 1)); else v_width_c=${#cert_days}; fi
        pad_c=$((10 - v_width_c)); pl_c=$((pad_c / 2)); pr_c=$((pad_c - pl_c))
        str_c=$(printf "%*s%b%*s" "$pl_c" "" "${cert_col}${cert_days}\033[0m" "$pr_c" "")
        
        if [ "$cdn_val" = "无" ]; then str_cdn="  \033[32m无\033[0m  "; else str_cdn="  \033[31m高\033[0m  "; fi
        
        str_hot="  -   "
        
        len_r=${#rec_val}; pad_r=$((8 - len_r)); pl_r=$((pad_r / 2)); pr_r=$((pad_r - pl_r))
        str_rec=$(printf "%*s%b%*s" "$pl_r" "" "\033[33m${rec_val}\033[0m" "$pr_r" "")
        
        len_s=${#http_code}; pad_s=$((10 - len_s)); pl_s=$((pad_s / 2)); pr_s=$((pad_s - pl_s))
        str_s=$(printf "%*s%b%*s" "$pl_s" "" "${stat_col}${http_code}\033[0m" "$pr_s" "")
        
        echo -e "|${str_d}|${str_b}|${str_h}|${str_c}|${str_cdn}|${str_hot}|${str_rec}|${str_s}|"
        echo -e "+--------------------------+----------+----------+----------+------+------+--------+----------+"
        
        if [[ "$rec_val" == "*****" || "$rec_val" == "****" ]]; then
            echo "$d" >> /tmp/good_snis.txt
        fi
    done

    end_time=$SECONDS
    total_time_s=$((end_time - start_time))
    success_rate=0
    [ "$total_domains" -gt 0 ] && success_rate=$((success_domains * 100 / total_domains))
    
    echo -e "\n${BOLD}⚡ 质检结束报告${NC}"
    echo -e "总耗时: ${total_time_s}s | 连通率: ${success_rate}%"
    
    if [ -s "/tmp/good_snis.txt" ]; then
        cat /tmp/good_snis.txt >> sni_collection.txt
        sort -u sni_collection.txt -o sni_collection.txt
        saved_num=$(wc -l < /tmp/good_snis.txt)
        echo -e "\n${GREEN}🎉 自动提取: 已将本次合格的 $saved_num 个极品(4~5星) SNI 归档至本地收藏库！${NC}"
        rm -f /tmp/good_snis.txt
    else
        echo -e "\n${YELLOW}⚠️ 本次未找到值得入库的高优免死金牌 SNI。${NC}"
    fi
    read -r -p "按回车键返回菜单..."
}

LOG_SUCCESS "初始化完成，稳定版引擎启动。"
sleep 0.5

# ================== 主循环 ==================
while true; do
    clear
    DIVIDER
    echo -e "${BOLD}        全平台 DD 重装与系统环境/SSL配置工具 (终极版)        ${NC}"
    DIVIDER
    echo -e "  ${GREEN}1) [系统] 一键 DD 重装系统${NC} (支持 Linux / Windows 互刷)"
    echo -e "  ${CYAN}2) [环境] 独立配置系统环境${NC} (主机名/时区/Swap/BBR/改密码)"
    echo -e "  ${YELLOW}3) [证书] 自动无感覆盖申请 SSL 证书${NC} (强刷专属配置)"
    echo -e "  ${MAGENTA}4) [测试] IP 质量与解锁综合检测${NC} (IP风险/流媒体/AI/邮局)"
    echo -e "  ${CYAN}5) [节点] 优质 SNI 极速探测与私有质检库${NC} (VLESS-Reality必备)"
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
        
        LOG_INFO "1. 锁定服务器系统时区为 Asia/Shanghai (北京时间)..."
        if command -v timedatectl >/dev/null 2>&1; then timedatectl set-timezone Asia/Shanghai; else ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime; fi
        LOG_SUCCESS "时区校准完成！当前系统时间: ${CYAN}$(date +"%Y-%m-%d %H:%M:%S %Z")${NC}"
        
        SUB_DIVIDER
        LOG_INFO "2. 探测定时任务组件 (Cron)..."
        if ! command -v crontab >/dev/null 2>&1 || ! pgrep -x "cron" >/dev/null 2>&1 && ! pgrep -x "crond" >/dev/null 2>&1; then
            if [ -f /etc/alpine-release ]; then apk update >/dev/null 2>&1 && apk add --no-cache busybox-suid dcron >/dev/null 2>&1 && rc-update add crond default >/dev/null 2>&1 && rc-service crond start >/dev/null 2>&1
            elif [ -f /etc/debian_version ]; then apt-get update -y >/dev/null 2>&1 && apt-get install -y cron >/dev/null 2>&1 && systemctl enable cron >/dev/null 2>&1 && systemctl start cron >/dev/null 2>&1
            elif [ -f /etc/redhat-release ]; then yum install -y cronie >/dev/null 2>&1 && systemctl enable crond >/dev/null 2>&1 && systemctl start crond >/dev/null 2>&1; fi
        fi
        LOG_SUCCESS "Cron 组件就绪！"

        SUB_DIVIDER
        LOG_INFO "3. 每日定时任务配置"
        
        current_reboot=$(crontab -l 2>/dev/null | grep -E "/sbin/reboot|reboot" | grep -v "^#" | head -n 1)
        if [ -n "$current_reboot" ]; then
            curr_min=$(echo "$current_reboot" | awk '{print $1}'); curr_hr=$(echo "$current_reboot" | awk '{print $2}')
            printf -v display_time "%02d:%02d" "$curr_hr" "$curr_min"
            echo -e " 状态: ${GREEN}每天 ${BOLD}${display_time}${NC}${GREEN} (北京时间) 自动重启${NC}"
            SUB_DIVIDER
            read -r -p "$(echo -e "👉 操作: [${GREEN}直接回车${NC}]修改时间 | [${RED}d${NC}]删除任务 | [${YELLOW}n${NC}]返回上一级 : ")" modify_reboot
            
            if [[ "$modify_reboot" == "d" || "$modify_reboot" == "D" ]]; then
                reboot_cmd_path=$(command -v reboot || echo "/sbin/reboot")
                crontab -l 2>/dev/null | grep -v "$reboot_cmd_path" | grep -v "/sbin/reboot" | grep -v "reboot" > /tmp/cron_backup
                crontab /tmp/cron_backup && rm -f /tmp/cron_backup
                LOG_SUCCESS "定时重启任务已成功删除！"
                sleep 1.5; continue
            elif [[ "$modify_reboot" == "n" || "$modify_reboot" == "N" ]]; then 
                continue 
            fi
        else
            echo -e " 状态: ${YELLOW}未设置任何自动重启任务${NC}"
            SUB_DIVIDER
        fi

        read -r -p "$(echo -e "👉 请输入重启时间的${CYAN}小时${NC} (0-23) [默认: 3]: ")" reboot_hour
        reboot_hour=${reboot_hour:-3}
        read -r -p "$(echo -e "👉 请输入重启时间的${CYAN}分钟${NC} (0-59) [默认: 0]: ")" reboot_minute
        reboot_minute=${reboot_minute:-0}

        if ! [[ "$reboot_hour" =~ ^[0-9]+$ ]] || [ "$reboot_hour" -lt 0 ] || [ "$reboot_hour" -gt 23 ]; then reboot_hour=3; fi
        if ! [[ "$reboot_minute" =~ ^[0-9]+$ ]] || [ "$reboot_minute" -lt 0 ] || [ "$reboot_minute" -gt 59 ]; then reboot_minute=0; fi

        reboot_cmd_path=$(command -v reboot || echo "/sbin/reboot")
        crontab -l 2>/dev/null | grep -v "$reboot_cmd_path" | grep -v "/sbin/reboot" | grep -v "reboot" > /tmp/cron_backup
        echo "$reboot_minute $reboot_hour * * * $reboot_cmd_path" >> /tmp/cron_backup
        crontab /tmp/cron_backup && rm -f /tmp/cron_backup

        printf -v final_display_time "%02d:%02d" "$reboot_hour" "$reboot_minute"
        LOG_SUCCESS "服务器将于每天北京时间 ${BOLD}${final_display_time}${NC} 自动重启。"
        sleep 2

    elif [[ "$main_choice" == "5" ]]; then
        while true; do
            clear
            DIVIDER
            echo -e "${BOLD}        [ 节点 SNI 极速探测与私有质检库 ]        ${NC}"
            DIVIDER
            echo -e "  ${CYAN}--- 极简高效引擎 ---${NC}"
            echo -e "   1) ⌨️ 手动输入自定义单域名"
            echo -e "   2) 🚀 ${RED}[核武器] RealiTLScanner 盲扫目标 + 无缝质检与收藏${NC}"
            echo -e "   3) ⚡ ${GREEN}[一键起飞] 批量跑完本地收藏库的所有极品 SNI${NC}"
            echo -e "   0) 返回主菜单"
            DIVIDER
            
            read -r -p "$(echo -e "${BOLD}请输入序号 [0-3]: ${NC}")" sni_choice
            
            case $sni_choice in
                1) 
                    read -r -p "$(echo -e "请输入需要测试的 ${CYAN}SNI 域名${NC}: ")" DOMAIN
                    if [[ -n "$DOMAIN" ]]; then deep_check_and_save "$DOMAIN"; fi
                    ;;
                2)
                    clear
                    DIVIDER
                    echo -e "${BOLD}     [ RealiTLScanner 盲扫 + 无缝二次质检归档 ]     ${NC}"
                    DIVIDER
                    LOG_INFO "正在部署 RealiTLScanner 组件..."
                    arch=$(uname -m)
                    case $arch in
                        x86_64) dl_arch="amd64|64" ;;
                        aarch64) dl_arch="arm64" ;;
                        *) LOG_ERROR "不支持的架构: $arch" ; sleep 2 ; continue ;;
                    esac

                    if [ ! -x "./RealiTLScanner" ]; then
                        api_url="https://api.github.com/repos/XTLS/RealiTLScanner/releases/latest"
                        dl_url=$(curl -sSL "$api_url" | grep -oP '"browser_download_url": "\K[^"]*' | grep -i "linux" | grep -iE "($dl_arch)" | grep -v "sha256" | head -n 1)
                        if [ -n "$dl_url" ]; then
                            wget -qO scanner_pkg "$dl_url"
                            if head -c 4 scanner_pkg | grep -q "PK"; then unzip -qo scanner_pkg -d scanner_tmp && find scanner_tmp -type f -name "*RealiTLScanner*" -exec mv {} ./RealiTLScanner \; 2>/dev/null && rm -rf scanner_tmp scanner_pkg
                            elif head -c 4 scanner_pkg | grep -q $'\x1f\x8b'; then mkdir -p scanner_tmp && tar -xzf scanner_pkg -C scanner_tmp && find scanner_tmp -type f -name "*RealiTLScanner*" -exec mv {} ./RealiTLScanner \; 2>/dev/null && rm -rf scanner_tmp scanner_pkg
                            else mv scanner_pkg ./RealiTLScanner; fi
                            chmod +x ./RealiTLScanner 2>/dev/null
                        fi
                    fi

                    if [ ! -x "./RealiTLScanner" ]; then LOG_ERROR "扫描器部署失败！请检查网络。"; sleep 2; continue; fi

                    read -r -p "$(echo -e "👉 请输入${GREEN}扫描目标${NC} (IP段/域名/网址) [默认: 1.1.1.1]: ")" scan_target
                    scan_target=${scan_target:-1.1.1.1}
                    read -r -p "$(echo -e "👉 请输入${GREEN}并发线程数${NC} [默认: 100]: ")" scan_threads
                    scan_threads=${scan_threads:-100}
                    read -r -p "$(echo -e "👉 请输入单次探测${GREEN}超时时间${NC}(秒) [默认: 5]: ")" scan_timeout
                    scan_timeout=${scan_timeout:-5}

                    clear
                    DIVIDER
                    LOG_INFO "引擎轰鸣中... 目标: ${scan_target} | 线程: ${scan_threads}"
                    LOG_WARN "若感觉成果足够，请按 ${RED}Ctrl+C${NC} 停止扫描，脚本将自动切入质检！"
                    DIVIDER
                    sleep 1
                    
                    rm -f out.csv
                    # 仅在扫描期间接管 Ctrl+C，确保按 Ctrl+C 会切入质检而不是退出
                    trap 'echo -e "\b\b\n${GREEN}✅ 盲扫已手动中断！正在无缝切入质检归档流程...${NC}"' SIGINT
                    
                    if [[ "$scan_target" == http* ]]; then ./RealiTLScanner -url "$scan_target" -thread "$scan_threads" -timeout "$scan_timeout" -out out.csv
                    else ./RealiTLScanner -addr "$scan_target" -thread "$scan_threads" -timeout "$scan_timeout" -out out.csv; fi
                    
                    # 扫描结束，恢复系统默认的 Ctrl+C (直接退出)
                    trap - SIGINT
                    
                    if [ -s "out.csv" ]; then
                        LOG_SUCCESS "初扫结束，正在提取有效名单进入质检引擎..."
                        scan_domains=$(awk -F, 'NR>1 {gsub(/"/, "", $3); print $3}' out.csv | sort -u)
                        if [ -n "$scan_domains" ]; then
                            deep_check_and_save "$scan_domains"
                        else
                            LOG_WARN "无可用域名数据。"
                            sleep 2
                        fi
                    else
                        LOG_WARN "扫描未产出任何结果，可能被拦截或目标错误。"
                        sleep 2
                    fi
                    ;;
                3)
                    if [ ! -s "sni_collection.txt" ]; then
                        LOG_INFO "本地收藏库为空，正在自动注入 32 款全网极品免死金牌 SNI..."
                        echo "www.nintendo.co.jp www.playstation.com www.u-tokyo.ac.jp www.kyoto-u.ac.jp www.honda.co.jp www.toyota.co.jp www.mercari.com www.apple.com swdist.apple.com www.microsoft.com update.microsoft.com www.amazon.com amd.com apps.mzstatic.com aws.com azure.microsoft.com beacon.gtv-pub.com bing.com catalog.gamepass.com cdn-dynmedia-1.microsoft.com cdn.bizibly.com devblogs.microsoft.com fpinit.itunes.apple.com go.microsoft.com gray-config-prod.api.arc-cdn.net gray.video-player.arcpublishing.com r.bing.com services.digitaleast.mobi snap.licdn.com tag-logger.demandbase.com tag.demandbase.com ts1.tc.mm.bing.net" | tr ' ' '\n' > sni_collection.txt
                    fi
                    local_list=$(cat sni_collection.txt)
                    deep_check_and_save "$local_list"
                    ;;
                0) break ;;
                *) LOG_ERROR "输入有误" ; sleep 1 ;;
            esac
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
            SUB_DIVIDER
            bash ipcheck.sh
            rm -f ipcheck.sh
            DIVIDER
        else
            LOG_ERROR "获取检测脚本失败，请检查网络。"
            rm -f ipcheck.sh
        fi
        read -r -p "按回车键返回主菜单..."

    elif [[ "$main_choice" == "3" ]]; then
        clear
        DIVIDER
        echo -e "${BOLD}              [ SSL 证书自动强刷与覆盖工具 ]               ${NC}"
        DIVIDER
        
        LOG_INFO "默认执行强制拉取与覆盖写入逻辑..."
        SSL_URL="https://raw.githubusercontent.com/zqh2333/SSL-Renewal/main/acme.sh"
        curl -sSL -o ssl_manager.sh "$SSL_URL"
        
        if grep -q "404: Not Found" ssl_manager.sh || [[ ! -s ssl_manager.sh ]]; then
            LOG_ERROR "获取 SSL 脚本失败！文件可能不存在。"
            rm -f ssl_manager.sh
            sleep 2
            continue
        fi
        
        chmod +x ssl_manager.sh
        SUB_DIVIDER
        bash ssl_manager.sh
        rm -f ssl_manager.sh
        DIVIDER
        LOG_SUCCESS "SSL 强刷任务执行完毕！"
        sleep 2

    elif [[ "$main_choice" == "2" ]]; then
        while true; do
            clear
            DIVIDER
            echo -e "${BOLD}                  [ 系统环境独立配置面板 ]                   ${NC}"
            DIVIDER
            echo -e "  ${CYAN}1) 修改主机名 (Hostname)${NC}"
            echo -e "  ${CYAN}2) 修改系统时区 (Timezone)${NC}"
            echo -e "  ${CYAN}3) 智能覆盖虚拟内存 (Swap)${NC}"
            echo -e "  ${YELLOW}4) 网络加速与内核管理 (强刷BBR/高并发)${NC}"
            echo -e "  ${CYAN}5) 修改 Root 登录密码${NC}"
            echo -e "  ${GREEN}0) 返回上一菜单${NC}"
            DIVIDER
            
            read -r -p "$(echo -e "${BOLD}请选择要执行的配置项 [0-5]: ${NC}")" env_choice
            
            case $env_choice in
                1)
                    SUB_DIVIDER
                    current_host=$(hostname 2>/dev/null || cat /etc/hostname 2>/dev/null)
                    LOG_INFO "当前系统主机名: ${CYAN}${current_host}${NC}"
                    read -r -p "$(echo -e "请输入新的${CYAN}主机名${NC} [直接回车跳过]: ")" input_hostname
                    if [[ -n "$input_hostname" && "$input_hostname" != "$current_host" ]]; then
                        if command -v hostnamectl >/dev/null 2>&1; then hostnamectl set-hostname "$input_hostname"; else echo "$input_hostname" > /etc/hostname; hostname "$input_hostname"; fi
                        LOG_SUCCESS "主机名已设置: ${BOLD}$input_hostname${NC}"
                    fi
                    sleep 1.5
                    ;;
                2)
                    SUB_DIVIDER
                    current_time=$(date +"%Y-%m-%d %H:%M:%S %Z")
                    LOG_INFO "当前时区: ${CYAN}${current_time}${NC}"
                    read -r -p "$(echo -e "请输入新${CYAN}时区${NC} [默认: Asia/Shanghai, 回车应用]: ")" input_timezone
                    TIMEZONE_VAL=${input_timezone:-Asia/Shanghai}
                    if command -v timedatectl >/dev/null 2>&1; then timedatectl set-timezone "$TIMEZONE_VAL"; else ln -sf /usr/share/zoneinfo/"$TIMEZONE_VAL" /etc/localtime; fi
                    LOG_SUCCESS "时区已设置: ${BOLD}$TIMEZONE_VAL${NC}"
                    sleep 1.5
                    ;;
                3)
                    SUB_DIVIDER
                    phy_ram=$(free -m | awk '/^Mem:/{print $2}')
                    if [ -z "$phy_ram" ] || ! [[ "$phy_ram" =~ ^[0-9]+$ ]]; then phy_ram=1024; rec_swap=1024
                    elif [ "$phy_ram" -le 2048 ]; then rec_swap=$((phy_ram * 2))
                    elif [ "$phy_ram" -le 8192 ]; then rec_swap=$phy_ram
                    else rec_swap=4096; fi
                    
                    LOG_INFO "探测物理内存: ${CYAN}${phy_ram} MB${NC} | 推荐 Swap: ${GREEN}${rec_swap} MB${NC}"
                    read -r -p "$(echo -e "请输入覆盖的 Swap 大小(MB) [默认: ${GREEN}${rec_swap}${NC}]: ")" input_swap
                    SWAP_VAL=${input_swap:-$rec_swap}
                    
                    if [[ "$SWAP_VAL" -gt 0 ]] && [[ "$SWAP_VAL" =~ ^[0-9]+$ ]]; then
                        LOG_INFO "正在重置挂载 ${SWAP_VAL}MB Swap..."
                        swapoff -a >/dev/null 2>&1
                        rm -f /swapfile
                        sed -i '/swap/d' /etc/fstab
                        dd if=/dev/zero of=/swapfile bs=1M count="$SWAP_VAL" status=none
                        chmod 600 /swapfile
                        mkswap /swapfile >/dev/null 2>&1
                        swapon /swapfile
                        echo "/swapfile none swap sw 0 0" >> /etc/fstab
                        LOG_SUCCESS "Swap (${SWAP_VAL} MB) 部署成功!"
                        sleep 2
                    else
                        LOG_WARN "值非法，跳过。"
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
                        
                        if [ -f /proc/user_beancounters ]; then virt_type="OpenVZ"
                        elif command -v systemd-detect-virt >/dev/null 2>&1; then virt_type=$(systemd-detect-virt)
                        else virt_type="KVM/Unknown"; fi

                        echo -e " 架构类型: ${CYAN}${virt_type}${NC} | 当前内核: ${CYAN}${kernel_full}${NC} | 拥塞算法: ${GREEN}${current_cc:-未配置}${NC}"
                        DIVIDER
                        echo -e "  ${GREEN}1) [默认] 强刷原生BBR并注入极客高并发TCP参数${NC}"
                        echo -e "  ${YELLOW}2) [进阶] 安装第三方魔改内核${NC} (老旧系统适用)"
                        echo -e "  ${RED}9) [清理] 恢复系统网络默认值${NC}"
                        echo -e "  ${NC}0) 返回上一级${NC}"
                        DIVIDER
                        
                        read -r -p "$(echo -e "${BOLD}请输入序号 [1]: ${NC}")" bbr_choice
                        bbr_choice=${bbr_choice:-1}

                        case $bbr_choice in
                            1)
                                SUB_DIVIDER
                                LOG_INFO "默认执行智能网络优化与高并发强刷流程..."
                                
                                if [[ $(echo "$kernel_version >= 4.9" | bc 2>/dev/null || echo 1) -eq 1 ]]; then
                                    sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
                                    sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
                                    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
                                    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
                                fi
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
                                ulimit -n 1000000 2>/dev/null; sysctl -p >/dev/null 2>&1
                                LOG_SUCCESS "高并发参数下发完成！"
                                sleep 1.5
                                ;;
                            2)
                                SUB_DIVIDER
                                LOG_WARN "警告: 更换内核极易导致系统失联！"
                                read -r -p "确认执行？(y/n) [n]: " confirm_kernel
                                if [[ "$confirm_kernel" == "y" || "$confirm_kernel" == "Y" ]]; then
                                    wget -N --no-check-certificate "https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh" -O tcp_net.sh >/dev/null 2>&1
                                    chmod +x tcp_net.sh && bash tcp_net.sh && rm -f tcp_net.sh
                                fi
                                ;;
                            9)
                                SUB_DIVIDER
                                sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
                                sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
                                sed -i '/fs.file-max/d' /etc/sysctl.conf
                                sed -i '/net.ipv4.tcp_/d' /etc/sysctl.conf
                                sed -i '/net.core.somaxconn/d' /etc/sysctl.conf
                                sed -i '/net.ipv4.ip_local_port_range/d' /etc/sysctl.conf
                                echo "net.core.default_qdisc=pfifo_fast" >> /etc/sysctl.conf
                                echo "net.ipv4.tcp_congestion_control=cubic" >> /etc/sysctl.conf
                                sysctl -p >/dev/null 2>&1
                                LOG_SUCCESS "已恢复默认。"
                                sleep 1.5
                                ;;
                            0) break ;;
                            *) LOG_ERROR "有误" ; sleep 1 ;;
                        esac
                    done
                    ;;
                5)
                    SUB_DIVIDER
                    read -r -p "$(echo -e "请输入新的 ${CYAN}Root 密码${NC} (留空跳过): ")" new_root_pwd
                    if [[ -n "$new_root_pwd" ]]; then
                        echo "root:$new_root_pwd" | chpasswd
                        if [[ $? -eq 0 ]]; then LOG_SUCCESS "修改成功！"; else LOG_ERROR "修改失败！"; fi
                    fi
                    sleep 1.5
                    ;;
                0) break ;;
                *) sleep 1 ;;
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
            if [[ -n "$SUBNET_PREFIX" ]]; then mask=$((0xffffffff << (32 - SUBNET_PREFIX))); NETMASK="$(( (mask >> 24) & 0xff )).$(( (mask >> 16) & 0xff )).$(( (mask >> 8) & 0xff )).$(( mask & 0xff ))"; else NETMASK="自动分配"; fi
        else MAIN_IP="自动获取"; GATEWAY="自动获取"; NETMASK="自动获取"; fi

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
            LOG_ERROR "有误。" ; sleep 1.5; continue
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
            LOG_INFO "已取消。"; sleep 1; continue
        fi

        LOG_INFO "开始下载引擎..."
        curl -sSL -O https://raw.githubusercontent.com/zqh2333/reinstall/main/reinstall.sh
        chmod +x reinstall.sh

        if [[ "$os_type_choice" == "1" ]]; then bash reinstall.sh $OS_CMD --password "$PASSWORD_VAL" --ssh-port "$PORT_VAL"
        else bash reinstall.sh $OS_CMD --password "$PASSWORD_VAL"; fi
        
        if [[ $? -eq 0 ]]; then DIVIDER; LOG_SUCCESS "[OK] 引导修改就绪，3 秒后重启..."; sleep 3; reboot
        else LOG_ERROR "执行失败！"; sleep 2; fi

    elif [[ "$main_choice" == "0" ]]; then
        clear
        LOG_SUCCESS "已退出工具，祝您使用愉快！"
        exit 0
    else
        LOG_ERROR "无效选项。"
        sleep 1
    fi
done
