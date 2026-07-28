# Level 3 — Component

## When and for whom

Zoom into **one** container to show its **components** — groupings of related
functionality behind an interface — and their responsibilities. Components inside a container typically execute in the same process space and are not separately deployable units.
**Audience: architects, developers.** Optional: produce it only for a
container that is non-trivial or critical, not for every container (e.g., omit for data storage containers or simple microservices).

**Show:** components of that one container, their names, responsibilities, and implementation technology. Show how they collaborate and reach out to people, other containers, and software systems to provide context. Draw a bounding box to explicitly show the boundary of the container.
**Do NOT show:** every class; other containers in full detail.

## LikeC4 constructs for this level

Components nest inside their container (directly, or via a deeper
`extend <system>.<container>` when splitting files). The view is scoped to the
container — inside it, references to nested elements should use **FQN**:

```likec4
// inside extend internetBanking { api = container { … } }  — or separately:
model {
  extend internetBanking.api {
    signin = component 'Sign In Controller' 'Allows users to sign in' {
      technology 'Spring MVC Rest Controller'
    }
    security = component 'Security Component' 'Authentication and authorization' {
      technology 'Spring Bean'
    }

    signin -> security 'uses'
    security -> db 'reads from and writes to' 'JDBC'      // sibling scope: db of the system
    security -> mainframe 'makes API calls to' 'XML/HTTPS' // reaching an external
  }
}

views {
  view apiComponents of internetBanking.api {
    title 'Components - API Application'
    include *
    autoLayout TopBottom
  }
}
```

Full working file: `templates/full/model/internet-banking.c4` (components
inline in the `api` container) + `templates/full/views/internet-banking-views.c4`.

## Guidance

- One Level 3 diagram per container — never mix components of two containers
  in one view.
- A component maps to a module/package/DI-registered unit, not a class. Components should be real things, evident in the code through an architecturally-evident coding style (e.g., naming conventions, packaging, or metadata), rather than purely logical constructs. When
  extracting from code, see `code-to-diagram.md`.
- Components may point outward (to the system's database, to externals) — the
  view will pull those endpoints in as context. Include people, software systems, and other containers to help put context around the container you've zoomed in upon.
- Annotate interactions between components with their purpose (e.g., "uses", "persists data using", "delegates to") and communication style (e.g., synchronous, asynchronous).
- For infrastructure components and cross-cutting concerns (like logging), avoid drawing lines from every component to prevent a cluttered diagram. Instead, omit the component if it doesn't add value, write a general note on the diagram, or include the component but use color coding or symbols in the legend to denote the relationship.

## Going deeper — Level 4

Default: don't. Link a component to its source instead. When code-level
structure genuinely needs communicating (or is explicitly requested), see
`levels/l4-code.md` — it covers the source-link substitute, custom code kinds,
and the pitfalls (`extends` is a reserved word, etc.).

## Common errors at this level

- `'X' is ambiguous` / `Target not resolved` in the view: bare nested names —
  use FQN (`internetBanking.api.signin`).
- `Invalid parent-child relationship`: a component relating to its own
  container (`signin -> api`).
- Component sprawl: > ~20 components means the container needs splitting or
  the granularity is too fine (you're drawing classes).
