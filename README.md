# likec4-skill

An [Agent Skill](https://agentskills.io) that turns a plain-language architecture
description or a source repository into correct, validated **C4 diagrams** written
in the [LikeC4](https://likec4.dev) DSL (`.c4` / `.likec4` files).

Covers all C4 levels plus deployment and dynamic (data-flow) views:

- **L1 System Context** · **L2 Container** · **L3 Component** · **L4 Code**
- **Deployment** views
- **Dynamic / flow** views

Every generated project is validated with a pinned LikeC4 CLI version
(`likec4 validate` + `likec4 format --check`) before delivery — the agent does
not guess syntax.

## Installation

The skill is the `likec4-skill/` folder inside this repo. Same `SKILL.md` format works in
Claude Code, Codex CLI, and OpenCode — only the install path differs:

| CLI | Global | Per-project |
|---|---|---|
| Claude Code | `~/.claude/skills/` | `.claude/skills/` |
| Codex CLI | `~/.codex/skills/` | `.codex/skills/` |
| OpenCode | `~/.config/opencode/skills/` | `.opencode/skills/` |

> OpenCode also reads `~/.claude/skills/` and `.claude/skills/` directly, so a
> single Claude Code install covers both.

### Manual (any OS, including Windows)

Download `likec4-skill.zip` from the latest
[release](../../releases/latest) and extract it into the skills directory of
your CLI, e.g. `%USERPROFILE%\.claude\skills\` on Windows or
`~/.claude/skills/` on Linux/macOS. You should end up with
`.../skills/likec4-skill/SKILL.md`.

### From git (Linux/macOS)

Clone once, symlink everywhere — `git pull` then updates every CLI at once:

```sh
git clone https://github.com/nedeadinside/likec4-skill
ln -s "$(pwd)/likec4-skill/likec4-skill" ~/.claude/skills/likec4-skill
ln -s "$(pwd)/likec4-skill/likec4-skill" ~/.codex/skills/likec4-skill
```

## Usage

The skill triggers automatically on requests like:

- "Diagram the architecture of this repo"
- "Draw a C4 container view for our payment system"
- "Document this system as architecture-as-code"
- "Fix / review these .c4 files"

Or invoke it explicitly: `/likec4-skill` (Claude Code),
`$likec4-skill` (Codex).

## Layout

```
likec4-skill/               # the skill itself (repo root holds README + CI)
├── SKILL.md                  # entry point: workflow + routing to references
├── references/               # DSL syntax, split by concern
│   ├── syntax-core.md        # specification / model / views fundamentals
│   ├── levels/               # one file per diagram level (l1–l4, deployment, flows)
│   ├── styling.md
│   ├── code-to-diagram.md    # generating C4 from an existing codebase
│   └── setup-and-validation.md
├── templates/
│   ├── minimal/              # smallest valid 3-file project
│   └── full/                 # multi-file project: model/, views/, deployment/
└── scripts/
    └── check.sh              # validates all templates with the pinned CLI version
```

## Development

The LikeC4 version is pinned in `scripts/check.sh` (`LIKEC4_VERSION`, single
source of truth). Upgrade procedure is documented in the script header and in
`references/setup-and-validation.md`.

**Minimum supported LikeC4: 1.53.0** (`LIKEC4_MIN`). Older CLIs are ignored in
favour of the pin — below 1.52.0 there is no `format` command (the check exits
0 without checking anything), and 1.52.0 exits 0 on an invalid model. An
installed CLI at or above the floor is used as-is.
