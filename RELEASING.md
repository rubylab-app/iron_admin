# Releasing IronAdmin

Publishing to RubyGems is **gated on a GitHub Release**. Pushing a bare git tag
does **not** publish anything. Only *publishing a GitHub Release* triggers
[`.github/workflows/release.yml`](.github/workflows/release.yml), which then:

1. checks that the tag is exactly `v` plus the version in `lib/iron_admin/version.rb`,
   before anything else runs,
2. runs the full CI workflow ([`ci.yml`](.github/workflows/ci.yml): Ruby 3.3/3.4/4.0 ×
   Rails 8.0/8.1, minimum dependency versions on Ruby 3.3, RuboCop, gem package check),
3. builds `iron_admin-X.Y.Z.gem` and verifies its contents
   ([`.github/scripts/verify_gem.rb`](.github/scripts/verify_gem.rb)),
4. pushes it to RubyGems via **trusted publishing** (OIDC: no API key or secret
   is stored anywhere; GitHub Actions proves its identity to RubyGems, and
   RubyGems, configured to trust this repo's `release.yml` in the `release`
   environment, accepts the push),
5. records a **green deployment** to the `release` environment.

## How a release happens

### 1. Prepare the release PR (never commit to `main` directly)

On a feature branch:

- Bump `lib/iron_admin/version.rb` to the new version (e.g. `0.7.0`). Run
  `bundle install` with the Ruby from `.ruby-version` so `Gemfile.lock` picks up
  the new version. Leave `BUNDLED WITH` as it is.
- In `CHANGELOG.md`: move the `[Unreleased]` entries under a new
  `## [0.7.0] - YYYY-MM-DD` heading, reopen an empty `[Unreleased]`, and add the
  `[0.7.0]: .../compare/v0.6.0...v0.7.0` reference link at the bottom.
- If there are breaking changes, update `UPGRADING.md`.
- Optionally run the package check CI will run:

  ```bash
  gem build iron_admin.gemspec
  ruby .github/scripts/verify_gem.rb iron_admin-0.7.0.gem 0.7.0
  ```

Open the PR, let the **CI result** check and the Copilot review pass, then merge
to `main`.

> The gem version comes from `version.rb`, **not** from the tag name. Make sure
> they match before publishing the Release. (A mismatch is exactly what broke the
> first 0.6.0 attempt: the tag said `v0.6.0` but `version.rb` still said `0.5.0`,
> so CI rebuilt `0.5.0` and RubyGems rejected the duplicate.) The workflow's first
> job, **Verify tag matches gem version**, now fails the release within seconds,
> before CI runs, if the tag is not `v` plus the `version.rb` version.

### 2. Publish the GitHub Release: this is the deliberate "go"

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

Publishing the Release creates the tag and fires `release.yml`. Once the tag
check and the full CI run pass (a few minutes), the gem is published and the
`release` deployment turns green.

## What CI runs

`ci.yml` runs on every PR to `main`, on every push to `main`, and from
`release.yml` (as `workflow_call`):

| Job | What it checks |
| --- | --- |
| `Ruby X / rails_8_Y` | The suite on Ruby 3.3, 3.4 and 4.0 against `gemfiles/rails_8_0.gemfile` and `gemfiles/rails_8_1.gemfile` (latest Rails 8.0.x and 8.1.x). |
| `Minimum deps` | The suite on Ruby 3.3 with every runtime dependency pinned to its gemspec floor (`gemfiles/minimum.gemfile`). |
| `lint` | RuboCop, from the root `Gemfile.lock`. |
| `Gem package` | Builds the gem and runs `verify_gem.rb` on it. |
| `CI result` | Fails unless every job above succeeded. This is the one required check. |

The `gemfiles/*.gemfile.lock` files are resolved in CI and not committed. To
reproduce a leg locally, for example:

```bash
BUNDLE_GEMFILE=gemfiles/minimum.gemfile bundle install
CI=true BUNDLE_GEMFILE=gemfiles/minimum.gemfile bundle exec rspec
```

`CI=true` makes the dummy app eager-load, as it does on GitHub Actions.

## One-time setup (repository admin)

These are repository and RubyGems settings, not files, so no PR can apply them.
Do them once, in this order.

1. **Require the `CI result` check on `main`.** The "Protect main" ruleset
   (id 12823605) still requires `test (3.2, 7.1)`, `test (3.2, 7.2)`,
   `test (3.3, 7.1)`, `test (3.3, 7.2)` and `lint`. The current `ci.yml` never
   reports the four `test (...)` checks and nobody can bypass the ruleset, so the
   PR that introduces it cannot merge until this changes. Once that PR shows a
   green **CI result**, run:

   ```bash
   gh api repos/rubylab-app/iron_admin/rulesets/12823605 \
     | jq '{name, target, enforcement, conditions, bypass_actors, rules: [.rules[] | if .type == "required_status_checks" then .parameters.required_status_checks = [{"context": "CI result", "integration_id": 15368}] else . end]}' \
     | gh api -X PUT repos/rubylab-app/iron_admin/rulesets/12823605 --input -
   ```

   `15368` is the GitHub Actions app, so only a workflow job can satisfy the
   check. The pull request and Copilot review rules are kept as they are.

2. **Restrict the `release` environment to `v*` tags.**

   ```bash
   gh api -X PUT repos/rubylab-app/iron_admin/environments/release \
     -F 'deployment_branch_policy[protected_branches]=false' \
     -F 'deployment_branch_policy[custom_branch_policies]=true'
   gh api -X POST repos/rubylab-app/iron_admin/environments/release/deployment-branch-policies \
     -f name='v*' -f type=tag
   ```

   A `release: published` run deploys from `refs/tags/vX.Y.Z`, which matches.

3. **Bind the RubyGems trusted publisher to the `release` environment.** On
   rubygems.org, open **iron_admin → Trusted publishers**. A publisher cannot be
   edited, so:
   1. Add a GitHub Actions publisher with owner `rubylab-app`, repository
      `iron_admin`, workflow filename `release.yml` and environment `release`.
   2. Delete the existing publisher that has no environment. This step is
      required: RubyGems falls back to a publisher without an environment, so
      leaving it in place lets a run from any branch publish.

   If the only publisher listed already has environment `release`, skip this step.

4. **Recommended: protect release tags.** Without this, anyone with write access
   can still create a `v*` tag on any commit, including one with a modified
   `release.yml`, and that run passes the environment's tag policy.

   ```bash
   gh api -X POST repos/rubylab-app/iron_admin/rulesets --input - <<'JSON'
   {"name": "Protect release tags", "target": "tag", "enforcement": "active",
    "conditions": {"ref_name": {"include": ["refs/tags/v*"], "exclude": []}},
    "rules": [{"type": "creation"}, {"type": "update"}, {"type": "deletion"}],
    "bypass_actors": [{"actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "always"}]}
   JSON
   ```

   The admin bypass (`actor_id` 5 is the admin role) lets `gh release create`
   still create the tag.

With steps 2 and 3 in place, `release.yml` can publish only when it runs on a
`v*` tag, never from a branch. Step 4 limits who can create those tags.

To check the settings (read-only):

```bash
gh api repos/rubylab-app/iron_admin/rulesets/12823605 \
  --jq '.rules[] | select(.type == "required_status_checks") | .parameters.required_status_checks'
gh api repos/rubylab-app/iron_admin/environments/release --jq '.deployment_branch_policy'
gh api repos/rubylab-app/iron_admin/environments/release/deployment-branch-policies \
  --jq '.branch_policies[] | {name, type}'
```

## Notes & gotchas

- **Never run `rake release` locally**: it would `gem push` a second time.
- A bare `git push origin v0.7.0` will **not** publish. Only a *published*
  GitHub Release does.
- **No secrets needed.** Publishing authenticates from GitHub Actions to RubyGems
  via OIDC trusted publishing.
- **Forks never publish.** The publish job only runs in `rubylab-app/iron_admin`,
  so a fork is a safe place to rehearse a release.
- **Actions are pinned to commit SHAs**, with the version in a trailing comment.
  Dependabot ([`.github/dependabot.yml`](.github/dependabot.yml)) proposes the
  bumps in one grouped weekly PR.
