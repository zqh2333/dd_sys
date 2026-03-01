# 🚀 全自动多系统 DD 重装脚本

这是一个为 VPS/云服务器 设计的**全自动、交互式**纯净系统重装（DD）脚本。基于业界最稳健的开源底层引擎（Leitbogioro Tools）开发，旨在提供极其简单、安全且高度可定制的系统重装体验。

## ✨ 核心特性

* **🛠 交互式配置**：全程友好的引导式配置，告别记不住复杂参数的烦恼。
* **⚡ 极速默认值**：支持全程按 **回车键** 使用预设默认值，一键无脑重装。
* **🌐 智能网络识别**：自动探测并提取当前机器的公网 IP、网关和子网掩码，最大程度避免重装后失联。
* **🚀 BBR 网络加速**：内置可选开关，系统重装完成时可自动开启 BBR。
* **💿 多系统支持**：支持一键重装为 Debian、Ubuntu、AlmaLinux、RockyLinux 等主流系统。
* **🧠 智能 Swap 规划**：底层机制会根据物理内存自动规划并创建合理的 Swap 分区大小。

---

## 💻 支持重装的操作系统

* **Debian**: 11, 12 (默认推荐)
* **Ubuntu**: 20.04, 22.04
* **AlmaLinux**: 9
* **RockyLinux**: 9

---

## 快速开始 (Quick Start)

请确保您当前使用的是 **root** 用户登录服务器。在终端中直接复制并运行以下命令：

```bash
bash <(curl -sSL [https://raw.githubusercontent.com/zqh2333/dd_sys/main/dd_install.sh](https://raw.githubusercontent.com/zqh2333/dd_sys/main/dd_reinstall.sh))
