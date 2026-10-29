---
title: Theming
parent: Guides
nav_order: 4
permalink: /guides/theming/
---

# Theming
{: .no_toc }

{: .warning }
> **This page is a stub.** Migrate the content from
> [`docs/guides/theming.md`](https://github.com/rubylab-app/iron_admin/blob/main/docs/guides/theming.md).
> **TODO:** copy the body, add front matter, fix links. Also cross-link the
> [Theme Properties reference]({% link reference.md %}).

Every page is drawn from a theme. The default one, Neutral, is a minimal light look; change
its properties with `config.theme`, register more themes with `config.register_theme`, and
people pick one from the theme switcher in the navbar (or `config.theme_resolver` picks it per
request). Every color, font, radius and shadow is a Tailwind class.
