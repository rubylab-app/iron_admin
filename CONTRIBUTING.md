# Contributing to IronAdmin

Thank you for your interest in contributing to IronAdmin! This document provides guidelines for contributing.

## Development Setup

1. Fork and clone the repository
2. Use Ruby >= 3.3 (the repo's `.ruby-version` pins the development Ruby, currently 3.4.9)
3. Install dependencies:
   ```bash
   bundle install
   ```
4. Run the test suite:
   ```bash
   bundle exec rspec
   ```
   CI also runs it with `CI=true`, which makes the dummy app eager-load like production.
5. Run the linter the way CI does (RuboCop skips dot-directories, so `.github/scripts` is
   named explicitly):
   ```bash
   bundle exec rubocop . .github/scripts
   ```

IronAdmin supports Ruby >= 3.3 and Rails >= 8.0.4. CI runs the suite on Ruby 3.3, 3.4 and
4.0 against Rails 8.0 and 8.1, plus a job that pins every runtime dependency to its gemspec
floor. To reproduce a CI leg locally, point Bundler at one of the files in `gemfiles/`:

```bash
BUNDLE_GEMFILE=gemfiles/minimum.gemfile bundle install
CI=true BUNDLE_GEMFILE=gemfiles/minimum.gemfile bundle exec rspec
```

## Making Changes

### Branch Naming

Use descriptive branch names:
- `feature/add-bulk-export` for new features
- `fix/search-pagination` for bug fixes
- `docs/update-readme` for documentation

### Code Style

- Follow the [Ruby Style Guide](https://rubystyle.guide/)
- All code must pass Rubocop without offenses
- Run `bundle exec rubocop -A` to auto-fix issues

### Testing

- All tests must follow [BetterSpecs](https://www.betterspecs.org/) guidelines
- Keep test coverage at or above 90% (SimpleCov fails the run below that)
- Write tests before implementing features (TDD)
- Use `describe` for methods, `context` for conditions
- One expectation per test when possible

Example test structure:
```ruby
RSpec.describe MyClass do
  describe "#method_name" do
    context "when condition is true" do
      it "returns expected value" do
        expect(subject.method_name).to eq(expected)
      end
    end
  end
end
```

### Commit Messages

- Use present tense: "Add feature" not "Added feature"
- Use imperative mood: "Fix bug" not "Fixes bug"
- Reference issues when applicable: "Fix #123"

### Pull Requests

1. Update documentation if needed
2. Add tests for new functionality
3. Ensure all tests pass
4. Ensure Rubocop passes
5. Update CHANGELOG.md

## Reporting Issues

When reporting issues, please include:
- Ruby version
- Rails version
- IronAdmin version
- Steps to reproduce
- Expected vs actual behavior

## Questions?

Open a discussion on GitHub if you have questions about contributing.
