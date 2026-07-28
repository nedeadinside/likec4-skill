# Setup & validation

## Pinned version

This skill is written and tested against **LikeC4 1.59.2** (also verified on
1.56.0). The DSL evolves between minor versions, so use the pin — snippets in
this skill are guaranteed to compile on it, not on arbitrary versions.
Requires **Node.js 22+** (the package declares `node >=22.22.3`; npm treats
`engines` as advisory, recent Node 22 works).

### Minimum usable version: 1.53.0

An already-installed CLI is only acceptable at **>= 1.53.0**. Below that the
skill's two hard rules cannot be enforced — measured, not guessed:

| Range | What breaks |
| --- | --- |
| < 1.52.0 | No `format` command. `likec4 format <dir> --check` is an *unknown command*: it prints the help text and **exits 0**, so the format gate silently passes without checking anything. |
| 1.52.0 | `format` exists, but `validate` prints `ERROR ... Invalid` and still **exits 0** on a broken model — the "deliver only on exit 0" rule becomes meaningless. |
| >= 1.53.0 | Both commands behave: `validate` exits 1 on an invalid model, `format --check` exits 1 on drift. Templates compile and are already canonical; `export json` output is identical to 1.59.2. |

So: below 1.53.0 ignore the installed binary and run the pinned version via
`npx` instead. `scripts/check.sh` enforces this automatically.

## Getting a working `likec4` command

Resolution order — use the first that applies:

1. **Already on PATH** (`command -v likec4`) → check `likec4 --version` first.
   `>= 1.53.0` → use it as-is (expect some syntax drift the further it is from
   the pin). Older → skip it, go to step 3.
2. **Project has it as a dependency** (`node_modules/.bin/likec4` or
   `likec4` in `package.json`) → run via `npx likec4 <command>` from the
   project root.
3. **Nothing installed** → run pinned, no install step needed:
   ```bash
   npx -y likec4@1.59.2 <command>
   ```
   First run downloads the package (~a minute); later runs hit the npx cache.

For a project the user will keep, recommend a dev dependency so the version is
pinned per-project and CI-reproducible:
```bash
npm install --save-dev likec4@1.59.2
```
Global install (`npm i -g likec4`) works but is not recommended: it drifts from
per-project versions and breaks reproducibility.

One-liner used throughout this skill — takes the installed CLI only if it is
new enough, otherwise the pin:
```bash
LC4="npx -y likec4@1.59.2"
# --version can also print an "Update available" banner — keep the semver line
v="$(likec4 --version 2>/dev/null | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+' | tail -1)"
[ -n "$v" ] && [ "$(printf '%s\n1.53.0\n' "$v" | sort -V | head -1)" = "1.53.0" ] && LC4=likec4
$LC4 validate <dir>
```

If the environment has no network and no cached/installed likec4, fall back to
the self-check below and say so explicitly.

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

### Delivery gate

Both must hold before handing anything over:

```bash
$LC4 validate ./architecture     # exit 0
$LC4 format   ./architecture --check   # exit 0
```

In CI, run the same two commands — `--check` keeps the repo formatted without
the pipeline ever writing to the working tree.

## Reading errors → fixes (catalogue)

Messages below are verbatim from the compiler (verified on 1.59.2).

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

Delivering `.c4` files is half the job; tell the user how to use them:

- **Live preview:** `$LC4 start ./architecture` — local dev server with hot
  reload; keep it running while editing. The **VS Code extension "LikeC4"**
  gives inline previews and language support in the editor.
- **Static site:** `$LC4 build ./architecture -o ./dist` — single deployable
  website with all views (the likec4/template repo shows GitHub Pages setup).
- **Images:** `$LC4 export png ./architecture -o ./images` — PNG per view
  (uses Playwright; the CLI prompts to install it on first run). `export jpg`
  also available.
- **Other formats:** `$LC4 codegen mermaid|d2|dot|plantuml` to embed diagrams
  in READMEs/PRs; `$LC4 export json` for structured data.
- **CI:** run `validate` (and optionally `build`) in the pipeline; official
  LikeC4 GitHub Actions exist for preview/export.

## Final gate

Deliver only when `likec4 validate` exited **0** (or the disclosed self-check
passed). Show the user the file tree, the validation result, and the one
command to view the diagrams (`likec4 start`).
