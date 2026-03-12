# 🚀 终极交互式跨平台 DD 重装/环境配置/SSL 三合一工具箱

这不仅仅是一个系统重装脚本，而是专为 VPS 玩家打造的**全自动、零门槛服务器运维终极套件**。

将**极客级的重装能力**、**系统精装**与**SSL 证书管理**完美融合于同一个高颜值交互式菜单中。无论您是要推倒重来，还是要配置新机环境，甚至是一键部署 HTTPS，都能“一路回车”轻松搞定！

---

## ✨ 核心杀手锏 (Features)

### 🖥️ 高颜值三合一控制台 (The All-In-One Menu)
只需执行一次脚本，即可进入美观的终端色彩高亮菜单（支持 Info/Success/Warn/Error 标签）。
- **[选项 1] 🚀 一键 DD 重装**：自动配置复杂网络（支持静态/IPv6/子网漂移），跨平台互刷（19 种 Linux 发行版及 Windows 官方原版 ISO）。
- **[选项 2] 🛠️ 系统精装工具**：自动修改 主机名、系统时区、增量开启 Swap，并一键激活 BBR 拥塞控制算法。
- **[选项 3] 🔒 SSL 证书管家**：自动对接 [zqh2333/SSL-Renewal](https://github.com/zqh2333/SSL-Renewal) 仓库，一键完成域名的 SSL 申请、部署与自动续签任务。

### 🪓 绝对强悍且安全的底层
- **绝对防误删机制**：采用基于**分区表 ID (Partition Table ID)** 的黑科技识别目标硬盘，在多硬盘复杂环境下也能确保不会“格错盘”。
- **闭环私有化控制**：系统的重装引擎内核已独立 Fork 至 [zqh2333/reinstall](https://github.com/zqh2333/reinstall)，SSL 逻辑独立在您个人仓库中，彻底隔绝外部上游不可控更新带来的风险。
- **Windows 脱机部署**：坚决不用存在安全隐患的第三方镜像，底层直接抓取微软原版，并在内存中**全自动脱机注入 VirtIO 驱动**。

---

## 🚀 快速开始 (Quick Start)

请使用 **`root`** 权限登录您的 Linux 服务器。直接在终端中复制粘贴并运行以下一键部署指令：

### 🌍 国际网络直连版 (推荐)
```bash
sh -c 'if ! command -v bash >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then echo "正在准备基础环境..."; if [ -f /etc/alpine-release ]; then apk add --no-cache bash curl; elif [ -f /etc/debian_version ]; then apt-get update -y && apt-get install -y bash curl; elif [ -f /etc/redhat-release ]; then yum install -y bash curl; fi; fi; bash <(curl -sSL https://raw.githubusercontent.com/zqh2333/dd_sys/main/dd_install.sh)'

