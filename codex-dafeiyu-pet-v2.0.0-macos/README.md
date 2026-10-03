# Codex 鲸鱼娘 · 大肥鱼（macOS）

这是 Codex Custom Pet「鲸鱼娘 · 大肥鱼」的 macOS 发布包，同时附带可独立运行的桌面宠物。

请先完整解压发布包，并保留解压后的整个文件夹。`Codex大肥鱼.app` 会通过相对路径调用同目录中的 `macos/` 脚本，不能单独把 `.app` 拖出来运行。

## 安装

在 Finder 中双击 `install.command`，或在 Terminal 中运行：

```bash
./install.sh
```

安装器会校验发布包内文件的 SHA-256，将宠物安装到 `~/.codex/pets/dafeiyu-whale-maid`，
备份旧版本，并把用户级 Codex hooks 合并到 `~/.codex/hooks.json`。

也可以指定 Codex 配置目录：

```bash
./install.sh --codex-home "$HOME/.codex"
```

安装完成后，在 Codex 的 **Settings > Pets** 中点击 **Refresh**，选择
**鲸鱼娘 · 大肥鱼**。完全重启 Codex Desktop 后，在 `/hooks` 中审核并信任新出现的用户级
hooks；未审核的 hooks 不会运行。

## 单独启动桌宠

推荐在 Terminal 中启动：

```bash
./macos/start-pet-macos.sh
```

也可以双击 `start-pet.command`，或直接打开 `Codex大肥鱼.app`。
`Codex大肥鱼.app` 是一键入口：它会先安装/更新 Mini 宠物和 hooks，然后启动独立桌宠。
每次启动都会检测运行依赖；首次发现 Node.js、Python 3.10+ 或 PySide6 缺失时，会先询问是否安装。
Node.js/Python 缺失时会使用 Homebrew；PySide6 安装在 Codex 专用 Python 虚拟环境中。
没有 Homebrew 时，App 会打开 Terminal 启动官方安装流程，可能要求完成 macOS 系统认证。
依赖下载和安装需要网络连接，首次配置可能需要几分钟；之后会复用已安装的环境。
专用虚拟环境保存在 `~/Library/Application Support/Codex/codex-dafeiyu-runtime/venv`。

### 首次打开被 macOS 拦截

此社区版未使用 Apple Developer ID 签名或公证。若 macOS 提示无法验证开发者或无法检查是否包含恶意软件，并且你确认下载包来源可信，可在 Finder 中按住 Control 点按 `Codex大肥鱼.app`，选择“打开”，再确认打开。若系统没有提供此选项，先尝试打开一次，再到“系统设置 > 隐私与安全性”查看是否出现针对该 App 的“仍要打开”选项。不要为此全局关闭 Gatekeeper。

窗口位置和大小保存在 `~/Library/Application Support/Codex/codex-dafeiyu-standalone/layout.json`；
hooks 状态保存在 `~/Library/Application Support/Codex/codex-dafeiyu/status.json`。
如果没有执行状态 hooks，独立窗口仍会只读轮询 `~/.codex/thread_history_1.sqlite`。
若直接运行 `macos/start-pet-macos.sh`，请先使用 App 完成依赖配置，或自行准备 Python 和 PySide6。

## 卸载

```bash
./uninstall.sh
./uninstall.sh --restore-backup
```

卸载会把当前版本移动到备份目录，不会直接删除。

## 包内容

- `pet.json`、`spritesheet.webp`：Codex v2 宠物资源；
- `install.sh` / `uninstall.sh`：安装与卸载入口；
- `install.command` / `uninstall.command`：Finder 双击入口；
- `start-pet.command`：Finder 启动入口；
- `Codex大肥鱼.app`：可双击打开的 macOS 应用包；
- `macos/`：macOS 启动器与 hooks 注册脚本；
- `standalone/`：独立桌宠 helper、动画资源和 Python 依赖说明；
- `checksums.sha256`：发布文件校验；
- `state-mapping.json` / `STATE_MAPPING.md`：Codex v2 状态映射。

这是非官方的社区自定义宠物，不修改 Codex 安装目录，也不会注册为官方内置 Mini。
