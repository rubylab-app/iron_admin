# Copilot Code Review Instructions

## Project Context

IronAdmin is a **Ruby on Rails Engine gem** that provides a convention-over-configuration admin panel. It auto-generates CRUD interfaces from ActiveRecord models. The gem is mountable, uses ViewComponent, HAML templates, Stimulus controllers, and Tailwind CSS.

## What to Review

### Ruby Code Quality

- **Rubocop compliance**: Flag code that would violate standard Rubocop rules. Never suggest modifying `.rubocop.yml` — always suggest refactoring the code to comply.
- **Rails conventions**: Follow Rails idioms (strong params, concerns, callbacks). Flag direct SQL string interpolation.
- **YAGNI**: Flag unnecessary abstractions, premature generalizations, or speculative code. Three similar lines are better than a premature abstraction.
- **No unnecessary changes**: Don't suggest adding docstrings, comments, or type annotations to code that wasn't changed in the PR. Only flag issues in changed lines.

### Security

- **SQL injection**: All user input must go through parameterized queries or the adapter layer. Flag raw string interpolation in queries.
- **Strong parameters**: Verify all controller params are permitted via `permit`. Flag `permit!` or unsafe `to_unsafe_h` usage.
- **XSS**: Flag `html_safe` or `raw` unless clearly intentional with a comment.
- **OWASP Top 10**: Flag command injection, path traversal, mass assignment bypasses.

### Architecture Patterns

- **Adapter pattern**: All database operations should go through `Resource.adapter` methods, not direct ActiveRecord calls. Flag direct `model.where(...)`, `model.find(...)`, etc. in controllers, helpers, or components. The only file that should call ActiveRecord directly is `lib/iron_admin/adapters/active_record.rb`.
- **Concerns extraction**: Controllers should stay under 250 lines (Rubocop ClassLength). Suggest extracting to concerns when approaching the limit.
- **Value objects**: Prefer Structs or plain Ruby classes (ActionField, ToolAction, NestedAssociation) over hashes for structured data.

### Testing (BetterSpecs)

- **`describe` for methods, `context` for conditions**: Flag `describe` blocks that describe conditions (should be `context "when..."` or `context "with..."`).
- **`subject` and `let` for setup**: Flag instance variables (`@var`) in specs — use `let` instead.
- **One expectation per test**: Flag tests with multiple unrelated expectations. Multiple related expectations in integration/request specs are acceptable.
- **Meaningful descriptions**: `it` descriptions should describe behavior, not restate the operator name or implementation detail.
- **No test duplication**: Flag identical setup code that should be extracted to `before` blocks or shared contexts.

### Backward Compatibility

- **DSL changes**: Any change to Resource, Tool, Dashboard, or Policy DSL must maintain backward compatibility. Flag breaking changes to public method signatures.
- **Arity detection**: Action blocks use arity to determine argument passing (1-arg = legacy, 2-arg = with params). Flag changes that break this convention.
- **Default values**: New keyword arguments must have defaults that preserve existing behavior.

## What NOT to Flag

- **Existing code outside the diff**: Don't suggest improvements to unchanged code.
- **Style preferences**: If Rubocop doesn't flag it, don't flag it. We follow Rubocop's rules, not additional style opinions.
- **HAML formatting**: HAML templates have their own conventions. Don't suggest ERB-style patterns.
- **Test count**: Don't suggest splitting integration tests that verify a complete user flow.
- **Gem dependencies**: Don't suggest alternative gems unless there's a security issue.
