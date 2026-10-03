# Codex v2 状态映射

这个 Pet 使用 Codex `spriteVersionNumber: 2` 的固定精灵图协议。Codex
会按固定槽位选择动作，`pet.json` 不能新增 `THINKING` 或 `SUCCESS` 之类的新槽位。
当前 Codex Mini 的状态选择器只把活动线程暴露为 `running`，所以 `running`
槽位使用工作动作；`review` 槽位保留带问号的思考动画，供未来支持该状态的
渲染器使用。独立桌宠版仍使用完整状态总线。

| Codex 工作状态 | 固定槽位 | 鲸鱼娘动作 | 含义 |
| --- | --- | --- | --- |
| 空闲 | `idle` | 呼吸待机 | 没有活动任务 |
| 思考/审阅（未来槽位） | `review` | 问号与思考动作 | 供支持该槽位的渲染器使用 |
| 正在工作/活动中 | `running` | 工作动作 | 当前 Codex Mini 可观察到的活动状态 |
| 模型思考 | 独立桌宠版 | 思考动作 | reasoning 阶段归入 `THINKING` |
| 整理工具结果 | 独立桌宠版 | `working_command` 贴图 | 状态仍为 `THINKING`，但用命令动作表示正在消化工具结果 |
| 正在执行工具 | 独立桌宠版 | 工作动作 | 仅当检测到 Codex 派生的活动 PowerShell 子进程时为 `WORKING` |
| 等待下一步 | 独立桌宠版 | `waiting` 贴图 | 没有活动 PowerShell 子进程时为 `WAITING` |
| 等待确认 | `waiting` | 等待动作 | 等待权限、确认或用户输入 |
| 出错 | `failed` | 红色 X 错误动作 | 工具或任务失败 |

`running-right`、`running-left`、`waving` 和 `jumping` 是 Codex 的移动或交互
动作槽位，不代表独立的工作生命周期状态。Codex v2 没有独立的 `success`
槽位，任务完成时会回到 `idle`。
