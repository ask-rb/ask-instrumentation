# Versioning — ask-instrumentation

This file is this repository's **canonical versioning policy**. If any other
document (README, RELEASE.md, CONTRIBUTING.md, commit messages) disagrees
with it, this file wins.

## Scheme

Versions follow [Semantic Versioning 2.0.0](https://semver.org) as
`MAJOR.MINOR.PATCH`:

- **PATCH** — backwards-compatible bug fixes only.
- **MINOR** — backwards-compatible new functionality.
- **MAJOR** — breaking changes.

### Pre-1.0 (0.x.y)

While the major version is `0`, the public API is not frozen:

- **0.x.PATCH** — bug fixes, docs, tests. No intentional behavior or public
  API change.
- **0.x.MINOR** — new functionality, *and* any breaking change (removing or
  renaming public API, changed event names or payload schemas, changed
  defaults). Pre-1.0, MINOR carries the breaking changes — there is no
  separate major bump until 1.0.0.
- **1.0.0** — first stable release; from here MAJOR/MINOR/PATCH mean exactly
  what SemVer says.

### Sequential one-step patch increments

Patch numbers advance by exactly one per release: `0.2.2` → `0.2.3` →
`0.2.4`. Never skip or jump patch numbers (`0.2.2` → `0.2.5` is wrong), even
when several fixes ship together — they ship as a single release with a
single patch number. The same one-step rule applies to minor and major.

## All releases go through gemchain

Every `ask-*` gem — ask-instrumentation included — and **yamine** is released
through **gemchain** from the workspace root. Never `rake release`, never a
hand-run `gem build` / `gem push`, never a hand-edited version bump outside
gemchain:

```bash
cd /Users/kaka/Code/ask-rb
gemchain guard ask-instrumentation
gemchain update ask-instrumentation <new-version> --dry-run
gemchain update ask-instrumentation <new-version> --test-only
gemchain update ask-instrumentation <new-version>
```

gemchain bumps the version, runs the tests, publishes, rewrites dependent
gems' constraints, and cascades their releases in topological order.

**gemchain itself** is not an `ask-*` gem, so the cascade cannot release it.
It follows the same release discipline manually: bump `VERSION`, update the
changelog, run tests, commit, `gem build` + `gem push`, `git tag`, push —
then `gem install gemchain` to refresh the installed binary.

## Dependency releases use the gemchain cascade

ask-instrumentation depends on `ask-runtime`. Releasing ask-runtime (or any
gem this one depends on) is never a single-gem event: one
`gemchain update ask-runtime <ver>` from the workspace root rewrites this
gem's gemspec constraint, re-runs this suite, bumps ask-instrumentation one
patch, commits, publishes, tags, and pushes. The same cascade runs in the
other direction — `ask-agent`, `ask-observability`, `ask-opentelemetry`, and
`ask-monitoring` depend on ask-instrumentation and are released when this
gem changes. `gemchain guard` shows the full blast radius; never hand-edit a
constraint or release dependents separately.

## Clean tree required

`git status --porcelain` must be empty before any release starts — commit or
stash work-in-progress first. gemchain commits the release's own changes
(version, changelog, constraint updates) as part of the release. A release is
done only when it is **published AND pushed**.

## Release checklist

Every release, in this order:

1. **Clean tree** — `git status --porcelain` is empty.
2. **Tests** — `bundle exec rake test` passes (dependents too, via
   `gemchain update … --test-only`, when cascading).
3. **Build** — `gem build ask-instrumentation.gemspec` succeeds (gemchain
   does this during release; a manual build is a pre-flight sanity check
   only).
4. **Changelog** — `## [Unreleased]` entries moved under a new
   `## [X.Y.Z] — YYYY-MM-DD` heading; a fresh empty `## [Unreleased]`
   opened above it.
5. **Version** — bumped in `lib/ask/instrumentation/version.rb` by
   gemchain, not by hand.
6. **Commit** — one release commit with version, changelog, and constraint
   updates (gemchain creates it).
7. **Tag** — `vX.Y.Z` on exactly that commit.
8. **Publish** — pushed to RubyGems inside gemchain.
9. **Push** — commit and tag pushed (`git push origin HEAD --tags`).
10. **Verify** — see "Version agreement" below.

## Version agreement

After every release these must all say the same thing:

| Source | Must equal |
|---|---|
| Published version on RubyGems | `X.Y.Z` |
| `lib/ask/instrumentation/version.rb` at HEAD | `X.Y.Z` |
| Git tag | `vX.Y.Z` |
| Source committed **and** pushed | yes |

A mismatch — a published gem with no commit (orphaned release), a bumped
`version.rb` with no publish, a tag pointing elsewhere — is a broken
release. Fix it (run the tests, then commit and push) before starting the
next one. `gemchain check` from the workspace root is the quick audit.

## Unreleased changelog workflow

`CHANGELOG.md` keeps a `## [Unreleased]` section at the top. Every
user-facing change lands under it in the same commit that introduces it,
using Keep a Changelog headings (`Added`, `Changed`, `Fixed`, `Removed`). At
release time that section is retitled to the new version and date; a fresh
empty `## [Unreleased]` stays above it. Never publish a release whose
entries are still under `[Unreleased]`, and never rewrite history for
already-released versions.

## Examples

Starting from `0.2.2`, released via `gemchain update ask-instrumentation
<ver>` from the workspace root:

| Change | Next version | Why |
|---|---|---|
| Fix a dropped event payload field | `0.2.3` | pre-1.0 fix ⇒ sequential PATCH |
| Two bug fixes land together | `0.2.4` (one release, not `0.2.5`) | one step, however many fixes |
| Add a new event name | `0.3.0` | new feature ⇒ pre-1.0 MINOR |
| Rename a public event or change its payload (breaking) | `0.3.0` | breaking ⇒ pre-1.0 MINOR |
| Declare the API stable | `1.0.0` | first stable major |
| `ask-runtime` releases | cascade via `gemchain update ask-runtime <ver>` | this gem's constraint is rewritten and it is re-tested, bumped one patch, published — never by hand |
