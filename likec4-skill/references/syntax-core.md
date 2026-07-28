# LikeC4 DSL — core syntax (cross-cutting)

Verified against **likec4 1.59.2** — every snippet in this file was compiled
with `likec4 validate` on that version. Level-specific constructs live in
`levels/` (dynamic views → `levels/flows-dynamic.md`, deployment →
`levels/deployment.md`). Authoritative upstream docs: https://likec4.dev/dsl/ —
consult only if something here doesn't cover the case; never invent keywords.

## File basics

- Source files end in `.c4` or `.likec4`. **All files under a project folder
  are recursively merged into a single model** — order across files does not
  matter, and no configuration file is required.
- Comments: `// line` and `/* block */`.
- **Separators:** `;` separates *properties* inside `style { … }` and inside a
  view body (`view v { title 'T'; include * }`). It does **not** separate
  element declarations in a `model` block — `system s1 { component api;
  component frontend }` fails with
  ``Expecting token of type '}' but found `;` ``. Put each element on its own
  line.
- Strings: single or double quotes; escape with backslash (`'Cloud\'s'`).
  Triple quotes (`'''…'''`) allow multi-line Markdown.
- Top-level blocks: `specification`, `model`, `views`, `deployment`, `global`.
  A file needs at least one; several blocks of the same type may exist, but
  keep the layout from SKILL.md (spec in one file, model apart from views).

## specification — your notation

**There are no built-in element kinds.** Every kind used in the model must be
declared here first, or compilation fails with
`Could not resolve reference to ElementKind`. Built-in are only the theme
*colors* and *shapes* (see `styling.md`) — which is why the templates need no
custom colors.

```likec4
specification {
  element person {
    notation 'Person'                  // legend text
    style { shape person; color indigo }
  }
  element system                       // color primary is the default
  element externalSystem {
    notation 'External System'
    style { color gray }               // one kind = one styling mechanism
  }
  element container
  element component
  element database { style { shape cylinder } }
  element queue    { style { shape queue } }

  relationship async { line dotted }   // relationship kinds add semantics + style

  deploymentNode environment           // deployment kinds also live here
}
```

Also supported, but **not used by this skill's templates** (built-ins cover
C4): `tag <name>` declarations (usable as `#name` for filtering/styling — must
be declared before use) and `color <name> <hex>` custom colors (3/6/8-hex or
`rgb()/rgba()`). Reach for them only if the user's existing project already
relies on them.

## model — elements

An element needs a **kind** and a **name**. Two equivalent forms:

```likec4
model {
  person customer          // kind-first
  customer = person        // name-first (with '=')
}
```

Names: letters, digits, `-`, `_`; cannot start with a digit or contain `.`;
must be unique within their parent.

### Element properties

```likec4
model {
  // Inlined: <name> = <kind> [title] [description] [technology]
  saas = system 'SaaS' 'Provides services to customers' 'Spring Boot'

  // Nested form — NOTE: tags (if used) MUST come first in the block
  api = container {
    #internal                                 // tags first, before other props
    title 'API Application'
    description 'Serves the JSON/HTTPS API'   // shown in details panel
    summary 'Serves the API'                  // short; shown on the diagram
    technology 'Java, Spring Boot'
    link https://repo 'Repository'            // multiple links allowed
    link ../src/api.ts#L1-L20                 // relative source link
    metadata {
      owner 'platform-team'
      regions ['us-east-1', 'eu-west-1']
    }
    style { color indigo }
  }
}
```
(The snippet above assumes `tag internal` is declared in the specification.
Putting a `#tag` after `title`/`description` is a compile error:
`Expecting token of type '}' but found '#'`.)

Markdown in `description`/`summary` via triple quotes:
```likec4
model {
  web = container {
    description '''
      ### Web Application
      Provides services via the [web](https://example.com).
    '''
  }
}
```

### Nesting & fully qualified names (FQN)

Any element can contain others; the parent name prefixes the child.
```likec4
model {
  system cloud {
    container backend {
      component api
    }
    container frontend
  }
}
// FQNs: cloud, cloud.backend, cloud.backend.api, cloud.frontend
```

## model — relationships

Defined with `->`. Give every relationship a label; for container/component
edges also state the protocol/technology.

```likec4
model {
  customer -> frontend 'opens in browser'

  // kinded relationship (two syntaxes)
  system1 -[async]-> system2 'notifies'
  system1 .async system2

  // nested: use `it` / `this` for the parent; or omit the source entirely
  person customer {
    -> frontend 'opens'        // same as: customer -> frontend
    frontend -> this 'notifies'
  }
}
```

Inline order is `[title] [description] [technology]`:
```likec4
model {
  spa -> api 'requests data' 'SPA calls the backend' 'JSON/HTTPS'

  spa -> billing 'requests invoices' {
    technology 'gRPC'
    link https://repo 'Repo'
    navigateTo billingFlow              // drill-down to a dynamic view
    metadata { protocol 'grpc' }
    style { color amber; line solid }
  }
}
```

**Parent–child rule (common error):** a relationship may not connect an
element to its own ancestor/descendant. `api -> backend` where `api` is nested
inside `backend` fails with `Invalid parent-child relationship`. Relate
siblings, or lift the edge to the right level.

## References — scope, hoisting, FQN

Lexical scope with hoisting (like JavaScript): every `{ … }` opens a scope; a
name that stays unique "bubbles" up.

```likec4
model {
  system s1 {
    component api
    component frontend
  }
  system s2 {
    component api
  }

  // frontend -> api 'calls'   ⛔ ambiguous: two `api` in scope
  frontend -> s1.api 'calls'   // ✅ FQN
}
```
Prefer FQNs whenever a bare name could become ambiguous after refactoring —
and **always in views** (see the note in `levels/flows-dynamic.md`).

## extend — split the model across files

`extend` enriches an element defined elsewhere; the target must be an **FQN**.
The extension inherits the parent's scope, so sibling references work.

```likec4
// landscape.c4
model { cloud = system 'Cloud System' }

// cloud-service2.c4
model {
  extend cloud {
    service2 = container 'Service 2'
    service2 -> service1 'calls'   // service1 defined in another extend of cloud
  }
}
```
`extend` can also add links/metadata (and tags) to an existing element. Deeper
targets work too: `extend cloud.backend { … }`.

## views — projections of the model

Views are computed from the model; model changes propagate automatically.
Properties (`title`, `description`, `link`) must precede predicates.

```likec4
views {
  view index {                    // `index` is the default landing view
    title 'System Context'
    include *
    autoLayout LeftRight
  }
}
```

### Scoped views — `view of <element>`
Inherits the element's scope and becomes its default drill-down target:
```likec4
views {
  view of cloud.backend {
    title 'Components - Backend'
    include api                   // resolves to cloud.backend.api
  }
}
```

### Extending views
```likec4
views {
  view base { title 'Base'; include * }
  view detail extends base {
    title 'More detail'
    include cloud.backend
  }
}
```

## View predicates — what is visible

Order matters; `exclude` only removes what an earlier `include` added.

```likec4
view {
  include backend                 // element + its relations to visible ones
  include broker.*                // children
  include broker.**               // descendants IF related to visible
  include cloud._                 // expand: element + related children only
  include *                       // top-level (unscoped) / element+children (scoped)
  exclude broker.emailsQueue
}
```

Relationship predicates:
```likec4
view {
  include customer -> cloud       // directed
  include customer <-> cloud      // any direction
  include -> backend              // incoming to visible
  include cloud.* ->              // outgoing from visible
}
```

Filter with `where` (fields: `kind`, `tag`, `source.*`, `target.*`,
`metadata.*`; operators `is`/`==`, `is not`/`!=`, `and`, `or`, `not`):
```likec4
view {
  include cloud.* where kind is container
  include -> backend where target.kind is database
  exclude * where kind is externalSystem
}
```

Override rendering with `with` (`where` must come **before** `with`; `with`
needs known endpoints for relationships — `a -> b`, not open `cloud.* ->`):
```likec4
view {
  include cloud.backend with {
    title 'Backend'
    navigateTo backendComponents   // custom drill-down
  }
  include api -> db with { color red; line solid }
}
```

### Groups (visual boundaries)
```likec4
view {
  group 'Frontend' {
    color amber; opacity 20%; border solid
    include frontend.*
  }
}
```

### Style predicates
```likec4
view {
  include *
  style * { opacity 10% }
  style spa, mobileApp { color secondary }
  style element.kind = externalSystem { color muted }
}
```

### Layout & rank
```likec4
view {
  include *
  autoLayout LeftRight 120 110    // direction [rankSep] [nodeSep]
  // directions: TopBottom (default), BottomTop, LeftRight, RightLeft
  rank source { customer }        // push to start
  rank same   { api, billingApi } // align on one level
  rank sink   { analytics }       // push to end
}
```

### Shared styles & predicates across views
`global { style name * { … } }` + `global style name` inside a view; likewise
`global { predicateGroup name { include … } }` + `global predicate name`.

### Organizing the view list
Use `/` in a `title`, or a common folder on the block:
```likec4
views 'Banking / IB' {
  view v1 { title 'Landscape'; include * }   // → Banking / IB / Landscape
}
```

## Quick keyword index

| Need | Keyword |
| --- | --- |
| Declare a kind | `element` / `relationship` / `deploymentNode` |
| Create element | `kind name` or `name = kind` |
| Relationship | `->`, `-[kind]->`, `.kind` |
| Parent ref in nesting | `it` / `this` |
| Add to existing element | `extend <FQN>` |
| Projection | `view` / `view of` / `dynamic view` / `deployment view` |
| Select | `include` / `exclude` / `*` / `.*` / `.**` / `._` |
| Filter / override | `where` / `with` |
| Boundary | `group` |
| Layout | `autoLayout` / `rank` |
| Drill-down | `navigateTo` |
| Deploy logical element | `instanceOf` (see `levels/deployment.md`) |
