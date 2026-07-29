# View predicates — selecting, filtering, overriding

Everything inside a view body that decides *what is on the diagram*. Verified
against the pinned LikeC4 version; every snippet here is compiled by
`scripts/check-snippets.sh`.

A view is built by accumulation: predicates run **in order**, `include` adds to
the accumulated result, `exclude` removes from it. `exclude` can only remove
what an earlier `include` already added — an `exclude` on line 1 does nothing.

## Anatomy

```
EXPRESSION          ::= WILDCARD | ELEMENT_EXPRESSION | RELATIONSHIP_EXPRESSION
FILTER_PREDICATE    ::= EXPRESSION where FILTER_CONDITIONS
CUSTOMIZE_PREDICATE ::= (EXPRESSION | FILTER_PREDICATE) with { … }
```

Read left to right: **select** → `where` **filter** → `with` **override**.
That is also the required order — `with` before `where` is a syntax error, and
`with` is only allowed on `include`.

```likec4 fixture=pred
include *                                  // wildcard
include cloud.api                          // element expression
include cloud.ui -> cloud.api              // relationship expression
include * where kind is container          // + filter
include cloud.db with { color amber }      // + override
include
  cloud.*
  where kind is container and tag is #primary
  with { color red }
```

## Element expressions — the four suffixes

| Written | Selects |
| --- | --- |
| `cloud` | that element, plus its relationships to what is already visible |
| `cloud.api` | that one named child |
| `cloud.*` | **direct children only**, plus their relationships to what is visible |
| `cloud._` | direct children that **have a relationship** with what is visible |
| `cloud.**` | **all descendants**, recursively, that have a relationship with what is visible |

`_` and `**` are *suffixes*, never predicates of their own — bare `include **`
and `exclude _` do not parse:

```likec4 invalid fixture=pred
include **
```

```likec4 invalid fixture=pred
include *
exclude _
```

(``Expecting token of type '}' but found `*` `` and
`unexpected character: ->_<-` respectively. Write `include cloud.**` /
`exclude cloud._`.)

### `*` depends on the view's scope

- **Unscoped** `view v { … }` — `*` is every top-level element and the
  relationships between them.
- **Scoped** `view v of cloud { … }` — `*` is `cloud` itself, its direct
  children, and their relationships.

That single difference explains most "why is my diagram empty / why is
everything here" surprises.

## Relationship expressions

| Written | Selects |
| --- | --- |
| `a -> b` | relationships from `a` to `b` (each side may be any element expression) |
| `a <-> b` | relationships between `a` and `b` in **either** direction |
| `-> b` | anything incoming to `b` from what is already visible |
| `a ->` | anything outgoing from `a` to what is already visible |
| `-> b ->` | anything between `b` and what is already visible, either way |
| `* -> *` | every relationship |

A relationship expression pulls in its endpoints, so `include api -> db` is
enough to draw both boxes and the edge.

```likec4 fixture=pred
include cloud.ui -> cloud.api
include cloud.api <-> cloud.db
include -> ext
include * -> *
```

## `where` — filter conditions

Operators: `is` / `==`, `is not` / `!=`, `and`, `or`, `not`, parentheses.

| Filter | Example |
| --- | --- |
| Tag | `* where tag is #primary` |
| Kind | `* where kind is not container` |
| Metadata value | `* where metadata.region is "eu"` |
| Metadata **key absent** | `* where not metadata.owner` |
| Metadata array contains | `* where metadata.regions is "eu"` |
| Metadata boolean | `* where metadata.critical is true` |
| Relationship kind/tag | `* -> * where kind is http` |
| Relationship metadata | `* -> * where metadata.protocol is "grpc"` |
| Endpoint of a relationship | `* -> * where source.tag is #primary`, `… where target.kind is database` |
| Endpoint metadata | `* -> * where target.metadata.region is "us"` |

```likec4 fixture=pred
include * where metadata.region is "eu"
include cloud.* where not metadata.owner
include * -> * where source.tag is #primary and target.kind is database
exclude * where tag is #deprecated
```

Metadata values are compared as **strings** — quote them (`"eu"`), except
booleans (`true` / `false`). An array-valued key matches when it *contains* the
value. `source.` / `target.` prefixes only mean something on a relationship
expression.

This is the machinery behind requests like "show only the EU services", "hide
everything without an owner", "only the gRPC calls" — none of which need a
second model.

## `with` — per-view overrides

`with { }` changes how the selected things render **in this view only**:
`title`, `description`, `technology`, `color`, `shape`, `border`, `opacity`,
`icon`, `line`, `head`, `tail`, `navigateTo`, `multiple`.

```likec4 fixture=pred
include *
include cloud.api with {
  title 'API (public)'
  color green
  navigateTo v
}
include cloud.api -> cloud.db with {
  color red
  line solid
}
```

Two constraints:

- **`where` comes before `with`.**
- On a relationship, `with` needs both endpoints known — `include cloud.* ->
  with { … }` (open-ended) is rejected. Name the target.
- In a **deployment view** `with { }` compiles and renders an **empty view** —
  use a `style` predicate there instead (`levels/deployment.md`).

## Reusing predicates across views

```likec4 fixture=kinds
global {
  predicateGroup shared {
    include *
    exclude * where tag is #internal
  }
}
views {
  view a {
    global predicate shared
  }
  view b {
    global predicate shared
    include *
  }
}
```

The declaration keyword is **`predicateGroup`** (plural block) — `global {
predicate name { … } }` is a parse error (``Expecting token of type '}' but
found `predicate` ``). Inside a view the *usage* is singular: `global predicate
shared`. Styles work the same way (`styling.md`): `global { styleGroup … }` and
`global { style … }`, used as `global style …`.

## Ordering rules, in one place

1. View properties (`title`, `description`, `link`, `variant`) come **before**
   any predicate.
2. Predicates apply in written order; `exclude` only removes what is already in.
3. `where` before `with`.
4. `style` predicates come after the `include`/`exclude` that put the elements
   there.
