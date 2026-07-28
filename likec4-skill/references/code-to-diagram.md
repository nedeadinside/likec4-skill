# Code → diagram — extracting a C4 model from a repository

When handed source code, reverse-engineer the model level by level. Read
structure and configuration, not every line — dependency manifests and infra
config are the highest-signal sources.

## What to look for, per level

### Level 1 — Context (system + externals) → `levels/l1-context.md`
- The repo (or monorepo service) *is* the system in scope. Name it from
  `package.json`/`pom.xml`/README.
- **Actors:** auth config, roles, README "users", public entry routes → persons.
- **External systems:** third-party SDKs and base URLs — Stripe, Twilio,
  SendGrid, S3, Auth0, external REST/GraphQL hosts, OAuth providers. Anything
  called but not owned → the `externalSystem` kind.

### Level 2 — Containers (deployable units + stores) → `levels/l2-container.md`
- **`docker-compose.yml` / k8s manifests / Helm charts** — each service, db,
  cache, broker is usually a container. Single best source.
- **Entry points / `main`** — each runnable process (API server, worker, cron,
  SPA build) is a container.
- **Datastore connections** — `DATABASE_URL`, JDBC URLs, `pg`/`mongoose`/
  `redis` clients → database/cache containers; engine goes in `technology`.
- **Brokers** — Kafka/RabbitMQ/SQS clients → a queue/broker container.
- **Frontend** — a separate SPA/mobile build → its own container
  (`browser`/`mobile` shape).

### Level 3 — Components (inside one container) → `levels/l3-component.md`
Only for a container worth zooming into:
- **Modules/packages/folders** grouping functionality (controllers, services,
  repositories, gateways).
- **DI registrations** (Spring `@Component`/`@Service`, NestJS providers,
  wire-up files) → components.
- **Clients as components** — an HTTP/SDK client class, a repository/DAO, a
  message publisher/consumer each map to a component with one responsibility.

### Relationships — infer from code
| In code | Relationship |
| --- | --- |
| HTTP client (`axios`, `fetch`, `RestTemplate`) to a base URL | → that container/external, label with protocol |
| DB client / ORM (`pg`, `mongoose`, JPA, Prisma) | → database container, label `reads/writes`, tech = driver |
| Broker producer (`kafkajs`, `@KafkaListener`) | → broker, label `publishes/consumes`, `async` kind |
| gRPC / GraphQL client | → target, label with protocol |
| Message consumer / subscriber | broker → this service (incoming) |

Direction follows the call/data flow. Label every edge with *what* and *how*.

## Method (in order)

1. Read manifests: `docker-compose`, k8s, `package.json`/`pom.xml`/`go.mod`, config.
   Draft the **container** list + externals.
2. Locate entry points and datastore/broker/HTTP clients. Draft
   **relationships**.
3. Write `spec.c4` (start from `templates/`) + model + Context and Container
   views. **Validate** (`setup-and-validation.md`).
4. Pick the most important container; read its module/DI structure; add
   **components** + a Component view. Validate.
5. Add a **dynamic view** for a key request flow traceable through the code
   (`levels/flows-dynamic.md`).
6. If infra manifests exist, derive a **deployment view** from compose/k8s
   (`levels/deployment.md`).

## Worked example (Node + Postgres + Kafka + external API)

**What the repo shows**
- `docker-compose.yml`: services `web` (React), `orders` (Node/Express),
  `postgres`, `kafka`.
- `orders/package.json` deps: `express`, `pg`, `kafkajs`, `axios`.
- `orders/src/` modules: `routes/`, `repository/` (pg), `payments/` (axios →
  `https://api.stripe.com`), `events/` (kafkajs producer → topic `orders`).

**Extraction**
- System in scope: **Shop Platform**. Actor: **Customer**. External: **Stripe**.
- Containers: **Web App** (React SPA), **Orders Service** (Node/Express),
  **Orders DB** (Postgres), **Event Bus** (Kafka).
- Components of Orders Service: **HTTP API**, **Order Repository**,
  **Payment Client**, **Event Publisher**.

**Resulting LikeC4** (validated on 1.59.2)

```likec4
// spec.c4 — built-ins only; broker is a project-specific kind
specification {
  element person        { style { shape person; color indigo } }
  element system
  element externalSystem { style { color gray } }
  element container
  element component
  element database      { style { shape cylinder } }
  element broker        { style { shape queue } }
  relationship async    { line dotted }
}
```
```likec4
// model.c4
model {
  customer = person 'Customer' 'Places orders in the shop'

  shop = system 'Shop Platform' {
    web = container 'Web App' 'Storefront SPA' {
      technology 'React'
      style { shape browser }
    }
    orders = container 'Orders Service' 'Handles order lifecycle' {
      technology 'Node.js, Express'

      httpApi = component 'HTTP API' 'REST endpoints for orders' {
        technology 'Express Router'
      }
      orderRepo = component 'Order Repository' 'Persistence for orders' {
        technology 'node-postgres (pg)'
      }
      paymentClient = component 'Payment Client' 'Calls the payment provider' {
        technology 'axios'
      }
      publisher = component 'Event Publisher' 'Emits order events' {
        technology 'kafkajs'
      }

      httpApi -> orderRepo 'reads/writes orders via'
      httpApi -> paymentClient 'charges via'
      httpApi -> publisher 'publishes events via'
    }
    ordersDb = database 'Orders DB' 'Orders and line items' {
      technology 'PostgreSQL'
    }
    kafka = broker 'Event Bus' 'orders topic' {
      technology 'Apache Kafka'
    }
  }

  stripe = externalSystem 'Stripe' 'Payment provider'

  customer -> web 'uses' 'HTTPS'
  web -> orders 'calls' 'JSON/HTTPS'
  orders -> ordersDb 'reads/writes' 'SQL/TCP 5432'
  orders -[async]-> kafka 'publishes order events to' 'Kafka protocol'
  orders -> stripe 'creates charges via' 'REST/HTTPS'
}
```
```likec4
// views.c4
views {
  view index {
    title 'System Context - Shop Platform'
    include *
    autoLayout LeftRight
  }
  view containers of shop {
    title 'Containers - Shop Platform'
    include *
    autoLayout TopBottom
  }
  view ordersComponents of shop.orders {
    title 'Components - Orders Service'
    include *
    autoLayout TopBottom
  }
}
```

**Notes**
- The Postgres/Kafka compose services became a `database` and a `broker`
  container; the compose topology can additionally drive a deployment view.
- The Kafka producer edge uses the `async` kind (dotted) to signal
  fire-and-forget messaging.
- The `axios` call to `api.stripe.com` became an `externalSystem` — not an
  internal container, because you don't own it.
- Component relationships that leave the container (e.g. a repository → the
  db) can be added at component level; LikeC4 derives the container-level edge.
