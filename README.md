# Codex 鲸鱼娘 · 大肥鱼

可独立运行的 Codex Custom Pet「鲸鱼娘 · 大肥鱼」，通过读取 Codex hooks、
线程历史和桌面进程状态，切换贴图来反映 Codex 的运行状态。

这是一个非官方社区项目，不修改 Codex 安装目录，也不代表 Codex、OpenAI、
DeepSeek 或素材上游项目。

## 2.0.0 下载

在 [v2.0.0 Release](https://github.com/aomeone/Independent-blue-fat-fish-desktop-pet-for-codex/releases/tag/v2.0.0)
中下载对应平台的发布包：

- **Windows**：`CodexDaFeiYuSetup.exe`，支持选择安装 Custom Pet、独立桌宠，或两者同时安装；
- **macOS**：`codex-dafeiyu-pet-v2.0.0-macos.zip`，解压后运行 `install.command`；
- `checksums.sha256` 位于各平台展开目录中，用于校验包内文件。

发布版本号：`2.0.0`  
发布日期：2026-10-02

## 源码结构

- `codex-dafeiyu-pet-v2.0.0-windows/`：Windows Custom Pet、独立桌宠运行时和安装入口；
- `codex-dafeiyu-pet-v2.0.0-macos/`：macOS Custom Pet、应用包和安装入口；
- `installer/`：Windows 启动器与一键安装器的 C# 源码；
- `build-windows-installer.ps1`：在 Windows 上重新编译并打包安装器。

Windows 构建脚本依赖系统 .NET Framework `csc.exe`。独立桌宠运行时需要
Python 3 和 PySide6；安装器会在用户确认后尝试准备缺少的依赖。

## 安装后

在 Codex 中打开 **Settings > Pets**，点击 **Refresh**，选择
**鲸鱼娘 · 大肥鱼**。首次安装或更新用户级 hooks 后，需要完全重启 Codex Desktop，
并在 `/hooks` 中审核和信任新出现的 hooks。

完整的平台安装、卸载、依赖和状态映射说明见各发布目录中的 `README.md`、
`STATE_MAPPING.md` 与 `ASSET_LICENSE.md`。

## 许可证

安装器、清单和打包文件使用 MIT License。精灵素材的来源与上游授权见
`codex-dafeiyu-pet-v2.0.0-macos/ASSET_LICENSE.md` 和
`dsh-pet-LICENSE.txt`。
