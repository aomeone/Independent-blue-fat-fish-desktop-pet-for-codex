# Codex 鲸鱼娘 · 大肥鱼

可独立运行的 Codex Custom Pet「鲸鱼娘 · 大肥鱼」，通过读取 Codex hooks、
线程历史和桌面进程状态，切换贴图来反映 Codex 的运行状态。

这是一个非官方社区项目，不修改 Codex 安装目录，也不代表 Codex、OpenAI、
DeepSeek 或素材上游项目。当前发布 Windows 和 macOS 版本；独立桌宠需要
Node.js、Python 3 和 PySide6，并可与 Codex 内置宠物并行使用。

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

### 运行独立桌宠

安装器中勾选“独立桌宠”后，Mini 宠物和独立窗口可以同时使用。独立版会读取
Codex hooks 状态，并在 Codex 工作、思考、整理、等待或空闲时自动切换贴图。

- **Windows**：从桌面或开始菜单打开 `start-pet.exe`。如果需要查看启动错误，
  可运行 `start-pet.cmd`。首次启动若缺少依赖，在独立桌宠目录中执行
  `py -3 -m pip install -r standalone\requirements.txt`。
- **macOS**：保持发布包完整解压，不要只移动 `.app`；双击 `start-pet.command`
  或 `Codex大肥鱼.app`，也可以在 Terminal 中运行
  `./macos/start-pet-macos.sh`。首次打开时 App 会引导配置 Node.js、Python 3.10+
  和 PySide6。
- 独立桌宠不要求先打开 Codex 才能启动；Codex 未运行时会显示待机。窗口位置会被
  保存在用户目录中，不会被状态同步覆盖。完整路径、卸载方式和故障排查见对应平台
  目录的 `README.md`。

完整的平台安装、卸载、依赖和状态映射说明见各发布目录中的 `README.md`、
`STATE_MAPPING.md` 与 `ASSET_LICENSE.md`。

## 许可证

安装器、清单和打包文件使用 MIT License。精灵素材的来源与上游授权见
`codex-dafeiyu-pet-v2.0.0-macos/ASSET_LICENSE.md` 和
`dsh-pet-LICENSE.txt`。
