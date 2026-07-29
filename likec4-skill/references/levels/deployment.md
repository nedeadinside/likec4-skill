# Deployment — physical topology

## When and for whom

Maps logical software systems and containers onto infrastructure: environments, zones, nodes, instances. Produce it when "where does it run?" matters — replication, failover, clustering, DMZ vs internal network, cloud topology, and per-environment differences. This is a required diagram that helps solve the question of where the software will be deployed.
**Audience: software developers, infrastructure architects, and operational/support staff.** The logical model stays clean: deployment *references* it, never redefines it.

## LikeC4 constructs for this level

Three parts: `deploymentNode` kinds (declared in the project's single
`spec.c4`, like all kinds), a `deployment { … }` block with the node
hierarchy, and a `deployment view`.

```likec4 group=banking
// spec.c4 (excerpt)
specification {
  deploymentNode environment
  deploymentNode zone
  deploymentNode server { style { icon tech:docker } }
}

// deployment/prod.c4
deployment {
  environment prod 'Production' {
    zone dmz 'DMZ' {
      web1 = server 'Web Server' {
        instanceOf internetBanking.spa    // deploy a logical container
        instanceOf internetBanking.api
      }
    }
    zone internal 'Internal Network' {
      dbPrimary = server 'DB Primary' { instanceOf internetBanking.db }
      dbStandby = server 'DB Standby' { db2 = instanceOf internetBanking.db }
    }
    // deployment-only relationship between two instances of the same element
    dbPrimary -> dbStandby 'replicates to'
  }
}

// views/dynamic-flows.c4 (or its own file)
views {
  deployment view prodDeployment {
    title 'Deployment - Production'
    include prod.**
    autoLayout LeftRight
  }
}
```

Full working files: `templates/full/spec.c4` (node kinds),
`templates/full/deployment/prod.c4`, view in
`templates/full/views/dynamic-flows.c4`.

## Guidance

- `instanceOf` targets are **FQNs of logical elements**; instances inherit the
  element's relationships and style, and may override
  title/technology/icon/style.
- Name an instance (`db2 = instanceOf …`) when the same element is deployed
  more than once and you need to reference a specific instance.
- Deployment nodes can represent physical infrastructure (servers, devices), virtualised infrastructure (IaaS, PaaS, VMs), containerised infrastructure (Docker containers), or execution environments (database servers, web servers). They can be nested to reflect reality.
- Include infrastructure nodes such as DNS services, routers, load balancers, and firewalls if they help tell the story.
- Annotate relationships between instances with their purpose, communication mechanism, style (e.g., synchronous, asynchronous), protocols, and port numbers. Directionality should consistently represent dependency or data flow.
- Indicate the runtime status of instances (e.g., active, passive, hot-standby, cold-standby), instance counts, scaling limits, IP addresses, VPCs, or VLANs where necessary.
- Deployment nodes can be `extend`ed by FQN like logical elements — one file
  per environment scales well (`deployment/prod.c4`, `deployment/staging.c4`).
- `include prod.**` shows the whole hierarchy; add `includeAncestors true` to
  force ancestors of filtered nodes to render.

## Filtering a deployment view — how tags and metadata resolve

An instance is not a copy of the logical element; the two are merged, and tags
and metadata merge by **different rules**. measured on the pinned version:

| Property | Rule |
| --- | --- |
| `kind` | the instance takes the logical element's kind |
| tags | **cumulative** — the instance matches its own tags *and* the logical element's |
| metadata | **replaced wholesale** — if the instance declares any `metadata`, the logical element's is not visible at all; with none, the logical metadata is the fallback |
| parent nodes | tags of enclosing deployment nodes are **not** inherited by instances |

```likec4 group=banking
views {
  deployment view prodEu {
    title 'Deployment - EU only'
    include prod.** where not metadata.retired
    autoLayout LeftRight
  }
}
```

The consequence that bites: adding one metadata key to an instance to record,
say, its port silently drops every filter that matched the logical element's
metadata. Either repeat the logical keys on the instance or keep instance
metadata empty.

## Styling a deployment view — local `style` only

This is the one place in LikeC4 where `likec4 validate` exits **0 on a broken
result**. `with { … }` on a deployment-view predicate compiles, reports
`✓ Valid`, and renders **zero nodes** — measured on the pinned version via `export json`:

| Need | Write | Never |
| --- | --- | --- |
| Colour/shape inside one deployment view | `style` predicate in the view | `include … with { … }` — valid, **empty view** |
| Colour/shape everywhere | `style { … }` on the `deploymentNode` kind in `spec.c4` | `global style` inside the view — parse error |

```likec4 group=banking
views {
  deployment view prodStyled {
    title 'Deployment - Production (styled)'
    include prod.**
    style * {
      color green
    }
    style prod.dmz.web1 {
      color amber
    }
  }
}
```

Because the failure is invisible to the gate, check the node count after
styling a deployment view — `$LC4 export json <dir> --outfile out.json
--skip-layout` and confirm the view is not empty.

## Common errors

- Declaring `deploymentNode` kinds inside `deployment/*.c4` — kinds belong in
  `spec.c4`; keep the specification in one file.
- `instanceOf` pointing at a non-existent FQN → `Target not resolved`; the
  logical element must exist in `model/`.
- Modeling deployment concerns as logical containers (a "Kubernetes"
  container) — infrastructure lives here, not in Level 2.
