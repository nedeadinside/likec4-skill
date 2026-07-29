# Level 2 — Container

## When and for whom

Zoom into the one system in scope to show its **containers** — separately runnable/deployable units and data stores (server-side web app, SPA, client-side desktop app, mobile app, server-side console app, microservice, serverless function, database, blob/content store, file system, or shell script). A container represents an execution context or boundary. "Container" is a runtime boundary, **not** a Docker container. **Audience: architects, developers, ops.** This is the baseline picture for a team — produce it whenever the system has any internal structure, to show the overall shape of the software architecture and how responsibilities are distributed.

**Show:** containers, their responsibilities, **technology** on every one,
relationships with protocols, communication styles, and port numbers; keep persons and external systems for context. The view must explicitly show the system boundary enclosing the containers, keeping the people and external software systems outside to provide continuity with Level 1.
**Do NOT show:** components inside containers, classes, or physical instances, failover, and clustering (these belong on a deployment diagram).

## LikeC4 constructs for this level

`extend` keeps each system's internals in its own file; a scoped
`view of <system>` shows the containers and becomes the system's drill-down
target:

```likec4 group=banking
// model/internet-banking.c4
model {
  extend internetBanking {
    spa = container 'Single-Page Application' 'Account info and payments' {
      technology 'JavaScript, Angular'
      style { shape browser }          // browser/mobile/cylinder convey type
    }
    api = container 'API Application' 'Banking features via a JSON/HTTPS API' {
      technology 'Java, Spring Boot'
    }
    db = database 'Database' 'Stores registrations, credentials, logs' {
      technology 'Oracle Database'
    }

    customer -> spa 'views balances and makes payments using'
    spa -> api 'makes API calls to' 'JSON/HTTPS'   // what + how
    api -> db 'reads from and writes to' 'JDBC'
    api -> mainframe 'makes API calls to' 'XML/HTTPS'
  }
}

// views/internet-banking-views.c4
views {
  view containers of internetBanking {
    title 'Containers - Internet Banking System'
    include *
    autoLayout TopBottom

    include internetBanking.api with {
      navigateTo apiComponents         // drill-down to Level 3
    }
  }
}
```

Full working files: `templates/full/model/internet-banking.c4`,
`templates/full/views/internet-banking-views.c4`. For a small system the
3-file `templates/minimal/` already contains this level.

## Guidance

- Every container requires a Name, a Description (a short statement of its responsibilities or the data it stores), and `technology` (the implementation technology) — making high-level technology choices explicit is the point of this level.
- Interactions between containers are typically out-of-process (inter-process). Relationship labels state *what* and *how*: `'makes API calls to'
  'JSON/HTTPS'`. Use a preposition to explain the direction of the arrow, pointing from the initiator to the receiver to show dependency. You may also specify the communication style (e.g., synchronous, asynchronous, batched) and port numbers.
- Sibling relationships live inside the same `extend`; edges to externals
  (`api -> mainframe`) also belong here, at the container level.
- Wire drill-down both ways: `view of <system>` makes the containers view the
  system's default target from Level 1; `navigateTo` on a container links down
  to its Level 3 view.

## Common errors at this level

- `Invalid parent-child relationship`: relating a container to its own system
  (`api -> internetBanking`). Relate siblings or lift the edge to Level 1.
- Duplicating externals inside the system — reference the top-level element
  (it's in scope), don't redeclare it.
- Modeling infrastructure here (load balancers, k8s nodes) — that's the
  deployment layer (`levels/deployment.md`), not a container.
