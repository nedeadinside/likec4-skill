# Snippet fixtures

Surrounding model for documentation fragments, used by `scripts/check-snippets.sh`
only. Doc snippets stay short and illustrative; the model they need in order to
compile lives here instead of being repeated in every reference file.

- **fixture** — a template with a `%%` hole. A block tagged
  ` ```likec4 fixture=NAME ` is compiled inside it.
- **prelude** — extra sources merged into a cross-file group. A block tagged
  ` ```likec4 group=NAME ` joins that project.

Everything below is inside HTML comments, so it renders as nothing.

<!-- likec4-fixture: kinds
specification {
  element person
  element system
  element externalSystem
  element container
  element component
  element database
  element queue
  relationship async
  deploymentNode environment
  tag internal
}
%%
-->

<!-- likec4-fixture: stubs
specification {
  element person
  element system
  element container
  relationship async
}
model {
  container frontend
  system system1
  system system2
  container spa
  container api
  container billing
}
views {
  dynamic view billingFlow {
    spa -> billing 'requests invoices'
  }
}
%%
-->

<!-- likec4-fixture: extend-target
specification {
  element system
  element container
}
%%
model {
  extend cloud {
    service1 = container 'Service 1'
  }
}
-->

<!-- likec4-fixture: world
specification {
  element person
  element system
  element externalSystem
  element container
  element component
  element database
  element queue
}
model {
  customer = person 'Customer'
  cloud = system 'Cloud' {
    frontend = container 'Frontend' {
      web = component 'Web UI'
    }
    backend = container 'Backend' {
      api = component 'API'
      billingApi = component 'Billing API'
      analytics = component 'Analytics'
    }
    db = database 'Database'
  }
  broker = system 'Broker' {
    emailsQueue = queue 'E-mails'
  }
  spa = container 'SPA'
  mobileApp = container 'Mobile App'
  ext = externalSystem 'External System'

  customer -> spa 'uses'
  spa -> api 'calls'
  api -> db 'reads from'
  api -> billingApi 'calls'
  billingApi -> ext 'charges via'
  api -> emailsQueue 'publishes to'
}
%%
-->

<!-- likec4-fixture: view
specification {
  element person
  element system
  element externalSystem
  element container
  element component
  element database
  element queue
}
model {
  customer = person 'Customer'
  cloud = system 'Cloud' {
    frontend = container 'Frontend' {
      web = component 'Web UI'
    }
    backend = container 'Backend' {
      api = component 'API'
      billingApi = component 'Billing API'
      analytics = component 'Analytics'
    }
    db = database 'Database'
  }
  broker = system 'Broker' {
    emailsQueue = queue 'E-mails'
  }
  spa = container 'SPA'
  mobileApp = container 'Mobile App'
  ext = externalSystem 'External System'

  customer -> spa 'uses'
  spa -> api 'calls'
  api -> db 'reads from'
  api -> billingApi 'calls'
  billingApi -> ext 'charges via'
  api -> emailsQueue 'publishes to'
}
views {
  view backendComponents of cloud.backend {
    include *
  }
%%
}
-->

<!-- likec4-fixture: pred
specification {
  element system
  element container
  element component
  element database
  tag primary
  tag deprecated
  relationship http
}
model {
  cloud = system 'Cloud' {
    api = container 'API' {
      #primary
      metadata {
        region 'eu'
        regions ['eu', 'us']
        critical true
        owner 'platform'
      }
      handler = component 'Handler'
    }
    db = database 'Database' {
      metadata { region 'us' }
    }
    ui = container 'UI'
  }
  ext = container 'External'

  ui -> api 'calls'
  api -[http]-> db 'reads from' {
    metadata { protocol 'grpc' }
  }
  api -> ext 'calls'
}
views {
  view v {
%%
  }
}
-->

<!-- likec4-fixture: flow-views
specification {
  element person
  element system
  element container
  element database
}
model {
  customer = person 'Customer'
  web = container 'Web App'
  api = container 'API'
  db = database 'Database'
  auth = container 'Auth Service'
  payments = container 'Payment Service'
  bank = system 'Bank'
  cache = container 'Cache'

  customer -> web 'uses'
  web -> api 'calls'
  api -> db 'reads from'
  api -> auth 'authenticates via'
  api -> payments 'charges via'
  payments -> bank 'authorizes with'
  api -> cache 'caches in'
}
views {
  dynamic view paymentDetail {
    customer -> web 'opens the payment page on'
  }
}
%%
-->

<!-- likec4-fixture: flow-steps
specification {
  element person
  element system
  element container
  element database
}
model {
  customer = person 'Customer'
  web = container 'Web App'
  api = container 'API'
  db = database 'Database'
  auth = container 'Auth Service'
  payments = container 'Payment Service'
  bank = system 'Bank'
  cache = container 'Cache'

  customer -> web 'uses'
  web -> api 'calls'
  api -> db 'reads from'
  api -> auth 'authenticates via'
  api -> payments 'charges via'
  payments -> bank 'authorizes with'
  api -> cache 'caches in'
}
views {
  dynamic view paymentDetail {
    customer -> web 'opens the payment page on'
  }
  dynamic view flow {
%%
  }
}
-->

<!-- likec4-prelude: banking
specification {
  element person
  element system
  element externalSystem
  element container
  element component
  element database
  element queue
  relationship async
}
-->
