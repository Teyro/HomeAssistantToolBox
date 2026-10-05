# Home Assistant ToolBox

**一键掌控你的智能家居：在 KDE Plasma 面板、macOS 菜单栏和 iPhone 上。**

[English](../README.md) · [Deutsch](../README.de.md) · **中文** · [हिन्दी](README.hi.md) · [Español](README.es.md) · [العربية](README.ar.md) · [Français](README.fr.md) · [বাংলা](README.bn.md)

来自 [Home Assistant](https://www.home-assistant.io/) 的灯、插座、暖气、能源和人员信息——作为原生
**KDE Plasma 6 小部件**、**macOS 菜单栏应用**（macOS 26 上采用 Liquid Glass 设计）以及通过
[Scriptable](https://scriptable.app) 实现的 **iPhone/iPad 小组件**。三者共享相同的逻辑和功能。

![KDE](../plasma/bilder/en/tiles-dark.png)

## 功能

- **灯**：灯组和房间（Home Assistant 区域），每盏灯都有开关和亮度调节，“全部关闭”
- **插座**：插线板和开关组合并为一行，带共用开关和总耗电
- **能源**：当前用电、24 小时历史、**今日用量**（电、水、燃气）、最大耗电设备
- **暖气**：每个房间的温度和湿度、目标温度、模式、预设、**额外加热**、窗户开/关状态和 **24 小时图表**
- **人员**：带区域的地图，谁在哪里、离家多远
- **多个 Home Assistant 实例**、**桌面小部件**、**实时更新**（WebSocket）
- **8 种语言**，根据系统语言自动选择

## 下载与安装

所有文件见 [Releases](https://github.com/Teyro/HomeAssistantToolBox/releases/latest)：

- **KDE Plasma 6**：`homeassistant-toolbox.plasmoid` → `kpackagetool6 -t Plasma/Applet -i homeassistant-toolbox.plasmoid`，
  然后右键面板 → 添加部件 → “Home Assistant ToolBox”（[说明](../plasma/README.md)）
- **macOS 14+**：解压 `HomeAssistantToolBox-macOS-x.y.z.zip`，拖到“应用程序”，然后运行一次
  `xattr -dr com.apple.quarantine "/Applications/Home Assistant ToolBox.app"`（[说明](../macos/README.md)）
- **iPhone/iPad**：将 `HomeAssistantToolBox.js` 存入 Scriptable 文件夹（[说明](../ios/README.md)）

你需要 Home Assistant 的地址和一个**长期访问令牌**
（Home Assistant → 个人资料 → *安全* → *长期访问令牌* → *创建令牌*）。

## 隐私

应用只与**你自己的 Home Assistant** 通信——没有云服务，没有跟踪。此外仅连接 GitHub（检查更新）和 OpenStreetMap 地图。
在 macOS 和 iOS 上，令牌保存在钥匙串中。

## 翻译

翻译借助机器完成，欢迎在 `i18n/zh.json` 中提交改进！

## 许可证与商标

GPL-3.0-or-later。Home Assistant ToolBox 是独立项目，与 Home Assistant、Nabu Casa 或 Open Home Foundation **没有任何关联**。
“Home Assistant” 是其所有者的商标。
