---
title: Imports & Exports
nav_order: 6
permalink: /imports-exports/
---

# Imports & Exports
{: .no_toc }

{: .warning }
> **This page is a stub.** Migrate the content from
> [`docs/guides/export.md`](https://github.com/rubylab-app/iron_admin/blob/main/docs/guides/export.md)
> and [`docs/guides/imports.md`](https://github.com/rubylab-app/iron_admin/blob/main/docs/guides/imports.md).
> **TODO:** copy the body, add front matter, fix links.

CSV and JSON export out of the box, respecting tenant scope, field visibility, and the
current filters, search and sort. `:password` fields are never exported with their value.
Resources can also opt in to CSV and JSON imports (`imports :csv, :json`) with an upload,
a validated preview, and an import step.
