# 🧩 dominikwozniak-skills

A personal bucket of Claude Code skills I actually use or share — distributed as an installable
plugin marketplace.

Each skill lives once in `skills/<name>/SKILL.md` and ships inside a plugin (collection) listed in
`.claude-plugin/marketplace.json`. Install the marketplace once, then add the plugins you want.

## 🚀 Quick start

```
claude plugin marketplace add git@github.com:dominikwozniak/dominikwozniak-skills.git
claude plugin install dw-misc
```

`dw-misc` bundles cross-cutting helpers (e.g. `dw-handoff`). `example-skill` is just a placeholder/template.

## 🧩 Skills

- **`dw-handoff`** (plugin `dw-misc`) — compact the session into a handoff doc at `.ai/handoffs/` for the next agent.
- **`example-skill`** (plugin `example-skill`) — placeholder/template; copy it to start a real skill.

## 🤝 Contributing

Layout, conventions, the add-a-skill checklist, CI, and repo prep all live in
[`AGENTS.md`](AGENTS.md) (`CLAUDE.md` is a symlink to it).

## 📜 License

MIT
