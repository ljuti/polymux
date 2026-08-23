## Ruby Gem Bootstrapping Plan

> **Note for a third sibling gem.** This checklist was refined during
> procountor-ruby's bootstrap. The 13-slice procountor-ruby build
> surfaced real friction not present in the original netvisor-ruby
> run; the amendments below capture it. When bootstrapping a third
> gem, follow this document AND `docs/compatibility-guide.md` — the
> latter describes the cross-gem contract that the consuming app
> relies on.

### Phase 1: Repository & Gem Initialization

1. **Create the GitHub repository** and clone it locally

2. **Generate gem scaffold**
   ```
   bundle gem <project>
   ```
   Select MIT license, RSpec for testing, Standard for linting.

3. **Flatten the namespace** (important; do this first).
   `bundle gem <provider>-ruby` produces `lib/<provider>/ruby.rb` with
   `<Provider>::Ruby::*` nesting. The compat-guide contract
   (§2.1–§2.2) assumes flat `<Provider>::*`. Fix before anything else:

   ```bash
   # Rename files
   mv lib/<provider>/ruby.rb lib/<provider>.rb
   mv lib/<provider>/ruby/version.rb lib/<provider>/version.rb
   rmdir lib/<provider>/ruby
   mv sig/<provider>/ruby.rbs sig/<provider>.rbs
   rmdir sig/<provider>
   ```

   Edit `lib/<provider>.rb` to open `module <Provider>` directly (no
   inner `module Ruby`). Edit `lib/<provider>/version.rb` to set
   `<Provider>::VERSION`. Update the gemspec's `require_relative` and
   `spec.version` references. Rename any `<provider>_ruby_spec.rb` to
   `<provider>_spec.rb`. Confirm `bundle exec rspec` still passes.

4. **Verify `required_ruby_version`** in `<project>.gemspec` — set it
   to the *floor* of Ruby versions the gem supports, **not** the
   version you develop on:

   ```ruby
   spec.required_ruby_version = ">= 3.2.0"
   ```

   Three distinct Ruby-version pins coexist and they mean different
   things:

   | Pin                                | Value      | Meaning                                                 |
   |------------------------------------|------------|---------------------------------------------------------|
   | `gemspec.required_ruby_version`    | `>= 3.2.0` | Lowest version consumers can install on                 |
   | `.mise.toml` (or `.tool-versions`) | `4.0` (or latest) | Ruby you run locally / in the devcontainer      |
   | CI matrix in `.github/workflows/ci.yml` | `3.2` / `3.3` / `3.4` | Range tested on every push                 |

   Do NOT set `required_ruby_version` to the dev Ruby; that breaks
   installability.

5. **Update `.standard.yml`** to match the minimum Ruby version
   (the gemspec floor, not the dev Ruby):
   ```yaml
   ruby_version: 3.2
   ```

6. **Fill in gemspec metadata** — `summary`, `description`,
   `homepage`, `source_code_uri`, `changelog_uri`, `allowed_push_host`.

   For internal publishing (e.g. Gemfury):
   ```ruby
   spec.metadata["allowed_push_host"] = "https://push.fury.io/<account>/"
   spec.metadata["rubygems_mfa_required"] = "true"
   ```

   For public RubyGems:
   ```ruby
   spec.metadata["allowed_push_host"] = "https://rubygems.org"
   ```

7. **Declare runtime dependencies** (the starter set for an API-wrapper
   gem that follows the compat-guide contract):
   ```ruby
   spec.add_dependency "activemodel",      ">= 7.0"  # Attributes + Dirty
   spec.add_dependency "activesupport",    ">= 7.0"  # Notifications
   spec.add_dependency "faraday",          ">= 2.0"  # HTTP transport
   spec.add_dependency "faraday-multipart", ">= 1.0"  # if any endpoint accepts file uploads
   spec.add_dependency "oj",               ">= 3.13" # JSON codec
   ```

   Plus dev deps in the `Gemfile` (not the gemspec):
   ```ruby
   gem "webmock", "~> 3.19"   # HTTP stubbing in tests
   gem "rspec",   "~> 3.0"
   gem "standard", "~> 1.3"
   gem "rake", "~> 13.0"
   ```

   `faraday-multipart` can be omitted if the target API has no
   multipart endpoints; add it when the first multipart-needing
   resource slice starts.

---

### Phase 2: .gitignore

Ensure `.gitignore` covers these categories. Note `Gemfile.lock` is
gitignored — standard practice for libraries (consuming apps lock
their own transitive deps; library authors don't).

```gitignore
# Bundler
/.bundle/
/vendor/bundle/
Gemfile.lock

# Documentation
/.yardoc
/_yardoc/
/doc/

# Build artifacts
/pkg/
/tmp/

# Coverage
/coverage/

# Test artifacts
/spec/reports/
.rspec_status

# IDE
.idea/
.vscode/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Environment
.env
.env.local

# AI assistant artifacts
.claude/
.opencode/
```

Add any project-specific entries (e.g., `*.db*` if using SQLite).

---

### Phase 3: Rakefile

`bundle gem` generates a `Rakefile` with RSpec and Standard tasks. Verify it includes:

```ruby
require "rspec/core/rake_task"
require "standard/rake"

RSpec::Core::RakeTask.new(:spec)
task default: %i[spec standard]
```

This gives you `rake spec`, `rake standard`, and `rake` (runs both).

---

### Phase 4: Linting Configuration

Create `.standard.yml`:

```yaml
ruby_version: 3.2
```

Standard Ruby provides a zero-config linter. No further customization needed in most cases. Add `ignore:` rules only when there is a concrete reason.

---

### Phase 5: Devcontainer Setup

Create `.devcontainer/` with three files:

**`.devcontainer/devcontainer.json`**
- Build from a custom `Dockerfile` with the project root as context
- Install features: `ghcr.io/devcontainers/features/git:1`
- Mount named volumes for persistent storage (e.g., `/apexflow`)
- `postCreateCommand` and `postStartCommand` pointing to shell scripts
- VS Code customizations: `Shopify.ruby-lsp`, `testdouble.vscode-standard-ruby`

```json
{
  "name": "<project>",
  "build": {
    "dockerfile": "Dockerfile",
    "context": ".."
  },
  "features": {
    "ghcr.io/devcontainers/features/git:1": {}
  },
  "mounts": [
    {
      "source": "<project>-apexflow",
      "target": "/apexflow",
      "type": "volume"
    }
  ],
  "postCreateCommand": "bash .devcontainer/post-create.sh",
  "postStartCommand": "bash .devcontainer/post-start.sh",
  "customizations": {
    "vscode": {
      "extensions": [
        "Shopify.ruby-lsp",
        "testdouble.vscode-standard-ruby"
      ]
    }
  }
}
```

**`.devcontainer/Dockerfile`**
- Base image: `ruby:<version>-slim` matching the gem's minimum Ruby version
- Install `build-essential` and `libssl-dev` for native gem compilation
- Set `WORKDIR /workspace`
- Copy `Gemfile`, `Gemfile.lock`, gemspec, and version file for layer caching
- Run `bundle install`, then copy the rest of the project

```dockerfile
FROM ruby:<version>-slim

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      build-essential \
      libssl-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

COPY Gemfile Gemfile.lock* <project>.gemspec lib/<project>/version.rb ./lib/<project>/

RUN bundle install

COPY . .
```

**`.devcontainer/post-create.sh`** (runs once on container creation)
```bash
#!/usr/bin/env bash
set -euo pipefail

bundle install
```

**`.devcontainer/post-start.sh`** (runs on every container start)
```bash
#!/usr/bin/env bash
set -euo pipefail

bundle check || bundle install
```

Make both scripts executable: `chmod +x .devcontainer/post-create.sh .devcontainer/post-start.sh`

---

### Phase 6: CI Pipeline

Create `.github/workflows/ci.yml`:

**Triggers:** `push` to `main` + all `pull_request`

**Strategy matrix:** Test against target Ruby versions (e.g., 3.2, 3.3, 3.4)

**Steps:**
1. `actions/checkout@v4`
2. `ruby/setup-ruby@v1` with `ruby-version: ${{ matrix.ruby }}` and `bundler-cache: true`
3. `bundle exec rake` (runs specs + Standard linting via the default task)

```yaml
name: Ruby

on:
  push:
    branches: [main]
  pull_request:

jobs:
  build:
    runs-on: ubuntu-latest
    name: Ruby ${{ matrix.ruby }}
    strategy:
      matrix:
        ruby:
          - '3.2'
          - '3.3'
          - '3.4'
    steps:
      - uses: actions/checkout@v4
      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: ${{ matrix.ruby }}
          bundler-cache: true
      - name: Run the default task
        run: bundle exec rake
```

---

### Phase 7: Release Workflow

Use `vX.Y.Z` for tags (the `v` prefix is the convention across both
sibling gems). `CHANGELOG.md` uses the [Keep a Changelog](https://keepachangelog.com/)
format with an `[Unreleased]` section at the top that moves into a
dated version section at release time.

**Manual release flow** (works for both RubyGems and Gemfury):

1. Update `lib/<project>/version.rb`.
2. Update `CHANGELOG.md` (move `[Unreleased]` contents into a new
   `[X.Y.Z] - YYYY-MM-DD` section; leave a fresh empty `[Unreleased]`
   above it).
3. Commit: `git commit -am "Release vX.Y.Z"`.
4. Tag: `git tag -a vX.Y.Z -m "vX.Y.Z - <one-line summary>"`.
5. Push: `git push --follow-tags`.
6. Build + push the gem:
   ```bash
   gem build <project>.gemspec
   # Gemfury:
   gem push <project>-X.Y.Z.gem --host https://push.fury.io/<account>/
   # RubyGems (public):
   gem push <project>-X.Y.Z.gem
   ```

Gemfury auth: `~/.gem/credentials` with a Gemfury deploy token, or
`gem push --key <keyname>` if you've configured named credentials.

**Optional automation**: `.github/workflows/release.yml` triggered on
`v*` tags. Requires a `GEMFURY_API_TOKEN` (or `RUBYGEMS_API_KEY`)
repo secret. Skip until you're doing enough releases that manual
feels tedious.

---

### Phase 8: Testing Conventions

Uses **RSpec** with these conventions:

- Spec files mirror the lib structure: `lib/foo/bar.rb` → `spec/foo/bar_spec.rb`
- Configure in `.rspec`:
  ```
  --require spec_helper
  --format documentation
  ```
- Keep `spec_helper.rb` minimal — add helpers only as needed
- CI runs the full suite via `bundle exec rake`

---

### Phase 9: License

`bundle gem` generates `LICENSE.txt` (MIT). Verify it has the correct year and author.

---

### Checklist Summary

```
[ ] 1.  Initialize Git repo + generate gem scaffold
[ ] 2.  Flatten namespace (lib/<provider>.rb, not lib/<provider>/ruby.rb)
[ ] 3.  Set required_ruby_version to the floor, not the dev Ruby
[ ] 4.  Configure .standard.yml to match the gemspec floor
[ ] 5.  Fill in gemspec metadata (including allowed_push_host for Gemfury/RubyGems)
[ ] 6.  Declare runtime dependencies (activemodel, activesupport, faraday, oj)
[ ] 7.  Configure .gitignore (Gemfile.lock IS gitignored for libraries)
[ ] 8.  Verify Rakefile (spec + standard as default)
[ ] 9.  Add .devcontainer/ (devcontainer.json, Dockerfile, post-*.sh)
[ ] 10. Add .github/workflows/ci.yml with Ruby version matrix
[ ] 11. Add LICENSE.txt
[ ] 12. Write first spec, verify `bundle exec rake` passes
[ ] 13. Push, verify CI workflow runs green
[ ] 14. Before first resource slice: read docs/compatibility-guide.md end-to-end
[ ] 15. Tag v0.1.0, publish to Gemfury (or RubyGems)
```

Each phase is independent enough to commit separately. The
devcontainer is a good one to do early since it gives you a
consistent dev environment for everything that follows.

Item 14 is non-negotiable for a sibling gem — the compat guide
encodes cross-gem rules that are hard to retrofit.
