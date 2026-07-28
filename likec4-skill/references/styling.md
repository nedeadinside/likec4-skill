# Styling — built-in colors, shapes, icons, layout

Styling applies at three levels, each overriding the previous:
1. **Kind** — `style { … }` in `specification` (all elements of a kind).
2. **Element** — nested `style { … }` in `model`/`deployment`.
3. **View** — `style` predicates / `with` overrides inside a view.

Prefer level 1: style the *kind* once, keep elements and views clean.

## Colors — use the built-in theme

Built-in colors: `primary` (default), `secondary`, `muted`, `amber`, `gray`,
`green`, `indigo`, `red`. They adapt to LikeC4's light/dark themes — which is
why this skill does **not** define custom hex colors: hardcoded hex looks
wrong in one of the two themes and adds boilerplate to every project.

C4 color convention via built-ins (baked into the templates' `spec.c4`):

| C4 role | Kind | Color |
| --- | --- | --- |
| In-scope system / container / component | `system`, `container`, `component` | `primary` (default — no style needed) |
| External system | `externalSystem` | `gray` |
| Person | `person` | `indigo` |

One kind = one mechanism. Don't triple-style externals with a tag + element
style + view predicate — the `externalSystem` kind carries it all.

## Shapes

`rectangle` (default), `component`, `storage`, `cylinder`, `browser`,
`mobile`, `person`, `queue`, `bucket`, `document`.

C4 mapping: Person → `person`; System/Container/Component → `rectangle`;
browser SPA → `browser`; mobile app → `mobile`; database → `cylinder` (or
`storage`); message queue/broker → `queue`; blob store → `bucket`.

## Element style properties

```likec4
specification {
  element service {
    style {
      shape rectangle
      color primary
      size medium         // xs|sm|md|lg|xl
      textSize md
      padding md
      opacity 100%        // container/group fill
      border dashed       // dashed|dotted|solid|none
      multiple false      // true = render as a stack of instances
    }
  }
}
```

## Icons

Bundled sets (5,000+ icons): `aws:`, `azure:`, `gcp:`, `tech:`, `bootstrap:` —
or any image URL. `icon` works as a bare property, no `style` block needed.

```likec4
model {
  fn  = container 'Lambda'      { icon aws:lambda }
  pg  = database 'PostgreSQL'   { icon tech:postgresql }
  ui  = component 'UI'          { icon bootstrap:house }
  bare = container 'Plain'      { icon none }   // unset an inherited icon

  tuned = container 'Tuned' {
    icon bootstrap:house       // `icon` is bare …
    style {
      iconColor red            // … but every icon* tweak lives in `style`
      iconSize lg
      iconPosition top
    }
  }
}
```
- Bundled icons (except `bootstrap:`) auto-fill `technology` (e.g.
  `tech:docker` → "Docker") unless you set it explicitly.
- `icon` is the only bare icon property. `iconColor` (affects `bootstrap:*`),
  `iconSize` (xs…xl) and `iconPosition` (`left` default, `right`, `top`,
  `bottom`) are **style properties** — writing them bare is a parse error
  (``Expecting token of type '}' but found `iconSize` ``).
- Icon names are validated: a typo fails with
  `Could not resolve reference to LibIcon named 'X'`. List the valid ones with
  `likec4 list-icons`.

## Relationship styling

```likec4
specification {
  relationship async {
    line dotted        // dashed(default) | solid | dotted
    head vee           // normal(default), onormal, diamond, odiamond,
    tail none          //   crow, vee, open, none
  }
}
```
Defaults: line `dashed`, head `normal`, tail `none`. Multiple relations
between the same pair merge into one edge; render them separately with
`multiple true` on the relationship (in spec or via view `with`).

## Legend / notation (the C4 "key")

C4 requires a key explaining shapes/colors. LikeC4 renders one from
`notation` text on kinds — the templates set it for every kind:

```likec4
specification {
  element externalSystem {
    notation 'External System'
    style { color gray }
  }
}
```

## Layout

```likec4
views {
  view v {
    include *
    autoLayout LeftRight 120 110   // direction, rankSep, nodeSep (optional)
  }
}
```
Directions: `TopBottom` (default), `BottomTop`, `LeftRight`, `RightLeft`.
Context/Landscape usually read well `LeftRight`; Container/Component often
`TopBottom`. For stubborn layouts add `rank same|source|sink { … }`
(`syntax-core.md`).

## Do / don't

- **Do** style kinds once in the spec; keep model elements style-free unless
  an individual element genuinely differs (e.g. `shape browser` on an SPA).
- **Do** give every kind a `notation` so diagrams get a legend.
- **Don't** hardcode hex colors — built-ins are theme-aware.
- **Don't** use more than a handful of colors; color should carry meaning, and
  never be the only carrier (keep explicit kinds/labels for accessibility).
