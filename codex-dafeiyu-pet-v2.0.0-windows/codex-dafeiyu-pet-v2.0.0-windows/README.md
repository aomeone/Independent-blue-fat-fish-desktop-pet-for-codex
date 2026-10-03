# Codex 鲸鱼娘 · 大肥鱼

这是一个可程序安装的 Codex Custom Pet 发布包，也附带可单独运行的桌面鲸鱼娘。
安装后，宠物会出现在 Codex 的 `Settings > Pets > Custom pets` 中，可以像内置宠物一样被 Mini 使用。

## 安装

双击发布包里的 `CodexDaFeiYuSetup.exe`，在组件选择页勾选 Mini、独立桌宠，或两者都装。勾选独立桌宠时，
安装器会先检测 Python 3、PySide6 和 Node.js；缺少的依赖会尝试通过 Windows `winget` 和 Python
`pip` 自动安装，因此这一步需要网络连接。安装器会：

- 校验 `pet.json` 与精灵图的 SHA-256；
- 安装 Mini 到 `%USERPROFILE%\.codex\pets\dafeiyu-whale-maid`；
- 将独立桌宠安装到 `%LOCALAPPDATA%\Codex\codex-dafeiyu-standalone`，并创建桌面和开始菜单快捷方式；
- 更新已有版本前，把旧版本备份到 `%USERPROFILE%\.codex\pets\.backups\dafeiyu-whale-maid`；
- 选择独立桌宠时，自动把状态桥接合并到 `%USERPROFILE%\.codex\hooks.json`，使用安装目录内自包含的 hook；
- 不需要管理员权限，也不需要 Python 或网络。

安装完成后，在 Codex 的 **Settings > Pets** 中点击 **Refresh**，选择 **鲸鱼娘 · 大肥鱼**。如果列表没有立即更新，重启 Codex 后再刷新。
完全重启 Codex Desktop 后，在 `/hooks` 中审核并信任新出现的用户级 hooks；未审核的 hooks 不会运行。
如果之后需要重新注册或修复用户级 hooks，可单独运行 `install-user-hooks.ps1`。
没有安装器时，也可以双击 `install.cmd` 走兼容的 Mini 脚本安装流程。

## 单独启动桌宠

启动入口会优先使用 PowerShell 7（`pwsh.exe`），没有时自动回退到系统 Windows PowerShell。
安装独立桌宠后，双击 `start-pet.exe` 即可启动，不会显示 CMD 窗口；
也可以双击 `start-pet.vbs`，它是兼容旧版本的无窗口启动入口；
也可以双击 `start-pet.cmd`，它会保留可见控制台，便于排查启动错误。三种方式都不需要先打开
Codex，也不会修改 Codex 的安装目录。首次启动需要本机已安装 Python 3 和 PySide6；
如果缺少依赖，在 PowerShell 中执行：

```powershell
py -3 -m pip install -r standalone\requirements.txt
```

注意：安装器可以只安装 Mini、只安装独立桌宠，或两个都安装。`install.cmd` 仍然只负责安装
Custom Pet，不会弹出独立窗口；日常使用建议运行 `start-pet.exe`，遇到问题时再运行
`start-pet.cmd` 查看错误信息。

也可以在 PowerShell 中安装到指定的 Codex 配置目录：

```powershell
.\install.ps1 -CodexHome "C:\Users\你的用户名\.codex"
```

## 卸载

双击 `uninstall.cmd`。当前安装会被移动到备份目录，不会直接删除。若要卸载后恢复安装前的版本：

```powershell
.\uninstall.ps1 -RestoreBackup
```

## 包内容

- `pet.json`：Codex v2 宠物 manifest；
- `spritesheet.webp`：`1536x2288`、RGBA、8x11 atlas；
- `CodexDaFeiYuSetup.exe`：一键安装器，可选择 Mini、独立桌宠或两者；
- `install.cmd` / `install.ps1`：安装入口；
- `install-user-hooks.ps1`：把真实 Codex 生命周期事件接到独立桌宠的状态 daemon；
- `uninstall.cmd` / `uninstall.ps1`：卸载入口；
- `start-pet.exe`：无 CMD 窗口的独立桌宠启动 EXE；
- `start-pet.vbs`：兼容旧版本的无 CMD 窗口启动入口；
- `start-pet.cmd` / `start-pet.ps1`：可见控制台的独立桌宠启动与排错入口；
- `standalone\`：独立桌宠 helper、动画资源和 Python 依赖说明；
- `checksums.sha256`：发布文件校验；`state-mapping.json` / `STATE_MAPPING.md`：Codex v2 状态映射；
- `ASSET_LICENSE.md`、`dsh-pet-LICENSE.txt`：素材来源与授权说明。

v2.0.0 在 v1.3.2 基础上整理为稳定发布版，独立桌宠跟随 Codex hooks 状态。启动桌宠后，
它会读取 `%LOCALAPPDATA%\Codex\codex-dafeiyu\status.json`；Codex 未运行或
daemon 停止时显示待机。独立版大小和位置仍保存在
`%LOCALAPPDATA%\Codex\codex-dafeiyu-standalone\layout.json`，不会被状态同步覆盖。
如果 Codex Desktop 没有执行状态 hooks，独立窗口还会只读轮询
`%USERPROFILE%\.codex\thread_history_1.sqlite`，自动识别最近活动回合的思考和工具执行状态。
在 Windows 上，它还会观察 Codex 启动的活动 PowerShell 子进程。只要发现这类进程，
就立即切换到 `WORKING`，即使 SQLite 尚未出现、正在被锁定、结构发生变化，或暂时
没有明确的工具记录；这条进程观察是兜底判据。这些观察都是只读的，不修改 Codex
数据库；Codex 内部数据库结构可能随版本变化。可设置
`CODEX_DAFEIYU_AUTO_DISCOVER=0` 关闭数据库观察，或设置
`CODEX_DAFEIYU_PROCESS_OBSERVER=0` 关闭 Windows 进程观察。

当前内置 Mini 的状态动作：
活动线程的 `running` 槽位显示工作动作；
`review` 槽位保留带问号的思考动画，供未来会暴露该状态的渲染器使用。独立桌宠
会把模型思考和工具结果整理显示为 `THINKING`，其中整理阶段使用 `working_command` 贴图。
独立版的 `WORKING` 判据只有 Windows 上是否存在由 Codex 进程派生的活动 PowerShell
子进程；数据库中的工具记录不会单独触发 `WORKING`。没有该子进程时，数据库只用于
区分思考、整理和等待下一步，其中等待下一步使用 `WAITING` 状态和 `waiting` 贴图。
Codex v2 没有独立的 `success` 槽位，任务完成后会
回到 `idle`。完整说明见 `STATE_MAPPING.md`。

这是非官方的社区自定义宠物，不修改 Codex 安装目录，也不会注册为官方内置 Mini。

