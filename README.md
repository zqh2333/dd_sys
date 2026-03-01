# 🚀 全自动多系统 DD 重装脚本 (Interactive OS Reinstall)

专为 VPS/云服务器 设计的**全自动、交互式**纯净系统重装（DD）脚本。基于业界最稳健的开源底层引擎开发，提供极其简单、安全且高度可定制的系统重装体验。无需记忆繁杂的命令行参数，跟着提示按回车即可完成服务器重装。

---

## ✨ 核心特性

- **🛠 交互式配置**：全程友好的引导式提问，告别冗长复杂的安装命令。
- **⚡ 极速默认值**：支持全程按 **回车键** 使用预设默认值，一键无脑重装。
- **🌐 智能网络识别**：自动探测并提取当前机器的公网 IP、网关和子网掩码，最大程度避免重装后失联。
- **🚀 BBR 网络加速**：内置可选开关，系统重装完成时可一键自动开启 BBR 加速。
- **💿 多系统支持**：支持平滑重装为 Debian、Ubuntu、AlmaLinux、RockyLinux 等主流 Linux 系统。
- **🧠 智能 Swap 规划**：底层机制会根据物理内存自动规划并创建合理的 Swap 分区大小。

---

## 💻 支持重装的操作系统

- **Debian**: 11, 12 (默认推荐，占用极低，极其稳定)
- **Ubuntu**: 20.04, 22.04
- **AlmaLinux**: 9
- **RockyLinux**: 9

---

## 🚀 快速开始 (一键运行)

请确保您当前使用的是 **`root`** 用户登录服务器。请在终端中直接复制并运行以下命令之一：

### 🌍 国际网络通用版 (推荐)
```bash
bash <(curl -sSL [https://raw.githubusercontent.com/zqh2333/dd_sys/main/dd_install.sh](https://raw.githubusercontent.com/zqh2333/dd_sys/main/dd_install.sh))
