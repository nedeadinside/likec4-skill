# Level 1 — System Context (+ System Landscape)

## When and for whom

One software system in scope, surrounded by its users (persons) and the
external systems it talks to. It answers what the system is, who uses it, and how it fits into the existing IT environment. The external systems typically sit outside the boundary of your own system, meaning you do not have responsibility or ownership of them. No internal detail. **Audience: everyone**,
including non-technical stakeholders inside and outside the immediate development team. Produce it almost always — it's the required entry point of the diagram set.

**Show:** the system, actors (individual people, users, roles, or personas), external systems, high-level labelled
relationships, and optionally an enterprise boundary. Every person and software system must include a name and a short description of its role or responsibilities.
**Do NOT show:** containers, components, technologies, protocols, or data formats.

## LikeC4 constructs for this level

Top-level elements in `model/landscape.c4` and `model/externals.c4`, one
unscoped view named `index` (the default landing view):

```likec4 group=banking
// model/landscape.c4
model {
  customer = person 'Personal Banking Customer' 'A customer with personal accounts'
  internetBanking = system 'Internet Banking System' {
    description 'View account information and make payments'
  }
}

// model/externals.c4 — externalSystem kind is gray by spec, nothing to restyle
model {
  mainframe = externalSystem 'Mainframe Banking System' {
    description 'Stores core banking information'
  }
  customer -> internetBanking 'views balances and makes payments using'
  internetBanking -> mainframe 'gets account information from'
}

// views/context.c4
views {
  view index {
    title 'System Context - Internet Banking'
    include *
    autoLayout LeftRight
  }
}
```

Full working files: `templates/full/model/landscape.c4`,
`templates/full/model/externals.c4`, `templates/full/views/context.c4`.

## System Landscape

When several in-scope systems must be shown together (enterprise/portfolio
map), it's just a wider unscoped view over the top-level elements, effectively a System Context diagram without a specific focus on one particular software system. It shows how multiple software systems fit together within the bounds of an enterprise:

```likec4 group=banking
views {
  view landscape {
    title 'System Landscape'
    include *
    autoLayout LeftRight
  }
}
```
If some systems shouldn't appear, `exclude` them or include explicitly. An enterprise boundary (a bounding box) is often used here to illustrate what is internal to the enterprise versus what is external.

## Common errors at this level

- Container detail leaking up: if `include *` in an unscoped view starts
  showing containers, they were declared at top level instead of nested inside
  their system — fix the model, not the view.
- Unlabelled relationships: every edge states *what* happens
  (`'views balances using'`), phrased consistently with its direction. Relationships should be uni-directional lines representing dependency or data flow. The description should help explain the direction of the arrow, often by using or ending with a preposition (e.g., "to", "from"). You should be able to read the relationship out loud as a sentence.
- Missing descriptions: drawing a collection of named boxes without short descriptive statements leaves the diagram open to interpretation and ambiguity.
- Unexplained acronyms: using domain or technical acronyms without defining them in a key or legend.
- Skipping the actor: a context diagram without a `person` usually means the
  system boundary wasn't thought through.
