# Plugin / Community Extension System — Design Proposal

> Status: **Design proposal + proof-of-concept skeleton.** The registration
> core and two-and-a-half extension points are implemented and tested; the
> remaining extension points are specified here but not yet built. This
> document is the contract a maintainer should approve before the feature is
> completed.
>
> ⚠️ **Stability: EXPERIMENTAL / unstable until 1.0.** The public surface
> described here (`IronAdmin.register_plugin`, `IronAdmin::Plugin`,
> `Plugin::Registration`, `MenuItem`/`MenuRegistry`) is **not** covered by the
> project's zero-breaking-changes invariant and may change or be removed
> before general availability. It becomes semver-governed only when the plugin
> system reaches GA (targeted for 1.0).

## 1. Philosophy — what a plugin is (and is not)

IronAdmin is already, quietly, an extensible system. Resources and tools
self-register via an `inherited` hook, dashboards self-register, field types
register through `IronAdmin.register_field_type`, components are swappable
through `config.components`, and adapters resolve through a registry. Host
applications extend IronAdmin every day just by dropping files into
`app/iron_admin/`.

A **plugin** is the packaging of those same extension points into a
**redistributable Rails gem** so that *one* author can ship a coherent bundle
of admin functionality that *many* host apps install with a single line.

**A plugin IS:**

- A normal Rails gem that `require`s IronAdmin and calls a small, stable
  registration API.
- A bundle of one or more extensions: resources, dashboards, tools, field
  types, adapters, component overrides, and custom menu entries.
- Versioned and declared-compatible against an IronAdmin version range.
- Activated **explicitly** by the host (`IronAdmin.register_plugin`) — the host
  keeps an auditable list of everything extending its admin panel.

**A plugin IS NOT:**

- A sandbox or a security boundary. A plugin is arbitrary Ruby loaded into the
  host process with full application privileges (see §6). Installing a plugin
  is exactly as much a trust decision as adding any gem to the `Gemfile`.
- A runtime-togglable module. Plugins are wired at boot, not enabled/disabled
  per request.
- A replacement for the existing `app/iron_admin/` convention. Host-owned
  resources still live there; plugins are for *shareable, cross-app* bundles.

### Design principle: a facade, not raw registries

Plugins never touch `ResourceRegistry`, `ToolRegistry`, `FieldTypeRegistry`,
`Configuration`, etc. directly. They receive a **`Registration` facade**
(§4) whose surface is the public plugin API. Internal registries can be
refactored freely as long as the facade holds. This is the single most
important architectural commitment in this proposal.

## 2. Extension points

The table maps each extension point to the existing IronAdmin mechanism it
builds on, and its status in this proposal.

| Extension point   | Underlying mechanism today                          | Status in skeleton |
|-------------------|-----------------------------------------------------|--------------------|
| Menu items        | *(new)* — sidebar was resource/tool-derived only    | **Implemented**    |
| Component override | `config.components.<slot> = Klass`                  | **Implemented**    |
| Field types       | `FieldTypeRegistry.register` / `register_field_type`| **Implemented**    |
| Resources         | `inherited` → `ResourceRegistry`, Zeitwerk `push_dir`| Design only        |
| Dashboards        | `inherited` → `IronAdmin.dashboard_class`           | Design only        |
| Tools             | `inherited` → `ToolRegistry`                         | Design only        |
| Adapters          | `Adapters::Registry::ADAPTERS` (currently frozen)   | Design only        |
| Action / lifecycle hooks | `config.on_action`                           | Design only        |

### 2a. Resources, dashboards, tools (via load paths)

These classes already self-register on load. The only thing a plugin must do
is get its class files onto the host's Zeitwerk autoload/eager-load set with
the `IronAdmin` namespace — exactly what `engine.rb` already does for the
host's own `app/iron_admin` directory:

```ruby
Rails.autoloaders.main.push_dir(resource_path, namespace: IronAdmin)
```

**Proposed mechanism:** a plugin exposes a load path and IronAdmin pushes it
during the `:set_autoload_paths`/`to_prepare` cycle:

```ruby
setup do |admin|
  admin.load_path File.expand_path("../../app/iron_admin", __dir__)
end
```

The directory follows the same layout as a host (`resources/`, `dashboards/`),
so `MyPlugin::…` files defining `IronAdmin::Resources::FooResource` land in the
registry through the existing `inherited` hook — **no new registration code for
the resource itself.** This is why load-path contribution, not per-class
registration, is the right abstraction here.

**Open question for the maintainer:** eager-load ordering. Plugin dirs must be
pushed *before* the engine's `to_prepare` eager-loads and calls
`ResourceRegistry.finalize!`. This requires the host to `register_plugin`
during engine initialization (an initializer that runs before
`iron_admin.autoload`), which is a tighter ordering contract than the "call it
anywhere" model the PoC uses for the config-level extension points. See §5.

### 2b. Component overrides — **implemented**

Delegates to `IronAdmin::Configuration::Components`. Any existing slot
(`:table`, `:form`, `:navbar`, `:sidebar`, `:shell`, `:search`, `:filter_bar`)
can be swapped:

```ruby
setup { |admin| admin.component :navbar, MyPlugin::NavbarComponent }
```

### 2c. Field types — **implemented**

Delegates to `FieldTypeRegistry` with the same block DSL as
`IronAdmin.register_field_type`:

```ruby
setup do |admin|
  admin.field_type(:color) do
    display { |record, field| record.public_send(field.name) }
  end
end
```

### 2d. Menu items — **implemented (new capability)**

Before this proposal the sidebar could only render entries *derived from*
registered resources and tools. Plugins frequently need to surface a page that
is **not** a CRUD resource (a report, an external dashboard, a separately
mounted engine). `MenuItem` + `MenuRegistry` add that as a first-class, small
value object:

```ruby
setup do |admin|
  admin.menu_item label: "Reports", path: "/admin/reports",
                  icon: "chart-bar", group: "Analytics", priority: 20
end
```

Items de-duplicate by `group + label + path`, so the idempotent re-activation
on every `to_prepare` (development reloads) never produces duplicate entries.
Wiring `MenuRegistry.grouped`/`.sorted` into `SidebarComponent` is a small,
deliberately-deferred follow-up (see §7).

### 2e. Adapters (design only)

`Adapters::Registry::ADAPTERS` is currently a **frozen** hash, and
`adapter_class` already accepts a class object directly — so a plugin *can*
ship an adapter today by pointing a resource at its class. To make adapters
first-class and referenceable by symbol (`self.adapter_class = :elasticsearch`)
the frozen hash must become a mutable registry:

```ruby
setup { |admin| admin.adapter :elasticsearch, MyPlugin::ElasticsearchAdapter }
```

This is deferred because it requires converting `Adapters::Registry` from a
constant lookup to a registration API and re-verifying the lazy-require
behaviour that keeps ActiveRecord and Mongoid code mutually exclusive.

### 2f. Lifecycle / action hooks (design only)

`config.on_action` today supports a **single** block. A plugin needs to
*subscribe* without clobbering the host's block or another plugin's. Proposed:
promote `on_action` to a list of subscribers and expose
`admin.on_action { |action, resource, record, user| … }`. Deferred because it
changes the semantics of an existing public config method (a backward-compat
concern the maintainer should rule on).

## 3. Packaging model

A plugin is an ordinary gem. Recommended layout:

```
iron_admin_reports/
├── iron_admin_reports.gemspec        # depends on "iron_admin", ">= 0.6"
├── lib/
│   ├── iron_admin_reports.rb         # requires the plugin + engine
│   └── iron_admin_reports/
│       ├── plugin.rb                 # < IronAdmin::Plugin
│       ├── engine.rb                 # optional: assets, routes, mount points
│       └── navbar_component.rb
└── app/
    └── iron_admin/                   # follows host convention; Zeitwerk-mapped
        ├── resources/…
        └── dashboards/…
```

- The gemspec declares `spec.add_dependency "iron_admin", ">= 0.6", "< 2.0"` —
  this is the coarse gate; the `requires_iron_admin` declaration (§5) is the
  runtime-checked fine gate.
- If the plugin ships its own routes/assets/mount points it includes a nested
  `Rails::Engine`, orthogonal to the IronAdmin plugin object.
- **The host stays in control:** adding the gem to the `Gemfile` loads the
  code; nothing activates until the host calls `IronAdmin.register_plugin`. A
  plugin gem must document that one line rather than auto-activating on
  `require`, so hosts can audit and order activation.

## 4. Registration API

Two entry points:

```ruby
# Host initializer — config/initializers/iron_admin.rb
require "iron_admin_reports"
IronAdmin.register_plugin(IronAdminReports::Plugin)
```

```ruby
# The plugin, in the gem
module IronAdminReports
  class Plugin < IronAdmin::Plugin
    plugin_name       "iron_admin_reports"
    plugin_version    "1.2.0"
    requires_iron_admin ">= 0.6", "< 2.0"

    setup do |admin|                       # `admin` is a Plugin::Registration
      admin.menu_item label: "Reports", path: "/admin/reports",
                      icon: "chart-bar", group: "Analytics", priority: 20
      admin.component :navbar, IronAdminReports::NavbarComponent
      admin.field_type(:currency) do
        display { |record, field| record.public_send(field.name) }
      end
      # admin.load_path "…/app/iron_admin"   # (planned — §2a)
      # admin.adapter :elasticsearch, …       # (planned — §2e)
    end
  end
end
```

Class hierarchy:

- **`IronAdmin::Plugin`** — base class. Declarative metadata
  (`plugin_name`, `plugin_version`, `requires_iron_admin`) + a single `setup`
  block. `activate!` checks compatibility then runs the block against a fresh
  `Registration`.
- **`IronAdmin::Plugin::Registration`** — the facade (§1). The *only* surface
  plugin authors are promised stability on.
- **`IronAdmin::PluginRegistry`** — stores activated plugin classes, keyed by
  `plugin_name` (idempotent). `register` validates + activates; `activate_all!`
  re-activates all (called from the engine on every `to_prepare`).
- **`IronAdmin.register_plugin`** — the one host-facing entry point,
  delegating to `PluginRegistry.register`.

Why **explicit** registration rather than `inherited` auto-registration (which
resources/tools use)? Two reasons: (1) determinism — the host controls
activation order, which matters for load-path contribution (§2a); (2)
auditability — a plugin is a bigger trust decision than a resource, so making
the host name it explicitly is a feature, not friction.

## 5. Versioning & compatibility

- Each plugin declares `requires_iron_admin` using standard RubyGems
  requirement syntax. At `activate!`, IronAdmin checks it against
  `IronAdmin::VERSION` and raises `IronAdmin::IncompatiblePluginError` if
  unsatisfied — a **loud, early** failure at boot rather than a mysterious
  `NoMethodError` deep in a request.
- IronAdmin should treat the `Registration` facade as **semver-governed public
  API**: additive changes are minor bumps; removing/renaming a facade method is
  a major bump. The facade's `requires_iron_admin` upper bound (`< 2.0`) is how
  a plugin protects itself against a future breaking major.
- **Activation ordering contract:** config-level extension points (component,
  field type, menu item) can be registered any time after IronAdmin loads.
  Load-path contribution (§2a) must happen during engine init. The maintainer
  should decide whether to support both timings or require all plugins to
  register in a dedicated `iron_admin.plugins` initializer.

## 6. Security & isolation

**There is no isolation, by design, and this must be documented prominently.**
A plugin is arbitrary Ruby with full host privileges: it can read any model,
issue any query, override the entire UI shell, and reach any secret the host
process holds. The threat model is identical to any other gem in the `Gemfile`.

Recommended posture:

- **Trust before install.** Document that plugins are not sandboxed. Encourage
  hosts to vet plugin source and pin exact versions.
- **Explicit activation** (§4) is the mitigation that exists: nothing runs
  until the host names it.
- **Fail-safe activation.** Consider (future) wrapping each plugin's `activate!`
  so one broken plugin logs and is skipped rather than taking down boot —
  mirroring how `ResourceRegistry.finalize!` already isolates per-resource
  failures. The PoC currently lets activation errors propagate (fail-loud),
  which is the safer default until the maintainer chooses a policy.
- **No privilege reduction is promised.** If per-plugin capability scoping is
  ever wanted, it is a separate, much larger project and out of scope here.

## 7. End-to-end example (fictional third-party plugin)

`iron_admin_stripe` — surfaces Stripe data in the admin panel.

```ruby
# lib/iron_admin_stripe/plugin.rb
module IronAdminStripe
  class Plugin < IronAdmin::Plugin
    plugin_name       "iron_admin_stripe"
    plugin_version    "0.3.0"
    requires_iron_admin ">= 0.6", "< 2.0"

    setup do |admin|
      # A read-only "Payments" report page the plugin's own engine mounts.
      admin.menu_item label: "Payments", path: "/admin/stripe/payments",
                      icon: "credit-card", group: "Billing", priority: 15

      # A money renderer reused across the plugin's resources.
      admin.field_type(:money) do
        display { |record, field| "$%.2f" % (record.public_send(field.name).to_i / 100.0) }
      end

      # A branded navbar for the billing section.
      admin.component :navbar, IronAdminStripe::NavbarComponent

      # (planned) ship CRUD resources for cached Stripe objects:
      # admin.load_path File.expand_path("../../app/iron_admin", __dir__)
    end
  end
end
```

```ruby
# Host app: config/initializers/iron_admin.rb
require "iron_admin_stripe"

IronAdmin.configure do |config|
  config.title = "Acme Admin"
end

IronAdmin.register_plugin(IronAdminStripe::Plugin)
```

On boot: compatibility is checked against `0.6.0` → passes; the `:money` field
type is registered; the navbar is overridden; and a "Payments" entry appears
under a "Billing" group in the sidebar. If Acme later upgrades to IronAdmin
`2.1`, the plugin refuses to activate with a clear
`IncompatiblePluginError` until `iron_admin_stripe` ships a compatible release.

## 8. What is implemented vs. deferred

**Implemented (this PR):**

- `IronAdmin::Plugin` base class (metadata DSL, `setup`, compatibility check,
  `activate!`).
- `IronAdmin::Plugin::Registration` facade with `menu_item`, `component`,
  `field_type`.
- `IronAdmin::PluginRegistry` (idempotent register/activate, `activate_all!`).
- `IronAdmin.register_plugin` host entry point.
- `IronAdmin::MenuItem` + `IronAdmin::MenuRegistry` (new sidebar extension
  point).
- `PluginError` / `IncompatiblePluginError`.
- Engine re-activates plugins on `to_prepare`.
- Full BetterSpecs coverage for the above.

**Deferred (needs maintainer sign-off before building):**

- `#load_path` — Zeitwerk dir contribution for resources/dashboards/tools, plus
  the activation-ordering contract (§2a, §5).
- `#adapter` — de-freeze `Adapters::Registry` into a mutable registry (§2e).
- `#on_action` — multi-subscriber lifecycle hooks (§2f).
- Rendering `MenuRegistry` entries in `SidebarComponent` (§2d).
- Fail-safe (isolated) activation policy (§6).
- Generators (`rails g iron_admin:plugin`) and published authoring guide.

## 9. Decisions the maintainer must approve

1. **Facade-as-contract**: commit to `Plugin::Registration` as the semver-
   governed plugin API; internal registries stay private.
2. **Explicit activation** over `inherited` auto-registration for plugins.
3. **New `MenuItem`/`MenuRegistry`** as the sidebar extension point (vs.
   forcing every nav entry through a resource/tool).
4. **Activation timing / ordering** model for load-path contribution (§5).
5. **Security posture**: ship "no isolation, trust-on-install" as documented
   policy; decide fail-loud vs. fail-safe activation.
6. **`on_action` compatibility**: whether to convert the single-block config
   hook into a multi-subscriber list.
```
