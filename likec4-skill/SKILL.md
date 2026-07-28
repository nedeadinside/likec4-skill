---
name: likec4-skill
description: >-
  Turn a plain-language architecture description or a source repository into
  correct, validated C4 diagrams written in the LikeC4 DSL (.c4 / .likec4
  files). Use when the user wants to model or document software architecture,
  draw a C4 diagram, produce a System Context / Container / Component /
  Deployment / Dynamic (data flow) view, "diagram the architecture", "document
  this system", "generate C4 from this code", set up a LikeC4 project, fix or
  review .c4 files, or mentions C4, LikeC4, likec4, Structurizr,
  architecture-as-code, or architecture diagrams. Validates output with the
  LikeC4 CLI (pinned version) before delivery.
license: MIT
compatibility: opencode
metadata:
  domain: software-architecture
  dsl: likec4
  likec4-version: 1.59.2
  likec4-min-version: 1.53.0
---

# LikeC4 C4 Diagrams

Produce **valid C4 diagrams in the LikeC4 DSL** from a verbal description or a
codebase, and validate them with the CLI before delivery. References are split
by concern — read only what the task needs, **before** writing that part; do
not guess syntax.

Everything here is verified against **likec4 1.59.2** (see
`references/setup-and-validation.md` for the pin and upgrade procedure).

## Hard rules (only two)

1. **Validate before delivering.** Run `likec4 validate` on the project and
   deliver only on exit 0. No CLI available at all → do the documented
   self-check and disclose it. Procedure: `references/setup-and-validation.md`.
2. **Never invent DSL syntax.** If unsure, open the relevant reference; if
   still unsure, consult https://likec4.dev/dsl/.

## Setup (first thing, once per session)

```bash
LC4="npx -y likec4@1.59.2"
v="$(likec4 --version 2>/dev/null | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+' | tail -1)"
[ -n "$v" ] && [ "$(printf '%s\n1.53.0\n' "$v" | sort -V | head -1)" = "1.53.0" ] && LC4=likec4
```
An installed CLI is used only at **>= 1.53.0** — older ones have no `format`
command and 1.52.0 exits 0 on invalid models, so both gates below would pass
silently. No global install required — `npx -y likec4@1.59.2` works in any
environment with Node 22+ and network (first run downloads, then cached). For
projects the user keeps, recommend `npm install --save-dev likec4@1.59.2`.
Details, version floor, offline fallback, and the error catalogue:
`references/setup-and-validation.md`.

## Task → what to read

| Task in front of you | Read |
| --- | --- |
| System Context / Landscape ("who uses it, what it talks to") | `references/levels/l1-context.md` |
| Containers ("what runs inside", tech choices) | `references/levels/l2-container.md` |
| Components (inside one container) | `references/levels/l3-component.md` |
| Code level — classes/interfaces of one component | `references/levels/l4-code.md` |
| Data flow / scenario / sequence (login, checkout, pipeline) | `references/levels/flows-dynamic.md` |
| Infrastructure / "where does it run" | `references/levels/deployment.md` |
| Any cross-cutting DSL question (spec, model, FQN, extend, predicates) | `references/syntax-core.md` |
| Colors, shapes, icons, legend, layout | `references/styling.md` |
| Given a repo / source code | `references/code-to-diagram.md` |
| Install, validate, format, errors, preview/export/CI | `references/setup-and-validation.md` |

## Scale the structure to the task

- **Small ask** (one system, quick context/container picture): start from
  `templates/minimal/` — 3 files (`spec.c4`, `model.c4`, `views.c4`). Do not
  build a multi-folder project for this.
- **Real system** (2+ levels, several systems, deployment, flows): use the
  `templates/full/` layout — copy the files and rename content:

```
architecture/
├── spec.c4                 # the ONLY specification block: all kinds
├── model/
│   ├── landscape.c4        # top-level systems + actors
│   ├── <system>.c4         # one file per system, via extend <system> { … }
│   └── externals.c4        # externalSystem elements
├── deployment/prod.c4      # nodes + instanceOf (kinds stay in spec.c4)
└── views/
    ├── context.c4          # Level 1 (view index)
    ├── <system>-views.c4   # Level 2/3 views with drill-down
    └── dynamic-flows.c4    # dynamic + deployment views
```

Grow by adding files (new system → new `model/<s>.c4`), keep model separate
from views, and keep the specification in one file. All `.c4` files under the
folder merge into one model automatically.

Templates use **built-in theme colors only** (in-scope = `primary`, external =
`gray` via the `externalSystem` kind, person = `indigo`) — no custom colors,
no tags. This keeps the C4 convention and adapts to light/dark themes.

## Workflow

1. **Scope** — identify the system, actors, externals; pick levels. Defaults:
   Context + Container; Component only for a non-trivial container; a dynamic
   view for each key scenario (recommended); deployment when infra matters;
   Level 4 only on explicit request or clear justification
   (`references/levels/l4-code.md` — default substitute is a source link).
   Repo as input →
   `references/code-to-diagram.md`. Genuinely ambiguous scope → ask one
   question; otherwise proceed and state assumptions.
2. **Set up** — copy the matching template, run the `LC4` line above.
3. **Model, then views** — write model files, then views with drill-down
   (`view of`, `navigateTo`), reading the level file for each diagram you
   produce.
4. **Validate, then format** — `$LC4 validate <dir>`; fix `Line N:` errors
   (catalogue in `setup-and-validation.md`) until exit 0. Then `$LC4 format
   <dir>` and re-validate, so the files match the canonical style the user's
   own tooling produces.
5. **Deliver** — show the file tree, the validation result, and how to view
   the diagrams (`$LC4 start <dir>`; export/CI options in
   `setup-and-validation.md`).

## Quality bar (check before delivery)

- [ ] `likec4 validate` exit 0 (or disclosed self-check), stderr clean.
- [ ] `likec4 format <dir> --check` exit 0 — files are in canonical form.
- [ ] Every element has a description; every container/component a
      `technology`; every relationship a directed label (what + how).
- [ ] Every view has a `title`; ≤ ~20 elements per view — split crowded views.
- [ ] Levels connect: Context → Container → Component via `view of` /
      `navigateTo`.
