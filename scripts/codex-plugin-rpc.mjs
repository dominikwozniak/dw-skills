#!/usr/bin/env node

import fs from "node:fs"
import path from "node:path"
import process from "node:process"
import readline from "node:readline"
import { spawn } from "node:child_process"

const [marketplaceArg, pluginName, cwdArg, expectedVersion] = process.argv.slice(2)
if (!marketplaceArg || !pluginName || !cwdArg || !expectedVersion) {
  console.error("usage: codex-plugin-rpc.mjs <marketplace.json> <plugin> <cwd> <version>")
  process.exit(2)
}

const marketplacePath = path.resolve(marketplaceArg)
const cwd = path.resolve(cwdArg)
const manifest = JSON.parse(fs.readFileSync(path.join(cwd, ".codex-plugin/plugin.json"), "utf8"))
if (manifest.version !== expectedVersion) {
  throw new Error(`source manifest version ${manifest.version}; expected ${expectedVersion}`)
}

const child = spawn("codex", ["app-server"], {
  cwd,
  env: process.env,
  stdio: ["pipe", "pipe", "pipe"],
})
const lines = readline.createInterface({ input: child.stdout })
let stderr = ""
child.stderr.on("data", (chunk) => {
  stderr += chunk
})

const send = (message) => child.stdin.write(`${JSON.stringify(message)}\n`)
const fail = (error) => {
  clearTimeout(timeout)
  child.kill()
  if (stderr) console.error(stderr.trim())
  console.error(error instanceof Error ? error.message : String(error))
  process.exit(1)
}

const timeout = setTimeout(() => fail("timed out waiting for Codex app-server"), 20000)
child.once("error", fail)
child.once("exit", (code) => {
  if (code && process.exitCode == null) fail(`Codex app-server exited with ${code}`)
})

lines.on("line", (line) => {
  let message
  try {
    message = JSON.parse(line)
  } catch {
    return
  }
  if (message.error) return fail(`Codex app-server error: ${JSON.stringify(message.error)}`)

  if (message.id === 1) {
    send({ jsonrpc: "2.0", method: "initialized" })
    send({
      jsonrpc: "2.0",
      id: 2,
      method: "plugin/install",
      params: { marketplacePath, pluginName },
    })
    return
  }

  if (message.id === 2) {
    send({ jsonrpc: "2.0", id: 3, method: "plugin/list", params: { cwds: [cwd] } })
    return
  }

  if (message.id === 3) {
    const plugins = (message.result?.marketplaces ?? []).flatMap(
      (marketplace) => marketplace.plugins ?? [],
    )
    const plugin = plugins.find((entry) => entry.id === `${pluginName}@dw-skills`)
    if (!plugin?.installed || !plugin?.enabled) {
      return fail(`plugin/list did not report enabled ${pluginName}@dw-skills`)
    }
    clearTimeout(timeout)
    process.exitCode = 0
    console.log(
      JSON.stringify({
        installed: [
          {
            pluginId: plugin.id,
            installed: plugin.installed,
            enabled: plugin.enabled,
            version: expectedVersion,
          },
        ],
      }),
    )
    child.stdin.end()
  }
})

send({
  jsonrpc: "2.0",
  id: 1,
  method: "initialize",
  params: {
    clientInfo: { name: "dw-skills-install-smoke", version: expectedVersion },
    capabilities: { experimentalApi: true },
  },
})
