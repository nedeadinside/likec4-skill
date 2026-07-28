# Level 4 — Code

## When and for whom

The internal structure of a **single component**: its key classes, interfaces, objects, functions, and their collaborations. It maps high-level, coarse-grained components into real-world code elements, bridging what are sometimes seen as two very different worlds: the software architecture and the code. **Audience: technical people within the software development team, specifically software developers.**

Default is still to skip it — this level of detail lives in the code, code-level diagrams decay fastest, and developers can get this detail on demand via their IDEs. Produce Level 4 only when it's explicitly requested or genuinely earns its maintenance cost: a long-lived critical core (domain model, security kernel, pricing engine), a non-obvious design that onboarding keeps stumbling on, an audit/regulatory need to document one mechanism precisely, or as a template when you want to describe a pattern that is used across a codebase.

**Show:** the load-bearing elements only — public interfaces, core classes, key collaborations, and only the selected attributes and methods that are relevant to the narrative you want to create. Aim for ≤ ~10–15 elements.
**Do NOT show:** every class, every field/property/attribute, getters/setters, or framework plumbing — that's what the IDE and the source are for. Resist the temptation to auto-generate unfiltered diagrams from code, which typically results in a huge mess of overlapping boxes and lines.

## Default substitute: link to source

Before modeling code, offer the cheap option — attach source links to the
component; the model stays truthful with zero maintenance:

```likec4
model {
  extend internetBanking.api.security {
    link ../src/security/index.ts#L1-L40 'Source'
  }
}
```

## LikeC4 constructs for this level

LikeC4 has **no built-in UML class diagram** — and no built-in kinds at all —
so Level 4 is just one more nesting level with your own fine-grained kinds.
Declare in `spec.c4` only the kinds you actually use, style them smaller so
the code level reads visually different from components, and give code
relationships their own kinds:

```likec4
specification {
  // Level 4 kinds — declare only what you actually use
  element class {
    notation 'Class'
    style { shape component; size sm; textSize sm }
  }
  element interface {
    notation 'Interface'
    style { shape component; size sm; textSize sm; border dashed }
  }
  relationship implements { line dotted; head onormal }
  relationship inherits   { head onormal }
  relationship calls
}

model {
  extend internetBanking.api.security {
    authnPort = interface 'AuthenticationPort' 'Contract for credential checks'
    tokenSvc = class 'TokenService' 'Issues and verifies JWTs' {
      technology 'Java'
      link ../src/security/TokenService.java#L1-L80 'Source'
    }
    pwdHasher = class 'PasswordHasher' 'BCrypt password hashing' {
      link ../src/security/PasswordHasher.java 'Source'
    }

    tokenSvc -[implements]-> authnPort 'implements'
    tokenSvc -[calls]-> pwdHasher 'verifies hashes via'
  }
}

views {
  view securityCode of internetBanking.api.security {
    title 'Code - Security Component'
    include *
    autoLayout TopBottom
  }
}
```

Wire it into the drill-down chain like every other level — in the Level 3
view: `include internetBanking.api.security with { navigateTo securityCode }`.

## Guidance

- One component per code view; if two components need Level 4, that's two
  views.
- Attach a `link` to **every** code element — the diagram is a map, the
  source stays the single source of truth.
- Name relationship kinds after the code semantics (`implements`, `inherits`,
  `calls`) so the legend explains the arrows.
- Because this level decays fastest, refresh it from the code, not from
  memory — the extraction method in `code-to-diagram.md` applies one level
  down (classes ← modules, interfaces ← exported contracts, `calls` ← direct
  invocations).
- An algorithm's *sequence* is often better told as a dynamic view over these
  code elements (`levels/flows-dynamic.md`) than as a static structure.

## Common errors at this level

- `relationship extends` — **parse error**: `extends` is a DSL keyword
  (`view X extends Y`). Name the kind `inherits`.
- `Could not resolve reference to ElementKind named 'class'` — code kinds are
  custom like all kinds; declare them in `spec.c4` first.
- `Target not resolved` in views/relations — code elements sit deep; use full
  FQNs (`internetBanking.api.security.tokenSvc`).
- `Invalid parent-child relationship` — a class relating to its own component
  (`tokenSvc -> security`). Relate siblings or lift the edge to Level 3.
- Class explosion: mirroring the whole codebase into the model. Cap the view
  at the load-bearing elements and link the rest to source.
