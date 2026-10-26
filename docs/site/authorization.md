---
title: Authorization
nav_order: 5
permalink: /authorization/
---

# Authentication & Authorization
{: .no_toc }

{: .warning }
> **This page is a stub.** Migrate the content from
> [`docs/guides/authentication.md`](https://github.com/rubylab-app/iron_admin/blob/main/docs/guides/authentication.md).
> **TODO:** copy the body, add front matter, fix links. Cross-link the `policy do … end`
> section of the [Resource DSL guide]({% link guides/resource-dsl.md %}#policies).

Configure who can sign in (`config.authenticate` / `config.current_user`) and the per-resource
`policy` DSL for fine-grained `allow` / `deny` rules. Browser requests that a policy denies, or
that point at a missing record, render a `403` or `404` page inside the admin layout; override it
with `app/views/iron_admin/shared/error.html.haml`.
