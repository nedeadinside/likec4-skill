# Project configuration & multi-project workspaces

Every option and behaviour below was exercised against the pinned LikeC4 version.

## Do you need a config file at all?

**No — for a single project.** `likec4 validate ./architecture` works on a bare
directory with no config; every `.c4` under it merges into one model. That is
what this skill's templates assume, and it stays true.

**Yes — as soon as one of these is true:**

| Need | Why the config is required |
| --- | --- |
| Two or more independent models in one repo | the config file is what *draws the boundary* between them |
| `import { … } from 'other-project'` | `from` takes a **project name**, which only a config can declare |
| Sharing `.c4` files from outside the folder | `include.paths` |
| Custom theme colors, default styles, landing page | nowhere else to put them |
| `likec4 gen <custom>` generators | defined in a `.ts`/`.js` config |

## The file

Recognized names, any one of them:

| Format | Names |
| --- | --- |
| JSON / JSON5 | `likec4.config.json`, `.likec4.config.json`, `.likec4rc` |
| JavaScript | `likec4.config.js`, `likec4.config.mjs` |
| TypeScript | `likec4.config.ts`, `likec4.config.mts` |

```json
{
  "$schema": "https://likec4.dev/schemas/config.json",
  "name": "internet-banking",
  "title": "Internet Banking Architecture"
}
```

`name` is the only required option. It must be unique in the workspace, must
not be `default`, and cannot contain `.`, `@` or `#`. Keep `$schema` — it is
what gives the user's editor completion and validation on the file.

**Scope rule:** a `.c4` file belongs to the project of the **nearest config file
up the directory tree**. So the config's location, not its content, decides
which files are in the model.

## Options

| Option | Type | Default | What it does |
| --- | --- | --- | --- |
| `name` | string | — | project id (required) |
| `title` | string | `name` | human-readable title |
| `contactPerson` | string | — | maintainer shown in the UI |
| `metadata` | object | — | arbitrary project-level key/values |
| `include.paths` | string[] | — | extra directories to scan for `.c4` |
| `include.maxDepth` | number | `3` | scan depth for those paths (1–20) |
| `include.fileThreshold` | number | `30` | guard on how many files those paths may pull in |
| `exclude` | string[] | `["**/node_modules/**"]` | picomatch globs to skip |
| `implicitViews` | boolean | `false` | auto-generate a scoped view per element |
| `inferTechnologyFromIcon` | boolean | `true` | `icon tech:docker` → `technology 'Docker'` |
| `imageAliases` | object | `{"@": "./images"}` | shortcuts for image paths |
| `manualLayouts.outDir` | string | `".likec4"` | where manual layout data is stored |
| `styles.theme.colors` | object | — | override the built-in color tokens |
| `styles.defaults` | object | — | default `border`/`opacity`/`size`, and `relationship` defaults |
| `extends` | string \| string[] | — | inherit style config from other JSON configs |
| `landingPage` | object | — | `{ "redirect": true }`, or `include`/`exclude` view ids |
| `generators` | object | — | custom generators (`.ts`/`.js` config only), run via `likec4 gen <name>` |

`implicitViews: true` is worth knowing about: it gives drill-down for free on a
large model. It is *not* a substitute for the explicit `view of` +
`navigateTo` chain the quality bar asks for on the levels you actually deliver.

## The config is never part of the gate

`likec4 validate` checks the **model**, not the config. Measured on the pinned
version, all of these exit **0**:

| What you wrote | What happens |
| --- | --- |
| a misspelled option (`implicitViewz`) | silently ignored, no message at all |
| an illegal `name` (e.g. `"default"`) | `Failed to register project config` is *logged*, the file is dropped, and the directory is validated as an unconfigured project |
| malformed JSON | same — the config is skipped, validation proceeds |
| `-p <name-that-does-not-exist>` | validates everything anyway and exits 0 |

The second row is the dangerous one: in a multi-project workspace a rejected
config means that project loses its boundary and its name, so `import … from
'<name>'` stops resolving and files start merging into the default project —
while the exit code stays green.

So: after writing or editing a config, **read the project lines the CLI prints**
rather than the exit code. `validate` logs one `add '<name>'` per registered
project and then `loaded N projects` — if your project is missing from that
list, or `N` is smaller than the number of config files, a config was dropped.
And keep `$schema`: with the CLI this permissive, the editor is the only thing
that will catch a typo in an option name.

## Multi-project workspace

```
workspace/
├── platform/
│   ├── likec4.config.json      { "name": "platform" }
│   └── platform.c4
├── banking/
│   ├── likec4.config.json      { "name": "banking" }
│   ├── model.c4
│   └── views.c4
└── payments/
    ├── likec4.config.json      { "name": "payments" }
    └── model.c4
```

`likec4 validate ./workspace` validates **all** projects in one run; `-p
banking` narrows it to one. The same `-p` flag exists on `format`, `export`,
`build` and `start`.

## `import` — crossing a project boundary

`platform/platform.c4`, in the project whose config says `"name": "platform"`:

```likec4 group=import-demo project=platform
specification {
  element system
}
model {
  auth = system 'Auth Platform'
}
```

`banking/model.c4`, in the project whose config says `"name": "banking"`:

```likec4 group=import-demo project=banking
import { auth } from 'platform'

specification {
  element container
}
model {
  api = container 'API'
  api -> auth 'authenticates with'
}
```

- `from` takes the **project name** from the other project's config —
  **not a file path**. `from './platform.c4'` fails with
  `Imported project not found`.
- Both projects need a config with `name`.
- Imported elements are referenced like local ones, but belong to the other
  project: extend them there, not here.

Use imports for genuinely separate models that reference each other (one team's
platform used by another team's system). Inside one model, `extend` across
files is the right tool and needs no config at all (`syntax-core.md`).
