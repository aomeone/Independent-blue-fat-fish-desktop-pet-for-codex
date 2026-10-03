import { copyFile, mkdir, readFile, rename, unlink, writeFile } from 'node:fs/promises'
import { existsSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import process from 'node:process'

const args = process.argv.slice(2)
function valueFor(name, fallback = '') {
  const index = args.indexOf(name)
  return index >= 0 ? args[index + 1] || fallback : fallback
}

const codexHome = resolve(valueFor('--codex-home', `${process.env.HOME}/.codex`))
const pluginRoot = resolve(valueFor('--plugin-root', resolve(dirname(fileURLToPath(import.meta.url)), '..')))
const nodePath = valueFor('--node', 'node')
const noBackup = args.includes('--no-backup')
const hooksPath = `${codexHome}/hooks.json`
const backupPath = `${hooksPath}.bak`
const hookScript = `${pluginRoot}/hooks/codex-pet.mjs`
const command = `"${nodePath}" "${hookScript}"`
const events = [
  'SessionStart', 'UserPromptSubmit', 'PreToolUse', 'PostToolUse',
  'PermissionRequest', 'SubagentStart', 'SubagentStop', 'Stop',
  'Interrupt', 'SessionEnd',
]

let config = {}
if (existsSync(hooksPath)) {
  try {
    config = JSON.parse(await readFile(hooksPath, 'utf8'))
  } catch (error) {
    throw new Error(`Cannot parse existing hooks.json; no changes written: ${error.message}`)
  }
}
if (!config || typeof config !== 'object' || Array.isArray(config)) {
  throw new Error('Existing hooks.json must contain an object.')
}
if (!config.hooks || typeof config.hooks !== 'object' || Array.isArray(config.hooks)) {
  config.hooks = {}
}

for (const event of events) {
  const groups = Array.isArray(config.hooks[event]) ? config.hooks[event] : []
  const filtered = groups.filter((group) => {
    const hooks = Array.isArray(group?.hooks) ? group.hooks : []
    return !hooks.some((hook) => hook?.command === command)
  })
  filtered.push({
    hooks: [{
      type: 'command',
      command,
      async: event !== 'SessionEnd',
      timeout: event === 'Interrupt' || event === 'SessionEnd' ? 3 : 5,
    }],
  })
  config.hooks[event] = filtered
}

await mkdir(dirname(hooksPath), { recursive: true })
if (existsSync(hooksPath) && !noBackup) await copyFile(hooksPath, backupPath)
const temporary = `${hooksPath}.${process.pid}.tmp`
try {
  await writeFile(temporary, `${JSON.stringify(config, null, 2)}\n`, 'utf8')
  await rename(temporary, hooksPath)
} finally {
  if (existsSync(temporary)) await unlink(temporary).catch(() => {})
}

console.log('Installed Codex whale pet user hooks.')
console.log(`Hook script: ${hookScript}`)
console.log(`Node: ${nodePath}`)
console.log(`Configuration: ${hooksPath}`)
if (!noBackup && existsSync(backupPath)) console.log(`Previous configuration backed up at: ${backupPath}`)
console.log('Restart Codex Desktop, then open /hooks and trust the new user hooks if prompted.')
