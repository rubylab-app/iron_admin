# IronAdmin Documentation Site

This directory contains the source for the **public IronAdmin documentation site**, a
navigable, searchable web experience built from the Markdown docs that already live in
[`docs/`](../). It is published to **GitHub Pages** at
<https://rubylab-app.github.io/iron_admin/>.

> **Status: live.** Installation, Quick Start, and the Resource DSL guide are fully
> migrated; the other pages are stubs that link to their source Markdown in the repo
> (mostly under [`docs/`](../)). See [Open work](#open-work).

---

## Tooling choice: Jekyll + `just-the-docs`

We recommend **[Jekyll](https://jekyllrb.com/)** with the
**[`just-the-docs`](https://just-the-docs.com/)** theme, deployed to GitHub Pages via a
GitHub Actions workflow.

### Why this is the right default for IronAdmin

| Criterion | Why Jekyll + just-the-docs wins |
|-----------|---------------------------------|
| **Ruby-friendly** | IronAdmin is a Ruby gem. Jekyll is Ruby. Contributors already have a Ruby toolchain and `bundle install` muscle memory. No Node.js, npm, or a second language runtime to maintain. |
| **Native GitHub Pages** | Jekyll is the *only* static generator GitHub Pages builds natively, and even with a custom Actions build it is the best-supported path. Zero third-party hosting. |
| **Low maintenance** | The docs are already Markdown with front-matter-free bodies. Migration is mostly adding a small YAML front matter block. No build config churn. |
| **Built-in search** | `just-the-docs` ships a client-side search index out of the box (`search_enabled: true`) — no external service (Algolia, etc.) to provision or pay for. |
| **Navigation** | Automatic sidebar nav from `nav_order` / `parent` front matter, breadcrumbs, and child-page grouping — matches the existing `docs/` folder hierarchy almost 1:1. |
| **Cost** | Free. GitHub Pages hosting + Actions minutes for public repos are free. |
| **Versioning** | See [Doc versioning](#doc-versioning) below. |

### Alternatives considered

- **MkDocs Material** — Excellent theme and search, but it is a **Python** toolchain.
  That adds a second language runtime to a Ruby project and splits contributor tooling.
  Rejected for that reason alone; the theme quality does not outweigh the ecosystem
  mismatch.
- **Docusaurus** — Powerful, great versioning, but it is a **React/Node.js** app. Heaviest
  maintenance burden (npm dependency churn, build complexity) and the furthest from a
  gem's natural toolchain. Overkill for a docs site of this size.
- **Plain GitHub `docs/` rendering** — What we have today. No search, no navigation, no
  landing page, not a "site". This is exactly what the roadmap item asks us to move beyond.

**Recommendation: Jekyll + just-the-docs.** It is the lowest-friction, lowest-cost,
most Ruby-native option that still delivers search, navigation, and a polished landing page.

---

## Local development

```bash
cd docs/site
bundle install
bundle exec jekyll serve --livereload
# open http://127.0.0.1:4000/iron_admin/
```

Requires Ruby >= 3.3. CI builds the site on the Ruby 3.4 series, the same series as the
repo's `.ruby-version` (3.4.9), using this directory's own `Gemfile.lock`.

## Structure

```
docs/site/
├── _config.yml            # Jekyll + just-the-docs configuration
├── Gemfile                # jekyll + just-the-docs (pinned)
├── index.md               # Landing page
├── assets/images/
│   └── demo-dashboard.png # Demo screenshot, also shown by the repository README.md
├── getting-started/
│   ├── index.md           # Section landing
│   ├── installation.md    # ✅ migrated (real content)
│   └── quick-start.md     # ✅ migrated (real content)
├── guides/
│   ├── index.md           # Section landing
│   ├── resource-dsl.md    # ✅ migrated (real content)
│   ├── dashboards.md      # stub — TODO
│   ├── fields.md          # stub — TODO
│   ├── theming.md         # stub — TODO
│   └── components.md      # stub — TODO
├── adapters.md            # stub — TODO
├── authorization.md       # stub — TODO
├── imports-exports.md     # stub — TODO
├── tools.md               # stub — TODO
├── reference.md           # stub — TODO
├── upgrade-guide.md       # stub — TODO
└── faq.md                 # stub — TODO
```

### Content source of truth

Every stub page lists the exact source file under [`docs/`](../) whose content should be
migrated into it. The migration is mechanical: copy the body, add front matter
(`title`, `parent`, `nav_order`), and fix relative links to point at site URLs.

Three pages are **already fully migrated** to validate the pipeline end to end:
Installation, Quick Start, and the Resource DSL guide.

## Doc versioning

Two viable approaches, to decide before the first `1.0`:

1. **Latest-only (recommended to start).** The site tracks `main`. Simple, matches most
   gems. Older versions remain readable via the git tag on GitHub and RubyGems.
2. **Multi-version.** `just-the-docs` supports a version dropdown via the
   [multiple-docs-sets pattern](https://just-the-docs.com/) or by building each release
   tag into a versioned subpath (`/iron_admin/v0.6/`). Adds Actions complexity; defer
   until there are breaking-change versions users must pin docs to.

## Deploy

[`.github/workflows/docs.yml`](../../.github/workflows/docs.yml) builds the site (without
deploying) on pull requests that touch `docs/` or the workflow itself, and deploys it to
GitHub Pages only when a maintainer runs it manually (`workflow_dispatch`) on `main`.
GitHub Pages is enabled with **Source: GitHub Actions**.

To publish documentation changes after they merge to `main`:

```bash
gh workflow run docs.yml --ref main
```

Adding a `push` trigger on `main` would make deploys automatic; that is still a maintainer
decision (see below).

---

## Open work

- [x] Tooling choice: Jekyll + just-the-docs (merged in #112).
- [x] GitHub Pages enabled (Source = GitHub Actions); live at https://rubylab-app.github.io/iron_admin/.
- [x] URL: project page `rubylab-app.github.io/iron_admin` (`url` / `baseurl` in `_config.yml`).
- [ ] Decide whether `docs.yml` should also deploy on `push` to `main` (currently manual-only).
- [ ] Decide the versioning strategy (latest-only vs. multi-version).
- [ ] Migrate the remaining stub pages from `docs/` (tracked as TODOs in each stub).
