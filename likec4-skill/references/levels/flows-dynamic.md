# Data flow — dynamic views (scenarios & sequences)

## When and for whom

A dynamic view (or sequence/collaboration diagram) shows one use case, user story, or data flow as an **ordered** set of interactions between existing model elements (people, software systems, containers, or components), without changing the model. Use it whenever order matters — login, checkout, payment, data pipeline — instead of trying to encode temporal order into a static Container/Component view. 

**Audience: developers, analysts.** Recommended for significant or complex scenarios where the execution path is not evident by reading the code, such as complex authentication handshaking, asynchronous message flows, or explaining how a low-level design pattern works. It is not practical or mandatory to document every execution path or trivial CRUD systems.

LikeC4 has no separate "DFD" diagram type: data flow = a dynamic view plus well-labelled directed relationships. Two render variants: `diagram` (default) and classic UML `sequence` (`variant sequence`, below).

## Syntax

```likec4 group=banking
views {
  dynamic view signInFlow {
    title 'Scenario - Customer sign in'

    customer -> internetBanking.spa 'submits credentials to'
    internetBanking.spa -> internetBanking.api.signin 'POST /login'
    internetBanking.api.signin -> internetBanking.api.security 'validates credentials using'
    internetBanking.api.security -> internetBanking.db 'checks hashed password in'
    internetBanking.spa <- internetBanking.api.signin 'returns session token to'  // response edge
  }

  dynamic view highlevel {
    title 'Scenario - Overview'
    customer -> internetBanking.spa 'signs in on' { navigateTo signInFlow }   // step-level drill-down
  }
}
```

`A -> B -> C` is shorthand for consecutive steps; `A -> B -> A` means
`A -> B` then `A <- B`. Self-calls (`api -> api 'process'`) are allowed.
Chains only run **forward**: `a <- b <- c` is a parse error
(``Expecting token of type '}' but found `<-` ``) — write returns as separate
`<-` steps. `include cloud, ui` adds non-participating context and sets actor
order for the sequence variant.

Full working file: `templates/full/views/dynamic-flows.c4`.

## Step body — what goes in it, and on which hop

A step takes an optional `{ … }` body with exactly five properties: `title`,
`description`, `technology`, `notes` (Markdown) and `navigateTo`.

```likec4 fixture=flow-steps
web -> api 'POST /payments' {
  technology 'JSON/HTTPS'
  notes '''
    Validates the cart before charging:
    - stock check
    - fraud score
  '''
  navigateTo paymentDetail
}
```

Two constraints, both verified on the pinned version:

- **No `metadata` on a step.** Unlike a model relationship, a step body rejects
  it: ``Expecting token of type '}' but found `metadata` ``. Put the metadata on
  the underlying model relationship instead.
- **`navigateTo` from a step only accepts a `dynamic view`.** Pointing it at a
  regular view fails with `Could not resolve reference to DynamicView named
  'X'` — drill down from a flow into another flow, and use `navigateTo` in a
  static view (`syntax-core.md`) to reach static views.

In a chain the body binds to the **hop it follows**, not to the whole chain —
attach it to the hop it actually describes:

```likec4 fixture=flow-steps
customer -> web
  -> api {
    technology 'HTTPS'
    navigateTo paymentDetail
  }
```

## Flow-control blocks

`parallel` is not a special case — it is one of a family of blocks. Every block
takes an **optional title** right after the keyword, then a `{ … }` body of
steps, and renders as a frame in the sequence variant.

| Block | Keyword(s) | Meaning |
| --- | --- | --- |
| Concurrency | `parallel` / `par` | steps run at the same time |
| Optional | `opt` | steps that may be skipped ("if" without "else") |
| Loop | `loop` | steps that repeat (retries, polling) |
| Interrupt | `break` | leaves the enclosing flow, typically a `loop` |
| Alternatives | `alt` | container of mutually exclusive branches |
| Branch | `when` / `if` / `else` | one branch **inside** `alt` (`if` = alias of `when`) |
| Error handling | `try` / `catch` / `finally` | happy path plus failure handling |

This is the answer to "show the retry", "show what happens when the payment is
declined", "show the error path" — reach for a block **before** splitting the
scenario into several views.

```likec4 fixture=flow-steps
customer -> web 'submits payment on'
web -> api 'POST /payments'

alt 'payment authorization' {
  when 'within limit' {
    api -> payments 'charges the card via'
    api <- payments 'returns an authorization code'
  }
  else 'over limit' {
    api -> web 'rejects the payment'
  }
}

opt 'if the customer opted in' {
  api -> auth 'requests a confirmation from'
}

loop 'until the bank answers' {
  payments -> bank 'polls the transfer status of'
  break 'when settled' {
    payments -> api 'reports settlement to'
  }
}

try 'persist the result' {
  api -> db 'writes the payment to'
} catch 'write failed' {
  api -> web 'shows an error on'
} finally {
  api -> api 'releases the connection'
}
```

### Three nesting rules (each one is a compiler error, verbatim on the pinned version)

1. **`parallel` cannot contain `parallel`** — `Nested parallel blocks are not
   allowed`. Everything concurrent goes in **one** `parallel` block. A
   `parallel` may still sit inside `opt` / `loop` / `try` / a branch.
2. **`when` / `if` / `else` only inside `alt`** — anywhere else:
   `"when" alternative branch must be inside "alt"`.
3. **Only branches may be direct children of `alt`** — a `loop` (or `opt`,
   `parallel`, `try`) written straight into `alt` fails with `"loop" can not be
   used as an alternative branch, only "if", "when" or "else" are allowed`.
   Put it **inside** a `when` / `else` branch.

`try` → `catch?` → `finally?` is a fixed order; `catch` without a preceding
`try` is a parse error. Apart from rule 1, blocks nest to any depth:

```likec4 fixture=flow-steps
loop 'until synced' {
  try {
    alt {
      when 'online' {
        web -> api 'syncs changes with'
      }
      else 'offline' {
        opt {
          web -> web 'queues the change locally'
        }
      }
    }
  } finally {
    web <- api 'acknowledges'
  }
}
```

## `variant sequence` — UML sequence rendering

```likec4 fixture=flow-views
views {
  dynamic view checkoutSequence {
    variant sequence            // lifelines top-to-bottom instead of a flow diagram
    title 'Scenario - Checkout'

    customer -> web 'clicks pay on'
    web -> api 'POST /checkout'
    api -> payments 'charges the card via'
    api <- payments 'returns an authorization code'   // `<-` = return, dashed lifeline
    web <- api 'returns 200 OK'
    customer <- web 'shows confirmation to'
  }
}
```

- `variant sequence` is a **view property**, so it goes before the first step,
  next to `title`. After a step it is a parse error.
- Returns are `<-` steps; do **not** fake them with a forward arrow pointing
  back — the sequence variant draws `<-` as a return message.
- The order actors first appear sets the lifeline order; `include` extra
  elements to place non-participants.
- Same model, same steps: the variant only changes rendering. Use it when the
  user asks for a *sequence diagram* specifically.

## Two rules that prevent broken/noisy flows (verified on the pinned version)

1. **One inline label per step.** Unlike model relationships, a dynamic step does **not** take inline description/technology fields: `spa -> api 'POST /login' 'JSON/HTTPS'` fails with `Expecting token of type '}' but found ''JSON/HTTPS''`. However, interactions should still explicitly identify the communication mechanism (e.g., REST, Java Message Service), communication style (e.g., synchronous, asynchronous), protocols, and port numbers. Put these details into the label text—ideally using or ending with a preposition to clarify direction, such as `'reads from and writes to via JDBC, port 9001'`—or into the step body (`technology`, `notes`).
2. **Step through leaf elements, and use FQNs.** Steps to/from a compound element (a container that has components) make the sequence variant warn `Sequence view does not support nested actors` — target the leaf instead (`internetBanking.api.signin`, not `internetBanking.api`). And inside any view, bare nested names may not resolve — write the FQN; only top-level elements are safe bare.

## Common errors

- `Target not resolved` — bare nested name in a step; use FQN.
- Ambiguous unlabelled lines — a collection of boxes connected by blank lines. Always annotate interactions with their purpose.
- Inconsistent directionality — even though most relationships are bi-directional (a request followed by a response), choose the most significant direction (typically initiator to receiver) and represent that as a uni-directional line. 
- A step between elements with no counterpart relationship in the model is legal, but if the flow reveals a real dependency, add it to the model too so static views stay truthful.
- Splitting one scenario across views only because it has a branch — use `alt` /
  `opt` / `try`. Split into separate views (linked with `navigateTo`) when the
  flow is genuinely long, not when it merely has a condition.
