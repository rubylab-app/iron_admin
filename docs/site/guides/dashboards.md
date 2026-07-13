---
title: Dashboards
parent: Guides
nav_order: 2
permalink: /guides/dashboards/
---

# Dashboards
{: .no_toc }

{: .warning }
> **This page is a stub.** Migrate the content from
> [`docs/guides/dashboard.md`](https://github.com/rubylab-app/iron_admin/blob/main/docs/guides/dashboard.md).
> **TODO:** copy the body, add front matter, and fix relative links to site URLs.

Configure metrics, charts, and recent-record widgets for the `/admin` dashboard.

```ruby
class AdminDashboard < IronAdmin::Dashboard
  metric(:total_users, format: :number) { User.count }
  recent :users, limit: 5
end
```
