# AGENTS.md — coding-agent guide for storage-cleaner

Rules live here; every `CLAUDE.md` is a one-line `@AGENTS.md` import. Edit this file, never the
import. A rule that applies to one folder goes in a nested `AGENTS.md` there, with its own
one-line `CLAUDE.md` beside it.

## What this repo is

Storage Cleaner is a native Mac app (SwiftUI, macOS 13 or later, built with SwiftPM) that shows where the disk space went, builds a cleanup plan, and can move the planned items to the Trash after a confirmation dialog and Touch ID or the Mac password. It is for a Mac owner cleaning up their own disk; see [README.md](README.md) for the safety rules the code enforces.

The one thing a newcomer gets wrong: the app is **review only by design**. Measuring runs only allowlisted read-only tools, nothing is ever deleted permanently, and CI fails the build if delete, move, or shell code appears in `Sources` outside a line marked `SAFETY-ALLOWED`. _[FILL IN: who else uses the app, if anyone, and whether it is meant for distribution beyond Hen's own Macs.]_

## Layout

| Package / folder                                       | Role                                                                                                                                                                                                         | Depends on                                         |
| ------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------- |
| [Sources/StorageCleaner/](Sources/StorageCleaner/)     | The one SwiftPM executable target: SwiftUI views (`ContentView`, `OverviewView`, `CategoryView`), `AppState`, `Catalog`, `Models`, `DiskScanner`, `Shell` (read-only tool allowlist), `Deleter` (Trash only) | SwiftUI, AppKit, LocalAuthentication               |
| [Resources/](Resources/)                               | `Info.plist` for the app bundle; `AppIcon.icns` is generated and gitignored                                                                                                                                  | —                                                  |
| [Scripts/](Scripts/)                                   | `make_icon.sh` + `make_icon.swift` — render the app icon into `Resources/AppIcon.icns`                                                                                                                       | `swift`, `sips`, `iconutil`                        |
| [.github/workflows/](.github/workflows/)               | `build.yml` — safety check, universal build, app bundle, ad-hoc codesign, GitHub Release on every push to `main`                                                                                             | GitHub Actions `macos-14`                          |

_[FILL IN: the boundary rule between them — what may import what, and where a cross-cutting helper goes.]_

- Only `Shell.swift` starts processes, and only the programs its allowlist names; only `Deleter.swift` changes files, and only by moving them to the Trash. New code that measures goes through `Shell`; new code that removes goes through `Deleter`.

## Public contracts

- **The review-only safety invariant** — the forbidden-pattern grep in the `Safety check` step of [.github/workflows/build.yml](.github/workflows/build.yml), the `Shell.isAllowed` allowlist, and `Deleter.isProtected`. Widening any of them, or adding a `SAFETY-ALLOWED` marker, is a behavior change that needs Hen's explicit OK.
- **The app bundle identity** — `CFBundleIdentifier` `com.heneytan.StorageCleaner` and `LSMinimumSystemVersion` `13.0` in [Resources/Info.plist](Resources/Info.plist), and `platforms: [.macOS(.v13)]` in [Package.swift](Package.swift).
- **The release asset** — tag `v1.0.<run_number>` and asset `StorageCleaner-mac.zip` holding `Storage Cleaner.app`, published by `build.yml`.

Changing any of them is a behavior change, never a refactor. Before changing a shared module, grep its consumers across the repo; a signature change enumerates every call site.

## Docs

| Folder                       | What it holds                                                      |
| ---------------------------- | ------------------------------------------------------------------ |
| [docs/adr/](docs/adr/)       | Immutable architecture decision records.                           |
| [docs/design/](docs/design/) | Design specs for a feature or subsystem.                           |
| [docs/plans/](docs/plans/)   | Implementation plans, task by task.                                |
| [docs/guides/](docs/guides/) | Guides, indexed by [docs/guides/README.md](docs/guides/README.md). |

Docs mirror rules and code for humans. When a change makes a guide, design doc, or README wrong, update it in the same change. Don't load a doc to follow a rule.

## Artifacts

`docs/artifacts.json` lists this project's published documents (handbook, screen spec, architecture review…) with the date each was last brought up to date. The PeakWatch dashboard reads it and flags an artifact as stale once code commits land after its `asOf`. When a change alters architecture, capabilities, screens or setup, update the artifact at its existing URL (never publish a new one) and bump `asOf` in the same change.

## Common tasks

| Command                                                  | Effect                                                                                                    |
| -------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| `swift build`                                            | Debug build of the app binary                                                                             |
| `swift build -c release --arch arm64 --arch x86_64`      | Universal release binary, as CI builds it                                                                 |
| `bash Scripts/make_icon.sh`                              | Render `Resources/AppIcon.icns`                                                                           |
| `grep -rnE "$FORBIDDEN" Sources \| grep -v SAFETY-ALLOWED` | The CI safety check, with `FORBIDDEN` copied from [build.yml](.github/workflows/build.yml); any output fails |

`swift build` is the aggregate check. It skips the safety check (run the grep row above by hand whenever `Sources` changes) and the app-bundle assembly in `build.yml`. There are no tests yet.

---

## Git

- Never include the Claude Code session link (`Claude-Session:` trailer, `https://claude.ai/code/session_...`) in commit messages, PR bodies, or issue and review comments.
- The `Co-Authored-By` trailer names `Agent`, never the full model/email.
- A PR body ends with `Co-Authored-By: Agent`, never with a "Generated with Claude Code" line or any other tool attribution.

### Git Commit Conventions

Commits follow Conventional Commits

```
type(scope): short description
```

| Type       | When to use                               |
| ---------- | ----------------------------------------- |
| `feat`     | New feature or capability                 |
| `fix`      | Bug fix                                   |
| `refactor` | Code change with no functional difference |
| `test`     | Adding or fixing tests                    |
| `chore`    | Maintenance, dependency updates, tooling  |

Scope identifies the affected package(s) or area.
Scope is optional for changes that span the whole repo or don't map cleanly to a single package.

**Rules**

- Description is lowercase, no trailing period.
- Use imperative mood: "add", "fix", "remove" — not "added" or "fixes".
- If a commit spans more than 2 scopes, omit the scope, keep only the type, and use a multi-line commit for details.

**Multi-line commits**

Prefer multi-line format whenever a commit includes multiple distinct changes — not just for PR squash merges. Use a single-line message only when the commit does exactly one thing.

Add a body listing the individual changes as bullet points. Omit iterative `type(scope)` bullets that only refine or clean up work introduced earlier in the same PR — include only bullets that add distinct value.

**Bullet prefix rule:** if every bullet has the same `type(scope)` as the subject line, omit `type(scope):` from all bullets and write only the description. If any bullet differs, include `type(scope):` on all bullets.

### Git Branch Rules

- **Protected branches: `main` — commits land there only via PRs or automated tooling, never manually.** Always work on a feature branch and open a PR.
- Branch naming: `feat/<description>`, `fix/<issue-number>-<description>`, `refactor/<issue-number>-<description>`.
- Every push to `main` (so every merged PR) builds and publishes a GitHub Release through `build.yml`.

### Issues

Issues carry the label of their kind: `bug` for a defect or regression, `enhancement` for a feature or behavior change, `documentation` for docs-only work, `accessibility` for a barrier affecting people with disabilities. Title: one specific line naming the area and the symptom, capability, or target.

### Pull Requests

- Label the PR to match the issue it closes, adding `security`, `breaking`, etc. when they apply.
- The PR body closes its issue (`Closes #<n>`).

---

## House rules

### Workflow rules

- **When the user asks a question, discuss first** — don't jump to implementation or edits as a response.
- **Be direct and concise** — no pleasantries, no preamble, no filler. Disclaimers and caveats stay short; the response goes to the main answer. Asked to explain something, give the high-level summary unless depth is asked for.
- **Link what you name.** A file or a doc section in a reply is a markdown link ([AGENTS.md](AGENTS.md), [Git](AGENTS.md#git)), never a bare path.
- **Report an edit, don't paste it.** What changed, where (linked), and why — the user reads the file.
- **Feedback in chunks.** Review findings or suggestions you volunteer in an interactive conversation come in chunks of up to five points, saying how many remain. A skill's prescribed report is presented as that skill says, and an unattended run sends the whole report in one message.
- **Ask before adding a dependency.** Prefer what the repo already has.
- **Ask before generating `.md` docs**, unless explicitly instructed otherwise.
- **A document is as long as its task needs.** Cover the substance; no filler sections, restated summaries, or boilerplate. A skill's or template's required sections are substance — the rule governs what fills them and what is added beyond them.
- **Search the web for current docs when researching a dependency, API, or tool** — training data is stale. Verify against the installed version before applying advice.
- **If a rule conflicts with a task, ask** — don't silently bypass.
- **TDD is mandatory for features, fixes, and behavior changes** — the `tdd` skill: a failing test first, then the minimum to pass.
- **`swift build` must pass before committing.** Before reporting a PR ready, run it again plus whichever manual checks Common tasks names.

### Technical rules

- **Design principles: DRY, KISS, YAGNI, SOLID — in that order of frequency.** Don't abstract until the second duplicate. Don't add config knobs, hooks, or generics for a use case that isn't in the diff. An established codebase pattern is not over-engineering: repeating it for new code is expected; flag as YAGNI only abstractions nothing in the codebase uses.
- **Tests live under `Tests/StorageCleanerTests/`, the SwiftPM convention, run by `swift test`.** Every new public function, type, or component ships with tests in the same commit; cover the happy path, the documented edge cases (empty, null, error), and failure paths. Tests exercise real logic.
- **Document non-obvious logic only.** A short comment explaining _why_ (invariant, workaround, protocol quirk, ADR reference) is welcome. Don't restate _what_ the code does.
- **Never count what the text lists.** "The three options", "both callbacks", "these five steps" — in a doc, a comment, a docstring, or a commit body — go stale the moment an item is added or removed. Let the list carry its length.
- **When a code question is really an architecture question, read the ADR before editing.** A boundary or a shape that looks wrong was decided, not overlooked.
- **Follow existing code patterns.** Different areas may differ in style — adapt. When existing code and these rules disagree, the rules win: legacy code may predate them.

### Checks and evidence

Each of these exists because its absence ships something wrong.

- **Every claim in a report is audited against a tool result from this session.** Report only work you can point to evidence for, and say explicitly what is not yet verified. Outcomes faithfully: a failing test with its output, a skipped step named, and what is done and verified stated plainly, without hedging.
- Every guard, gate, or check must be provably able to fail: break what it guards, watch it go red, revert. A check you cannot demonstrate red is not a check.
- Catches fail closed. A tool error, an empty result, or a skipped step never reads as "no findings".
- Numbers in commit messages and PR bodies are prose; evidence is the command that ran and its exit status.

## Security

When writing or reviewing code, check for the following. The categories follow the OWASP Top 10; look an item up there for depth. Severity: **HIGH** = blocker,
**MEDIUM** = should fix, **LOW** = consider fixing but always notify the team.

### HIGH — Blockers

- **Hardcoded credentials or API keys** (Security Misconfiguration) in source code or committed config files.
- **Sensitive data exposure** (Cryptographic Failures): secrets, tokens, or PII written to logs, included in error output, or returned beyond what the caller needs.
- **Untrusted input reaching a shell, a query, a parser, or a filesystem path unvalidated** (Injection) — injection and path traversal. Parameterize queries; sanitize any path built from input.
- **Weakening the review-only invariant** (Insecure Design): a new process launch outside `Shell`'s allowlist, a file change outside `Deleter`, a permanent delete, emptying the Trash, a path `Deleter.isProtected` should refuse, or a `SAFETY-ALLOWED` marker added to get past the CI grep.

### MEDIUM — Should fix

- **Cryptographic failures** (Cryptographic Failures): weak algorithms, hardcoded IVs, home-rolled crypto, insufficient key lengths; secrets encrypted at rest and in transit.
- **Unhandled errors** (Security Misconfiguration) — an uncaught rejection, panic, or exception that leaks a stack trace or internal state to a caller.

### LOW — Consider

- **Vulnerable or outdated components** (Vulnerable and Outdated Components): when adding or upgrading a dependency, verify it has no known CVEs and is actively maintained.

## Code conventions

### General

- No magic numbers or strings — named constants.
- No commented-out code. A `TODO` / `FIXME` references a ticket or states a clear action.
- No debug prints in shipped code — use the project's logger.
- Prefer early return over nested conditionals; split a function with many branches.
- When a function takes more than two parameters, two of the same type, or any boolean, take one named argument object (or struct) instead.
- Lint and typecheck every file you touch before finishing; lint errors are often real bugs — a missing await, an unhandled error, a wrong import.

### Swift

- SwiftUI on macOS 13+, no third-party dependencies; the target builds universal (`arm64` + `x86_64`).
- _[FILL IN: naming, typing, and idiom rules for Swift that a linter does not already enforce]_

## Permissions when running unattended

This section applies when you run as a subagent, in a background task, or in a non-interactive session — anywhere a permission prompt has no one to answer it. An interactive session simply asks; a denied call there means the user declined, so adjust the approach rather than retry it.

Unattended, a denied tool call is a silent failure mid-workflow. A call must pass both the tools the session has and the project's permission lists (`.claude/settings.json` for Claude Code — `permissions.allow` is auto-approved, `permissions.deny` is blocked). Read them at the start and plan around them.

- Each piped variant of a shell command needs its own allow entry: `Bash(git log*)` does not cover `git log | head`.
- Fetch only allowed domains; call only allowed MCP tools; check the deny list for path restrictions before editing.
- When a needed tool is missing, try a permitted alternative; if none exists, stop and report — do not retry the denied call.
- At the end of your work, list any tool you needed but could not use, so the user can extend the settings:

```
MISSING PERMISSIONS:
  - <Tool>(<pattern>): <why needed>
```
