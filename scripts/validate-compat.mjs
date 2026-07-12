#!/usr/bin/env node

import fs from "node:fs"
import path from "node:path"
import process from "node:process"

const root = process.cwd()
const fail = (message) => {
  console.error(`::error::${message}`)
  process.exitCode = 1
}
const readJson = (file) => JSON.parse(fs.readFileSync(path.join(root, file), "utf8"))
const packageVersion = readJson("package.json").version
const codexManifest = readJson(".codex-plugin/plugin.json")
const claudeMarketplace = readJson(".claude-plugin/marketplace.json")

const versions = new Map([
  ["package.json", packageVersion],
  [".codex-plugin/plugin.json", codexManifest.version],
  [".claude-plugin/marketplace.json metadata", claudeMarketplace.metadata.version],
])
for (const plugin of claudeMarketplace.plugins) {
  versions.set(`Claude marketplace ${plugin.name}`, plugin.version)
  versions.set(
    `${plugin.source}/.claude-plugin/plugin.json`,
    readJson(`${plugin.source}/.claude-plugin/plugin.json`).version,
  )
}
for (const [source, version] of versions) {
  if (version !== packageVersion) fail(`${source} has ${version}; expected ${packageVersion}`)
}

const skillsDir = path.join(root, "skills")
const skillNames = fs
  .readdirSync(skillsDir, { withFileTypes: true })
  .filter(
    (entry) => entry.isDirectory() && fs.existsSync(path.join(skillsDir, entry.name, "SKILL.md")),
  )
  .map((entry) => entry.name)
  .sort()

let descriptionBudget = 0
const claudeExplicit = []
const codexExplicit = []
for (const name of skillNames) {
  const file = path.join(skillsDir, name, "SKILL.md")
  const body = fs.readFileSync(file, "utf8")
  const frontmatter = body.match(/^---\n([\s\S]*?)\n---/m)?.[1] ?? ""
  const descriptionMatch = frontmatter.match(
    /^description:\s*(?:>-\s*\n((?:[ \t]+.*\n?)+)|([^\n]+))/m,
  )
  const description = (descriptionMatch?.[1] ?? descriptionMatch?.[2] ?? "")
    .split("\n")
    .map((line) => line.trim())
    .join(" ")
    .trim()
  if (!description) fail(`${name}: missing description`)
  if (description.length > 350)
    fail(`${name}: description is ${description.length} chars (max 350)`)
  descriptionBudget += description.length
  if (/^disable-model-invocation:\s*true$/m.test(frontmatter)) claudeExplicit.push(name)
  const openaiFile = path.join(skillsDir, name, "agents/openai.yaml")
  if (fs.existsSync(openaiFile)) {
    const openai = fs.readFileSync(openaiFile, "utf8")
    if (/allow_implicit_invocation:\s*false/.test(openai)) codexExplicit.push(name)
  }
  if (body.includes("${CLAUDE_PLUGIN_ROOT}")) fail(`${name}: contains CLAUDE_PLUGIN_ROOT`)
  if (body.includes("$ARGUMENTS") && !body.includes("literal `$ARGUMENTS`")) {
    fail(`${name}: uses $ARGUMENTS without the Codex literal-placeholder fallback`)
  }
  if (body.includes("AskUserQuestion")) fail(`${name}: names a host-specific question tool`)
}
if (descriptionBudget > 6000) fail(`description catalog is ${descriptionBudget} chars (max 6000)`)
if (claudeExplicit.join() !== codexExplicit.sort().join()) {
  fail(`explicit-only mismatch: Claude=[${claudeExplicit}] Codex=[${codexExplicit.sort()}]`)
}
if (skillNames.length !== 17) fail(`expected 17 skills, found ${skillNames.length}`)

const publishedRoots = ["skills", "scripts/runtime", ".codex-plugin", ".agents/plugins"]
for (const publishedRoot of publishedRoots) {
  const stack = [path.join(root, publishedRoot)]
  while (stack.length) {
    const current = stack.pop()
    for (const entry of fs.readdirSync(current, { withFileTypes: true })) {
      const target = path.join(current, entry.name)
      if (entry.isDirectory()) stack.push(target)
      else if (
        entry.isFile() &&
        fs.readFileSync(target, "utf8").includes("/Users/dominik.wozniak")
      ) {
        fail(`${path.relative(root, target)} contains an author-local absolute path`)
      }
    }
  }
}

if (!process.exitCode) {
  console.log(
    `OK  ${skillNames.length} skills; descriptions ${descriptionBudget}/6000; version ${packageVersion}`,
  )
}
