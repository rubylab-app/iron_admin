---
title: Upgrade Guide
nav_order: 9
permalink: /upgrade-guide/
---

# Upgrade Guide
{: .no_toc }

{: .warning }
> **This page is a stub.** Migrate the content from the repo-root
> [`UPGRADING.md`](https://github.com/rubylab-app/iron_admin/blob/main/UPGRADING.md).
> **TODO:** copy the body, add front matter, fix links. Also link the
> [`CHANGELOG.md`](https://github.com/rubylab-app/iron_admin/blob/main/CHANGELOG.md)
> for the full release history.

Version-by-version upgrade notes and breaking changes.

## Upgrading to 0.7.0

IronAdmin 0.7.0 requires **Ruby >= 3.3** and **Rails >= 8.0.4**, raises several
dependency floors (for example `pagy >= 43.7.1, < 44` and `view_component >= 4.0, < 5`),
and closes authorization gaps, so some requests that used to succeed now return `403`
or `404`. Read the 0.7.0 section at the top of
[`UPGRADING.md`](https://github.com/rubylab-app/iron_admin/blob/main/UPGRADING.md)
before you run `bundle update iron_admin`.
