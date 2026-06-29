# Releasing IronAdmin

Publishing to RubyGems is **gated on a GitHub Release**. Pushing a bare git tag
does **not** publish anything — only *publishing a GitHub Release* triggers
[`.github/workflows/release.yml`](.github/workflows/release.yml), which then:

1. runs the test suite (`rspec`) and the linter (`rubocop`),
2. builds `iron_admin-X.Y.Z.gem`,
3. pushes it to RubyGems via **trusted publishing** (OIDC — no API key or secret
   is stored anywhere; GitHub Actions proves its identity to RubyGems and
   RubyGems, configured to trust this repo's `release.yml`, accepts the push),
4. records a **green deployment** to the `release` environment.

## How a release happens

### 1. Prepare the release PR (never commit to `main` directly)

On a feature branch:

- Bump `lib/iron_admin/version.rb` to the new version (e.g. `0.7.0`). Run
  `bundle install` so `Gemfile.lock` picks up the new version.
- In `CHANGELOG.md`: move the `[Unreleased]` entries under a new
  `## [0.7.0] - YYYY-MM-DD` heading, reopen an empty `[Unreleased]`, and add the
  `[0.7.0]: .../compare/v0.6.0...v0.7.0` reference link at the bottom.
- If there are breaking changes, update `UPGRADING.md`.

Open the PR, let CI and the Copilot review pass, then merge to `main`.

> The gem version comes from `version.rb`, **not** from the tag name. Make sure
> they match before publishing the Release. (A mismatch is exactly what broke the
> first 0.6.0 attempt: the tag said `v0.6.0` but `version.rb` still said `0.5.0`,
> so CI rebuilt `0.5.0` and RubyGems rejected the duplicate.)

### 2. Publish the GitHub Release — this is the deliberate "go"

From an up-to-date `main` (with `version.rb` already at the new version):

```bash
gh release create v0.7.0 \
  --target main \
  --title v0.7.0 \
  --notes-file <(awk '/^## \[0\.7\.0\]/{f=1;next} f&&/^## \[/{exit} f' CHANGELOG.md) \
  --latest
```

The `awk` snippet pulls the `## [0.7.0]` section out of `CHANGELOG.md` for the
release notes. You can also do this from the GitHub UI:
**Releases → Draft a new release → tag `v0.7.0` → paste notes → Publish**.

Publishing the Release creates the tag and fires `release.yml`. The gem is
published automatically a minute later, and the `release` deployment turns green.

## Notes & gotchas

- **Never run `rake release` locally** — it would `gem push` a second time.
- A bare `git push origin v0.7.0` will **not** publish. Only a *published*
  GitHub Release does.
- **No secrets needed.** Publishing authenticates from GitHub Actions to RubyGems
  via OIDC trusted publishing.
- One-time setup to verify (see the release PR for details): the RubyGems trusted
  publisher's *Environment* field must be blank or exactly `release`, and the
  GitHub `release` environment must have no blocking protection rules.
