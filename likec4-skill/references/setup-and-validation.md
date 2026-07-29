# Setup & validation

## Pinned version — one file, no exceptions

The pin is the single line in **`scripts/likec4-version`**. That file is the only
place the number exists: the checks read it, and so should you. Every construct
in this skill is compiled against it (`scripts/check-snippets.sh` proves it on
every snippet in every reference file). The DSL changes between minor versions,
so the pin is the contract:

```bash
PIN="$(cat <this-skill-folder>/scripts/likec4-version)"
LC4="npx -y likec4@$PIN"
$LC4 validate <dir>
```

**Do not substitute a locally installed `likec4`**, however new it looks. Other
versions disagree quietly rather than loudly: measured, older CLIs both reject
valid flow-control syntax and exit 0 on models this one rejects — either way the
delivery gate stops meaning anything. Run the pin, always.

Requires **Node.js 22+** (the package declares `node >=22.22.3`; npm treats
`engines` as advisory, recent Node 22 works). First `npx` run downloads the
package (~a minute); later runs hit the npx cache.

For a project the user will keep, recommend the same version as a dev
dependency, so their CI reproduces what was delivered:
```bash
npm install --save-dev "likec4@$PIN"
```
Global install (`npm i -g likec4`) is not recommended: it drifts from
per-project versions and breaks reproducibility.

If the environment has no network and no cached likec4, fall back to the
self-check below and say so explicitly.

## Validate — in place, before delivery

**Never hand over LikeC4 that hasn't compiled.** `likec4 validate` is
read-only — it does not modify or create files — so validate the project
directory directly. No temp dirs, no copying.

```bash
$LC4 validate ./architecture
echo "exit=$?"
```

- Success: exit `0`, output contains `✓ Valid (N files)`.
- Failure: **non-zero exit**, one `ERROR ... Invalid <file>` per bad file, each
  followed by `Line N: <message>` lines, then `✗ Invalid (N files, M errors)`.
- Checks syntax, semantic errors (unresolved references, invalid
  relationships), and layout drift.
- Beware shell pipes: `$LC4 validate dir | grep ...; echo $?` reports grep's
  exit, not likec4's. Capture the exit code before piping.

On errors: fix the source, re-run, repeat until exit 0. Fix the **first**
reported error first — later ones are often cascades. Do not deliver broken
code and do not "explain away" a non-zero exit.

## Format — `likec4 format`

The CLI ships a canonical formatter. Run it **after** the model compiles and
**before** delivery, so handwritten files match what the VS Code extension and
the user's own `format` runs would produce — otherwise the first thing the user
does to your output is generate a diff.

```bash
$LC4 format ./architecture           # rewrites files in place
$LC4 format ./architecture --check   # read-only gate: exit 1 if anything differs
```

- `--check` **changes nothing**; it lists every file that needs formatting and
  exits `1`. Use it as the gate, `format` (no flag) as the fix.
- Streams match `validate`: the per-file `needs formatting` / `formatted`
  lines go to **stdout**, the `N of M file(s) need formatting:` summary to
  **stderr**.
- Scope it with `--files <path>` (repeatable) or `-p <project>` (repeatable)
  when you only touched part of a workspace.
- Formatting is purely syntactic — it never changes the model, so a project
  that was `✓ Valid` stays `✓ Valid`. Re-run `validate` anyway; it costs a
  second and proves it.
- What it normalizes: indentation, brace placement, and reflowing multi-line
  constructs — e.g. it splits `include X with { … }` so `include` sits on its
  own line. Don't fight it; adopt its output.

Order in practice: **write → `validate` (exit 0) → `format` → `validate`
again**. Formatting a file that doesn't parse is pointless, which is why
`validate` comes first.

## Fast iteration loop — `--json --file`, never as the gate

While editing one file, narrow the output instead of re-reading the whole
project's errors:

```bash
$LC4 validate --json --no-layout -f ./architecture/model/orders.c4 ./architecture
```

```json
{ "valid": true, "errors": [],
  "stats": { "totalFiles": 2, "totalErrors": 2, "filteredFiles": 0, "filteredErrors": 0 } }
```

- `--no-layout` skips layout computation — noticeably faster in a tight loop.
- `-f` / `--file` is repeatable and restricts *reporting* to those files.
- `filteredFiles` counts **filtered files that contain errors**, not the number
  of `-f` flags. On a clean file it is `0`, which is not a problem.

**The trap:** `valid` and the **exit code describe only the filtered subset**.
Above, `valid: true` and exit `0` while `totalErrors: 2` — two real errors
elsewhere in the project. Read `stats.totalErrors`, which stays honest.

So `--file` is an iteration tool. The delivery gate is always the bare project
path.

### Delivery gate

Both must hold before handing anything over — no `--file`, no `--json`:

```bash
$LC4 validate ./architecture     # exit 0
$LC4 format   ./architecture --check   # exit 0
```

Exit 0 is necessary, not sufficient: three constructs compile clean and still
produce the wrong diagram. Check them by hand if the model uses them —
`with { }` in a deployment view (renders **empty**, `levels/deployment.md`),
an `extend` on a relationship whose matcher misses (`syntax-core.md`), and
`validate --file` run as if it were this gate.

In CI, run the same two commands — `--check` keeps the repo formatted without
the pipeline ever writing to the working tree.

## Reading errors → fixes (catalogue)

Messages below are verbatim from the compiler (verified on the pinned version).

| Message | Cause | Fix |
| --- | --- | --- |
| `Could not resolve reference to ElementKind named 'X'` | Used kind `X` in the model but never declared `element X` — there are **no built-in element kinds** | Add `element X` to `spec.c4` |
| `Could not resolve reference to Tag named 'X'` | Used `#X` without `tag X` in the specification | Declare the tag, or drop it (this skill's templates don't use tags) |
| `Could not resolve reference to Referenceable named 'X'` / `Target not resolved` | Typo, element not defined, or a **nested name used in a view** | Check spelling; use **FQN** (`system.container.X`), especially inside `view` / `dynamic view` / `deployment view` |
| `'X' is ambiguous` | Same bare name exists under two parents | Qualify with FQN (`s1.api` vs `s2.api`) |
| `Invalid parent-child relationship` | A relationship connects an element to its own ancestor/descendant | Relate siblings, or move the edge to the correct level |
| `Expecting token of type '}' but found `#`` | Tags placed **after** other properties in an element block | Move `#tag` lines to the **top** of the block, before `title`/`description`/etc. |
| `Expecting token of type '}' but found `'...'`` (on a dynamic step) | Second inline string on a `dynamic view` step — steps take **one** inline label only, no inline technology | Keep a single label; put protocol into the label text or a nested `{ notes '...' }` |
| `'X' already defined` | Two elements share a name under the same parent | Rename one, or nest it under a different parent |
| Errors about `include`/`exclude`/`where`/`with` tokens | Predicate ordering — `where` must come **before** `with`; view properties before predicates | Reorder per `syntax-core.md` |
| Layout drift warning | Manual layout in a `.c4` is stale | Re-open in the editor to relayout, or ignore if you don't use manual layout |
| `Could not resolve reference to Referenceable named 'loop'` (or `alt`, `opt`, `try`) | Flow-control block in a dynamic view compiled by a CLI older than the pin | Run the pinned version; the keywords parse as element names on older ones |
| `"when" alternative branch must be inside "alt"` | `when`/`if`/`else` outside an `alt` block | Wrap the branches in `alt { … }` (`levels/flows-dynamic.md`) |
| `"loop" can not be used as an alternative branch, only "if", "when" or "else" are allowed` | `loop`/`opt`/`parallel`/`try` written as a direct child of `alt` | Nest it inside a `when` / `else` branch |
| `Nested parallel blocks are not allowed` | `parallel` inside `parallel` | One `parallel` block holds all the concurrent steps |
| ``Expecting token of type '}' but found `metadata` `` (dynamic step) | A step body takes `title`/`description`/`technology`/`notes`/`navigateTo` only | Put metadata on the model relationship instead |
| `Could not resolve reference to DynamicView named 'X'` | `navigateTo` in a **dynamic** step pointing at a static view | Point it at a `dynamic view`, or navigate from a static view instead |
| ``Expecting token of type '}' but found `global` `` (deployment view) | `global style` used inside a deployment view | Use a local `style … { }` predicate in that view |

### Errors the compiler does *not* report

| Symptom | Cause | Fix |
| --- | --- | --- |
| Deployment view renders empty, `✓ Valid` | `include … with { … }` in a deployment view | Local `style` predicate instead (`levels/deployment.md`) |
| `extend` on a relationship changes nothing, `✓ Valid` | Matcher missed: source + target + kind + title must all match | Repeat the relationship verbatim, kind arrow included (`syntax-core.md`) |
| `valid: true`, exit 0 on a project you know is broken | `validate --file` was used as the gate | Gate on bare `validate <dir>`; read `stats.totalErrors` |
| Config options have no effect; `import` stops resolving | A broken or misspelled `likec4.config.json` is skipped, not reported — `validate` still exits 0 | Read the `add '<name>'` / `loaded N projects` lines (`project-config.md`) |

### When the message doesn't say enough — debugging order

1. **Locate the file.** `$LC4 validate --json --no-layout -f <edited.c4> <dir>`:
   `filteredErrors: 0` with `totalErrors > 0` means your file is clean and the
   problem is upstream.
2. **Fix the first error only, then re-run.** Later ones are usually cascades of
   the first unresolved name.
3. **Check the FQN against the hierarchy**, character by character — most
   `not resolved` errors are a missing parent segment, not a typo.
4. **Bisect by block.** Comment out `model`, `deployment` and `views`; validate
   `specification` alone, then add one block back at a time.
5. **Test a predicate in isolation.** Copy the failing `include`/`exclude` into
   a throwaway view with `include *` above it — wildcard scope
   (`predicates.md`) is the usual culprit.
6. **Inspect the result, not just the exit code:** `$LC4 export json <dir>
   --skip-layout --pretty` shows what was actually computed. This is the only
   way to see the silent failures below.

### Large models

- Keep `specification` in its own file: editing it re-parses the whole project.
- A view that exports as a partial image is too big — split it and link with
  `navigateTo` (the ≤ ~20 element rule in SKILL.md exists for this reason).

Also watch **stderr warnings** even on exit 0 — e.g. `Sequence view does not
support nested actors` means a dynamic view steps through a compound element;
route steps through leaf elements (see `levels/flows-dynamic.md`).

## Fallback self-check (only if the CLI truly cannot run)

State explicitly that validation was a self-check, not the CLI, and recommend
the user run `likec4 validate` locally. Check:

1. Every kind used is declared in `specification` (`element`, `relationship`,
   `deploymentNode`).
2. Every referenced element exists; nested references in views use **FQN**.
3. No parent↔child relationships; no duplicate names under one parent.
4. Balanced braces; each top-level block well-formed; tags (if any) first in
   their block.
5. Every view has a `title`; `navigateTo` / `view of` targets exist.
6. Relationships are directed and labelled; kinds used (`-[async]->`) are
   declared; dynamic steps carry a single inline label.

## After validation — preview, export, CI

Delivering `.c4` files is half the job; tell the user how to use them.

**The command list is closed.** `likec4 <command>` is one of: `start`
(`serve`/`dev`), `build` (`bundle`), `gen` (`generate`/`codegen`), `export`,
`format` (`fmt`), `preview`, `sync`, `validate`, `list-icons`, `mcp`, `lsp`,
`check-update`, `completion`. There is **no** `check`, `lint`, `verify`,
`compile` or `render` command — the model that invents one gets a help dump and
**exit 0**, which is how a broken model ships. Every command takes the project
directory as its last argument and `-p <project>` to pick one project of a
multi-project workspace.

- **Live preview:** `$LC4 start ./architecture` — local dev server with hot
  reload; keep it running while editing. The **VS Code extension "LikeC4"**
  gives inline previews and language support in the editor.
- **Static site:** `$LC4 build ./architecture -o ./dist` — one deployable
  website with all views. Useful flags: `--base /repo-name/` for GitHub Pages,
  `--theme dark`, `--output-single-file`, `--public ./assets`.
- **Images:** `$LC4 export png ./architecture -o ./images` — PNG per view (uses
  Playwright; the CLI prompts to install it on first run).
  `--flat` puts every image in one directory instead of mirroring the source
  tree, `--theme light|dark`, `--seq` renders dynamic views with the sequence
  layout, `-f <pattern>` exports only matching view ids, `-i` continues past a
  view that fails. `export jpg` and `export drawio` take the same shape.
  **Watch the flag collision:** `-f` is `--file` on `validate` but `--filter`
  on `export`; `-o` is `--outdir` for `png` and `--outfile` for `json`.
- **Structured data:** `$LC4 export json ./architecture -o model.json
  --skip-layout --pretty` — the fastest way to *inspect what the model actually
  computed*, which is how you catch the silent failures listed above.
- **Diagrams for READMEs/PRs:** `$LC4 gen mermaid|plantuml|d2|dot ./architecture`
  (`codegen` is an alias of `gen`). Also `gen model` for a typed
  `LikeC4Model.ts`, `gen react`, `gen webcomponent`.
- **Icons:** `$LC4 list-icons` lists ~5k bundled icons; `-g aws|azure|gcp|tech|bootstrap`
  filters by group and `-f json` makes it greppable — use it instead of
  guessing an icon name (a wrong one fails with
  `Could not resolve reference to LibIcon named 'X'`).
- **MCP server:** `$LC4 mcp ./architecture` (stdio by default, `--http` /
  `-p <port>` for HTTP) exposes the model to an MCP client.
- **CI:** run `validate` and `format --check` in the pipeline; official
  LikeC4 GitHub Actions exist for preview/export.

## Final gate

Deliver only when `likec4 validate` exited **0** (or the disclosed self-check
passed). Show the user the file tree, the validation result, and the one
command to view the diagrams (`likec4 start`).
