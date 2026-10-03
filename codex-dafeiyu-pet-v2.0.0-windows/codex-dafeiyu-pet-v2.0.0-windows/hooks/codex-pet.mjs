import { existsSync } from 'node:fs'
import { mkdir, readFile } from 'node:fs/promises'
import { basename, dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { homedir, tmpdir } from 'node:os'
import { spawn } from 'node:child_process'
import net from 'node:net'

const here = dirname(fileURLToPath(import.meta.url))
const packageRoot = resolve(here, '..')

function runtimeRoot(root) {
  const standaloneRuntime = join(root, 'standalone', 'runtime')
  return existsSync(join(standaloneRuntime, 'codex-daemon.mjs'))
    ? join(root, 'standalone')
    : root
}

const defaultRoot = runtimeRoot(packageRoot)

const SUCCESS_EVENTS = new Set(['Stop', 'SubagentStop'])
const JSON_OUTPUT_EVENTS = new Set(['Stop', 'SubagentStop', 'Interrupt'])

function dataDirectory() {
  if (process.env.PLUGIN_DATA) return resolve(process.env.PLUGIN_DATA)
  if (process.env.CODEX_DAFEIYU_DATA) return resolve(process.env.CODEX_DAFEIYU_DATA)
  if (process.platform === 'win32' && process.env.LOCALAPPDATA) {
    return join(process.env.LOCALAPPDATA, 'Codex', 'codex-dafeiyu')
  }
  return join(process.env.XDG_STATE_HOME || join(homedir(), '.local', 'state'), 'codex-dafeiyu')
}

function text(value, limit = 160) {
  const valueText = String(value ?? '').replace(/\s+/gu, ' ').trim()
  return valueText.length > limit ? `${valueText.slice(0, limit - 1)}…` : valueText
}

export function summarize(value, limit = 120) {
  return text(value, limit)
}

export function classifyTool(toolName, toolInput = {}) {
  const name = String(toolName ?? '').toLowerCase()
  const command = typeof toolInput?.command === 'string' ? toolInput.command.toLowerCase() : ''
  const value = `${name} ${command}`
  if (/search|grep|find|glob|web|read|fetch|open|inspect/.test(value)) return 'searching'
  if (/write|edit|patch|replace|create|move|delete|apply_patch/.test(value)) return 'editing'
  if (/test|check|lint|build|verify|compile/.test(value)) return 'testing'
  if (/shell|bash|exec|command|terminal|powershell/.test(value)) return 'commanding'
  return 'using-tool'
}

export function activityStage(activity) {
  return {
    searching: '查找阶段',
    editing: '实现阶段',
    testing: '验证阶段',
    commanding: '执行阶段',
  }[activity] || '处理阶段'
}

export function activityMessage(activity) {
  return {
    searching: '正在项目里仔细找找哦',
    editing: '正在把改动写进去呢',
    testing: '正在跑测试确认一下哦',
    commanding: '正在执行项目命令呢',
    'using-tool': '正在继续处理任务呢',
  }[activity] || '正在继续处理任务呢'
}

export function hasToolError(response) {
  if (response == null) return false
  if (typeof response === 'string') {
    return /\b(error|failed|failure|exception|traceback|exit code [1-9])\b/i.test(response)
  }
  if (Array.isArray(response)) return response.some(hasToolError)
  if (typeof response === 'object') {
    if (response.error || response.errors || response.failed === true) return true
    if (Number.isInteger(response.exit_code) && response.exit_code !== 0) return true
    if (Number.isInteger(response.exitCode) && response.exitCode !== 0) return true
  }
  return false
}

function projectName(cwd) {
  const value = text(cwd, 80)
  return value ? basename(value.replace(/[\\/]+$/u, '')) : '当前项目'
}

function eventBase(input) {
  const eventName = String(input?.hook_event_name || '')
  const sessionId = String(input?.session_id || 'default-session')
  const toolName = String(input?.tool_name || '')
  const project = projectName(input?.cwd)
  return {
    protocolVersion: 1,
    kind: 'hook-event',
    hookEventName: eventName,
    sessionId,
    turnId: input?.turn_id ? String(input.turn_id) : undefined,
    agentId: input?.agent_id ? String(input.agent_id) : undefined,
    project,
    cwd: text(input?.cwd, 260),
    toolName,
  }
}

export function buildCompanionEvent(input) {
  const base = eventBase(input)
  const eventName = base.hookEventName
  const toolInput = input?.tool_input && typeof input.tool_input === 'object'
    ? input.tool_input
    : {}
  if (eventName === 'SessionStart') {
    return {
      ...base,
      action: 'session-start',
      state: 'IDLE',
      phase: 'session-start',
      stage: '等待任务',
      message: '鲸鱼娘上线啦，等你派任务哦',
    }
  }
  if (eventName === 'UserPromptSubmit') {
    const task = summarize(input?.prompt || '')
    return {
      ...base,
      action: 'state',
      state: 'THINKING',
      phase: 'prompt',
      stage: '分析阶段',
      clip: 'thinking',
      task,
      message: task ? `正在处理「${task}」呢` : '正在认真想下一步呢',
    }
  }
  if (eventName === 'PreToolUse') {
    const activity = classifyTool(base.toolName, toolInput)
    return {
      ...base,
      action: 'state',
      state: 'WORKING',
      phase: 'tool-call',
      activity,
      stage: activityStage(activity),
      task: text(toolInput?.description || toolInput?.command || base.toolName, 120),
      message: activityMessage(activity),
    }
  }
  if (eventName === 'PostToolUse') {
    const failed = hasToolError(input?.tool_response)
    const activity = classifyTool(base.toolName, toolInput)
    if (failed) {
      return {
        ...base,
        action: 'pulse',
        state: 'ERROR',
        resumeState: 'THINKING',
        resumeActivity: undefined,
        ttlMs: 1800,
        phase: 'tool-error',
        stage: '遇到问题',
        message: '刚才的操作遇到一点问题哦',
        detail: text(input?.tool_response, 180),
      }
    }
    return {
      ...base,
      action: 'state',
      state: 'THINKING',
      phase: 'tool-result',
      stage: '整理阶段',
      clip: 'working_command',
      message: '正在整理刚才的结果呢',
      activity,
    }
  }
  if (eventName === 'PermissionRequest') {
    return {
      ...base,
      action: 'state',
      state: 'WAITING',
      phase: 'permission',
      stage: '等待确认',
      task: text(toolInput?.description || base.toolName, 120),
      message: '这里要等你确认一下哦',
    }
  }
  if (eventName === 'Stop') {
    return {
      ...base,
      action: 'pulse',
      state: 'SUCCESS',
      resumeState: 'IDLE',
      ttlMs: 2600,
      phase: 'turn-end',
      stage: '完成啦',
      message: '这次的任务搞定啦~',
      detail: text(input?.last_assistant_message, 180),
    }
  }
  if (eventName === 'Interrupt') {
    return {
      ...base,
      action: 'pulse',
      state: 'ERROR',
      resumeState: 'IDLE',
      ttlMs: 1600,
      phase: 'interrupt',
      stage: '先停在这里',
      message: '这次任务先停在这里哦',
    }
  }
  if (eventName === 'SessionEnd') {
    return {
      ...base,
      action: 'session-end',
      state: 'IDLE',
      phase: 'session-end',
      stage: '会话结束',
      message: '这次先休息一下啦',
    }
  }
  if (eventName === 'SubagentStart') {
    return {
      ...base,
      sessionId: base.agentId || base.sessionId,
      action: 'state',
      state: 'WORKING',
      phase: 'subagent-start',
      stage: '协作阶段',
      message: '正在和小伙伴一起处理呢',
    }
  }
  if (eventName === 'SubagentStop') {
    return {
      ...base,
      sessionId: base.agentId || base.sessionId,
      action: 'pulse',
      state: 'SUCCESS',
      resumeState: 'THINKING',
      ttlMs: 1500,
      phase: 'subagent-end',
      stage: '协作完成',
      message: '小伙伴这一步处理好了哦',
    }
  }
  return {
    ...base,
    action: 'state',
    state: 'THINKING',
    phase: 'unknown',
    stage: '思考阶段',
    clip: 'thinking',
    message: '正在继续处理任务呢',
  }
}

async function readStdin() {
  const chunks = []
  for await (const chunk of process.stdin) chunks.push(chunk)
  return Buffer.concat(chunks).toString('utf8')
}

async function readDaemonState(filePath) {
  try {
    const value = JSON.parse(await readFile(filePath, 'utf8'))
    if (!Number.isInteger(value.port) || value.port <= 0) return null
    return value
  } catch {
    return null
  }
}

function sendToPort(port, payload) {
  return new Promise((resolve, reject) => {
    const socket = net.createConnection({ host: '127.0.0.1', port })
    let settled = false
    const finish = (error) => {
      if (settled) return
      settled = true
      socket.destroy()
      if (error) reject(error)
      else resolve()
    }
    socket.setTimeout(900, () => finish(new Error('daemon connection timed out')))
    socket.once('error', finish)
    socket.once('connect', () => {
      socket.end(`${JSON.stringify(payload)}\n`, () => finish())
    })
  })
}

function startDaemon(root, data) {
  const daemon = join(root, 'runtime', 'codex-daemon.mjs')
  const child = spawn(process.execPath, [daemon], {
    cwd: root,
    detached: true,
    stdio: 'ignore',
    windowsHide: true,
    env: {
      ...process.env,
      CODEX_DAFEIYU_ROOT: root,
      CODEX_DAFEIYU_DATA: data,
    },
  })
  child.unref()
}

async function deliver(payload) {
  const data = dataDirectory()
  await mkdir(data, { recursive: true })
  const stateFile = join(data, 'daemon.json')
  const root = runtimeRoot(process.env.PLUGIN_ROOT ? resolve(process.env.PLUGIN_ROOT) : defaultRoot)
  const daemon = join(root, 'runtime', 'codex-daemon.mjs')
  for (let attempt = 0; attempt < 12; attempt += 1) {
    const state = await readDaemonState(stateFile)
    if (state) {
      try {
        await sendToPort(state.port, payload)
        return
      } catch {
        // The state file may point at a daemon that is shutting down.
      }
    }
    if (attempt === 0 && !existsSync(daemon)) return
    if (attempt === 0) startDaemon(root, data)
    await new Promise((resolve) => setTimeout(resolve, 100))
  }
}

export async function main() {
  let input
  try {
    input = JSON.parse(await readStdin())
  } catch {
    return
  }
  const event = buildCompanionEvent(input)
  try {
    await deliver(event)
  } catch (error) {
    process.stderr.write(`codex-dafeiyu hook: ${error instanceof Error ? error.message : String(error)}\n`)
  }
  if (JSON_OUTPUT_EVENTS.has(event.hookEventName)) process.stdout.write('{}\n')
}

if (process.argv[1] && resolve(process.argv[1]) === resolve(fileURLToPath(import.meta.url))) {
  await main()
}
