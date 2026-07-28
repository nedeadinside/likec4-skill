# Data flow — dynamic views (scenarios & sequences)

## When and for whom

A dynamic view (or sequence/collaboration diagram) shows one use case, user story, or data flow as an **ordered** set of interactions between existing model elements (people, software systems, containers, or components), without changing the model. Use it whenever order matters — login, checkout, payment, data pipeline — instead of trying to encode temporal order into a static Container/Component view. 

**Audience: developers, analysts.** Recommended for significant or complex scenarios where the execution path is not evident by reading the code, such as complex authentication handshaking, asynchronous message flows, or explaining how a low-level design pattern works. It is not practical or mandatory to document every execution path or trivial CRUD systems.

LikeC4 has no separate "DFD" diagram type: data flow = a dynamic view plus well-labelled directed relationships. Two render variants: `diagram` (default) and classic `sequence` (switchable in the UI).

## Syntax

```likec4
views {
  dynamic view signInFlow {
    title 'Scenario - Customer sign in'

    customer -> internetBanking.spa 'submits credentials to'
    internetBanking.spa -> internetBanking.api.signin 'POST /login'
    internetBanking.api.signin -> internetBanking.api.security 'validates credentials using'
    internetBanking.api.security -> internetBanking.db 'checks hashed password in'
    internetBanking.spa <- internetBanking.api.signin 'returns session token to'  // response edge
  }

  dynamic view checkout {
    title 'Scenario - Checkout'
    user -> app.ui 'clicks pay on'
    app.ui -> app.api 'POST /checkout' {
      notes 'Validates the cart before charging'   // Markdown supported
    }
    parallel {                                     // concurrent steps (no nesting)
      app.api -> app.db 'saves order to'
      app.api -> ext 'creates charge using'
    }
    app.ui <- app.api 'shows confirmation to'
  }

  dynamic view highlevel {
    ui -> api 'requests' { navigateTo checkout }   // step-level drill-down
  }
}
```

`A -> B -> C` is shorthand for consecutive steps; `A -> B -> A` means
`A -> B` then `A <- B`. Self-calls (`api -> api 'process'`) are allowed.
`include cloud, ui` adds non-participating context and sets actor order for
the sequence variant.

Full working file: `templates/full/views/dynamic-flows.c4`.

## Two rules that prevent broken/noisy flows (verified on 1.59.2)

1. **One inline label per step.** Unlike model relationships, a dynamic step does **not** take inline description/technology fields: `spa -> api 'POST /login' 'JSON/HTTPS'` fails with `Expecting token of type '}' but found ''JSON/HTTPS''`. However, interactions should still explicitly identify the communication mechanism (e.g., REST, Java Message Service), communication style (e.g., synchronous, asynchronous), protocols, and port numbers. Put these details into the label text—ideally using or ending with a preposition to clarify direction, such as `'reads from and writes to via JDBC, port 9001'`—or detail them in a nested `{ notes '...' }`.
2. **Step through leaf elements, and use FQNs.** Steps to/from a compound element (a container that has components) make the sequence variant warn `Sequence view does not support nested actors` — target the leaf instead (`internetBanking.api.signin`, not `internetBanking.api`). And inside any view, bare nested names may not resolve — write the FQN; only top-level elements are safe bare.

## Common errors

- `Target not resolved` — bare nested name in a step; use FQN.
- Ambiguous unlabelled lines — a collection of boxes connected by blank lines. Always annotate interactions with their purpose.
- Inconsistent directionality — even though most relationships are bi-directional (a request followed by a response), choose the most significant direction (typically initiator to receiver) and represent that as a uni-directional line. 
- A step between elements with no counterpart relationship in the model is legal, but if the flow reveals a real dependency, add it to the model too so static views stay truthful.
- Cramming alternatives/branches into one flow — make one dynamic view per scenario (happy path, failure path) and link them with `navigateTo`.
