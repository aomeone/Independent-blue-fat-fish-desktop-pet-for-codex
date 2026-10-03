import { createServer } from 'node:net'
import { existsSync } from 'node:fs'
import { mkdir, open, readFile, rename, rm, stat, writeFile } from 'node:fs/promises'
import { dirname, extname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { spawn } from 'node:child_process'
import process from 'node:process'

export const PROTOCOL_VERSION = 1

const STATES = new Set(['IDLE', 'THINKING', 'WORKING', 'WAITING', 'SUCCESS', 'ERROR', 'DISCONNECTED'])
const PRIORITY = Object.freeze({
  WAITING: 60,
  ERROR: 50,
  WORKING: 30,
  THINKING: 20,
  IDLE: 0,
  DISCONNECTED: -1,
})

const here = dirname(fileURLToPath(import.meta.url))
const defaultRoot = resolve(here, '..')

export function priorityFor(state) {
  return PRIORITY[state] ?? 0
}

export function activityStage(activity) {
  return {
    searching: '查找阶段',
    editing: '实现阶段',
    testing: '验证阶段',
    commanding: '执行阶段',
  }[activity] || '处理阶段'
}

function inferClip(state, stage, clip) {
  const stageText = String(stage || '')
  if (state === 'WORKING') {
    if (clip === 'waiting' || stageText.includes('等待')) return 'waiting'
    if (clip === 'working' || clip === 'working_search') return clip
    return undefined
  }
  if (typeof clip === 'string' && clip) return clip
  if (state === 'WAITING' || stageText.includes('等待')) return 'waiting'
  if (state === 'THINKING' && stageText.includes('整理')) return 'working_command'
  if (state === 'THINKING') return 'thinking'
  return undefined
}

function message(kind, payload = {}) {
  return {
    protocolVersion: PROTOCOL_VERSION,
    kind,
    timestamp: Date.now(),
    ...payload,
  }
}

function layoutPath(data) {
  return join(data, 'layout.json')
}

function miniMode() {
  return process.env.CODEX_DAFEIYU_MINI !== '0'
}

function helperLaunch(root) {
  const explicit = process.env.CODEX_DAFEIYU_HELPER
  if (explicit && existsSync(explicit)) {
    return {
      command: explicit,
      args: process.env.CODEX_DAFEIYU_HEADLESS === '1' ? ['--headless'] : [],
    }
  }
  const bundled = process.platform === 'win32'
    ? join(root, 'runtime', 'bin', 'win32-x64', 'codex-dafeiyu-helper.exe')
    : process.platform === 'linux'
      ? join(root, 'runtime', 'bin', 'linux-x64', 'codex-dafeiyu-helper')
      : join(root, 'runtime', 'bin', 'darwin', 'codex-dafeiyu-helper.app', 'Contents', 'MacOS', 'codex-dafeiyu-helper')
  if (existsSync(bundled)) return { command: bundled, args: [] }
  const helper = join(root, 'runtime', 'helper.py')
  const python = process.env.CODEX_DAFEIYU_PYTHON || (process.platform === 'win32' ? 'py' : 'python3')
  if (process.platform === 'win32' && /(^|[\\/])py(?:\.exe)?$/i.test(python)) {
    return {
      command: python,
      args: ['-3', helper, ...(process.env.CODEX_DAFEIYU_HEADLESS === '1' ? ['--headless'] : [])],
    }
  }
  return {
    command: python,
    args: [helper, ...(process.env.CODEX_DAFEIYU_HEADLESS === '1' ? ['--headless'] : [])],
  }
}

function sessionDetail(record) {
  return [record.project, record.task, record.stage].filter(Boolean).join(' · ') || 'Codex · 等待下一次任务'
}

export class PetDaemon {
  constructor({ root = defaultRoot, data = process.env.CODEX_DAFEIYU_DATA || join(process.cwd(), '.codex-phase0') } = {}) {
    this.root = resolve(root)
    this.data = resolve(data)
    this.stateFile = join(this.data, 'daemon.json')
    this.statusFile = join(this.data, 'status.json')
    this.lockFile = join(this.data, 'daemon.lock')
    this.sessions = new Map()
    this.server = null
    this.helper = null
    this.stopTimer = null
    this.statusRevision = 0
    this.statusWrite = Promise.resolve()
    this.started = false
  }

  async start() {
    await mkdir(this.data, { recursive: true })
    await rm(this.statusFile, { force: true })
    this.server = createServer((socket) => this.#handleConnection(socket))
    await new Promise((resolveStart, reject) => {
      this.server.once('error', reject)
      this.server.listen(0, '127.0.0.1', resolveStart)
    })
    const address = this.server.address()
    if (!address || typeof address === 'string') throw new Error('unable to allocate loopback port')
    await writeFile(this.stateFile, JSON.stringify({
      pid: process.pid,
      port: address.port,
      startedAt: Date.now(),
      protocolVersion: PROTOCOL_VERSION,
    }, null, 2))
    this.started = true
    this.#sendHello()
    this.#render()
    return address.port
  }

  #handleConnection(socket) {
    let buffer = ''
    socket.setEncoding('utf8')
    socket.on('data', (chunk) => {
      buffer += chunk
      while (true) {
        const newline = buffer.indexOf('\n')
        if (newline < 0) break
        const line = buffer.slice(0, newline).trim()
        buffer = buffer.slice(newline + 1)
        if (!line) continue
        try {
          this.handle(JSON.parse(line))
        } catch (error) {
          process.stderr.write(`codex-dafeiyu daemon: ${error instanceof Error ? error.message : String(error)}\n`)
        }
      }
    })
  }

  handle(event) {
    if (!event || event.protocolVersion !== PROTOCOL_VERSION || event.kind !== 'hook-event') return
    const sessionId = String(event.sessionId || 'default-session')
    if (event.action === 'session-end') {
      this.sessions.delete(sessionId)
      this.#render()
      this.#scheduleStop()
      return
    }
    const current = this.sessions.get(sessionId) || {
      sessionId,
      state: 'IDLE',
      updatedAt: 0,
    }
    if (event.action === 'session-start') {
      current.state = 'IDLE'
      current.phase = event.phase
      current.stage = event.stage
      current.message = event.message
      current.task = undefined
      current.activity = undefined
      current.clip = undefined
    } else if (event.action === 'pulse') {
      current.state = event.resumeState && STATES.has(event.resumeState) ? event.resumeState : 'IDLE'
      current.activity = event.resumeActivity
      current.phase = event.phase
      current.stage = event.stage
      current.message = event.message
      current.task = event.detail
      current.clip = inferClip(current.state, current.stage, event.resumeClip)
      this.sessions.set(sessionId, { ...current, project: event.project, updatedAt: Date.now() })
      this.#renderPulse(event, current)
      return
    } else if (event.action === 'state') {
      current.state = STATES.has(event.state) ? event.state : 'THINKING'
      current.phase = event.phase
      current.activity = event.activity
      current.stage = event.stage || activityStage(event.activity)
      current.message = event.message
      current.task = event.task
      current.clip = inferClip(current.state, current.stage, event.clip)
    }
    current.project = event.project
    current.updatedAt = Date.now()
    this.sessions.set(sessionId, current)
    this.#render()
    if (this.stopTimer) {
      clearTimeout(this.stopTimer)
      this.stopTimer = null
    }
  }

  #topRecord() {
    return [...this.sessions.values()].sort((left, right) =>
      priorityFor(right.state) - priorityFor(left.state) || right.updatedAt - left.updatedAt
    )[0] || {
      sessionId: 'idle',
      state: 'IDLE',
      project: 'Codex',
      stage: '等待任务',
      message: '鲸鱼娘在这儿等新任务哦',
      updatedAt: Date.now(),
    }
  }

  #render() {
    const record = this.#topRecord()
    this.#publish(message('state', {
      state: record.state,
      sessionId: record.sessionId,
      phase: record.phase || 'aggregate',
      activity: record.activity,
      clip: record.clip,
      stage: record.stage || '处理中',
      message: record.message || '正在继续处理任务呢',
      task: record.task,
      detail: sessionDetail(record),
    }))
  }

  #renderPulse(event, record) {
    const top = this.#topRecord()
    this.#publish(message('pulse', {
      state: event.state,
      ttlMs: Number.isFinite(event.ttlMs) ? event.ttlMs : 1800,
      resumeState: top.state,
      resumeActivity: top.activity,
      resumeClip: top.clip,
      resumeMessage: top.message || '正在继续处理任务呢',
      resumeDetail: sessionDetail(top),
      sessionId: event.sessionId,
      phase: event.phase,
      stage: event.stage,
      message: event.message,
      detail: event.detail || sessionDetail(record),
    }))
  }

  #publish(payload) {
    const current = {
      ...payload,
      revision: ++this.statusRevision,
    }
    this.#send(current)
    const temporaryFile = `${this.statusFile}.${process.pid}.tmp`
    this.statusWrite = this.statusWrite
      .catch(() => {})
      .then(async () => {
        const serialized = JSON.stringify(current, null, 2)
        // On Windows the standalone helper polls this file with a read handle
        // that can briefly block delete/rename. Direct overwrite shares the
        // existing read handle, so retry the write instead of replacing the
        // path underneath the reader.
        if (process.platform === 'win32') {
          let lastError = null
          for (let attempt = 0; attempt < 20; attempt += 1) {
            try {
              await writeFile(this.statusFile, serialized)
              lastError = null
              break
            } catch (error) {
              lastError = error
              await new Promise((resolve) => setTimeout(resolve, 50))
            }
          }
          if (lastError) throw lastError
        } else {
          await writeFile(temporaryFile, serialized)
          await rename(temporaryFile, this.statusFile)
        }
      })
      .catch((error) => {
        process.stderr.write(`codex-dafeiyu status: ${error instanceof Error ? error.message : String(error)}\n`)
      })
  }

  #sendHello() {
    this.#send(message('hello', {
      host: 'codex',
      pluginVersion: '0.1.0',
      state: 'IDLE',
      message: 'Codex 鲸鱼娘已连接',
    }))
  }

  #send(payload) {
    try {
      if (!this.helper || this.helper.exitCode !== null) this.#startHelper()
      this.helper?.stdin.write(`${JSON.stringify(payload)}\n`)
    } catch (error) {
      process.stderr.write(`codex-dafeiyu helper: ${error instanceof Error ? error.message : String(error)}\n`)
    }
  }

  #startHelper() {
    const launch = helperLaunch(this.root)
    const mini = miniMode()
    const scale = process.env.CODEX_DAFEIYU_SCALE || (mini ? '0.6' : '')
    const bubbleScale = process.env.CODEX_DAFEIYU_BUBBLE_SCALE || (mini ? '0.8' : '1')
    const bubbleMode = process.env.CODEX_DAFEIYU_BUBBLE_MODE || (mini ? 'hidden' : 'always')
    const env = {
      ...process.env,
      CODEX_DAFEIYU_LAYOUT_PATH: layoutPath(this.data),
      CODEX_DAFEIYU_MINI: mini ? '1' : '0',
      CODEX_DAFEIYU_SCALE: scale,
      CODEX_DAFEIYU_BUBBLE_SCALE: bubbleScale,
      CODEX_DAFEIYU_BUBBLE_MODE: bubbleMode,
      CODEX_DAFEIYU_BUBBLE_STATES: process.env.CODEX_DAFEIYU_BUBBLE_STATES || 'SUCCESS,ERROR,WAITING',
      CODEX_DAFEIYU_WEBUI_URL: process.env.CODEX_DAFEIYU_WEBUI_URL || 'https://chatgpt.com/codex',
      DSH_DAFEIYU_LAYOUT_PATH: layoutPath(this.data),
      DSH_DAFEIYU_SCALE: scale,
      DSH_DAFEIYU_BUBBLE_SCALE: bubbleScale,
      DSH_DAFEIYU_BUBBLE_MODE: bubbleMode,
      DSH_DAFEIYU_BUBBLE_STATES: process.env.CODEX_DAFEIYU_BUBBLE_STATES || 'SUCCESS,ERROR,WAITING',
      DSH_DAFEIYU_WEBUI_URL: process.env.CODEX_DAFEIYU_WEBUI_URL || 'https://chatgpt.com/codex',
    }
    this.helper = spawn(launch.command, launch.args, {
      cwd: this.root,
      env,
      stdio: ['pipe', 'pipe', 'pipe'],
      windowsHide: true,
    })
    this.helper.stdout?.on('data', () => {})
    this.helper.stderr?.on('data', (chunk) => process.stderr.write(String(chunk)))
    this.helper.once('exit', () => {
      this.helper = null
    })
    this.helper.stdin.on('error', () => {})
    this.helper.stdin.write(`${JSON.stringify(message('hello', {
      host: 'codex',
      pluginVersion: '0.1.0',
      state: 'IDLE',
      message: 'Codex 鲸鱼娘已连接',
    }))}\n`)
    this.helper.stdin.write(`${JSON.stringify(message('config', {
      scale: Number(scale) || (mini ? 0.6 : 1),
      bubbleScale: Number(bubbleScale) || 1,
      bubbleMode,
      bubbleStates: ['SUCCESS', 'ERROR', 'WAITING'],
      reducedMotion: false,
      soundEnabled: true,
      activityLevel: 'normal',
    }))}\n`)
  }

  #scheduleStop() {
    if (this.sessions.size > 0 || this.stopTimer) return
    this.stopTimer = setTimeout(() => {
      if (this.sessions.size === 0) void this.stop()
    }, 60_000)
    this.stopTimer.unref?.()
  }

  async stop() {
    if (this.stopTimer) clearTimeout(this.stopTimer)
    this.stopTimer = null
    try {
      this.helper?.stdin.write(`${JSON.stringify(message('shutdown'))}\n`)
      this.helper?.stdin.end()
    } catch {}
    this.server?.close()
    await this.statusWrite.catch(() => {})
    await rm(this.statusFile, { force: true })
    await rm(`${this.statusFile}.${process.pid}.tmp`, { force: true })
    await rm(this.stateFile, { force: true })
    this.started = false
  }
}

async function acquireLock(lockFile) {
  try {
    const handle = await open(lockFile, 'wx')
    await handle.writeFile(String(process.pid))
    return handle
  } catch {
    try {
      const details = await stat(lockFile)
      if (Date.now() - details.mtimeMs < 10_000) return null
      await rm(lockFile, { force: true })
      const handle = await open(lockFile, 'wx')
      await handle.writeFile(String(process.pid))
      return handle
    } catch {
      return null
    }
  }
}

export async function main() {
  const root = process.env.CODEX_DAFEIYU_ROOT || defaultRoot
  const data = process.env.CODEX_DAFEIYU_DATA || join(process.cwd(), '.codex-phase0')
  await mkdir(data, { recursive: true })
  const lock = await acquireLock(join(data, 'daemon.lock'))
  if (!lock) return
  const daemon = new PetDaemon({ root, data })
  const cleanup = async () => {
    await daemon.stop()
    await lock.close()
    await rm(join(data, 'daemon.lock'), { force: true })
  }
  process.once('SIGINT', () => void cleanup().finally(() => process.exit(0)))
  process.once('SIGTERM', () => void cleanup().finally(() => process.exit(0)))
  try {
    await daemon.start()
  } catch (error) {
    process.stderr.write(`codex-dafeiyu daemon failed: ${error instanceof Error ? error.message : String(error)}\n`)
    await cleanup()
    process.exitCode = 1
  }
}

if (process.argv[1] && resolve(process.argv[1]) === resolve(fileURLToPath(import.meta.url))) {
  await main()
}
