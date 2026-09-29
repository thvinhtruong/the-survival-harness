---
name: gap-audit
description: Audit a just-implemented goal state against its production entry points to surface unreachable code, wiring gaps, silent divergences, and security holes the change opened (access control, injection, secrets, fail-open, new dependencies). Use AFTER a multi-file change reaches its state (scripts/goal now) — before declaring "done" and before commit.
allowed-tools: Read, Grep, Glob, Bash
---

# Gap Audit

Auto-fires via `.claude/hooks/check-gap-audit.sh` when ≥5 code files are modified without a session marker. To skip an audit (refactor, doc tweak, simple fix): `scripts/skip.sh gap-audit "<reason>"`.

## The 7 gap classes

Walk every class. Each one is a real failure mode where unit tests stay green and production breaks — or, for class 7, where production works and leaks.

### 1. Unreachable / unwired

New code that compiles, passes its tests, but no production path executes it. Two flavors:

- **Type/method never called.** Grep for every NEW exported type, field, or `With*()` builder. Exclude `_test.go`. If hits are only definitions and tests → gap.
- **Construction site missing.** Every new dependency needs a `cmd/*.go` instantiation. Every new `With*` builder needs a corresponding call in `cmd/`.

```bash
grep -rn "NewMyThing\|MyField" --include="*.go" --exclude="*_test.go" .
```

### 2. Silent divergence from canonical helpers

A new package reimplements an existing helper (slug, hash, format, parse) with subtly different rules. Both sides of new code agree; old callers diverge.

For every helper added, grep for siblings and confirm byte-for-byte parity OR justify with a comment AND a parity test. Common offenders: `slugify`, `normalize`, `hash`, `canonicalize`, `parse*TS`.

### 3. Filter applied once, bypassed elsewhere

A change adds policy X to component A. Component B re-derives the same data from upstream state and bypasses the filter.

For every filter/transform, find ALL consumers of the upstream source — not just the one the change modified. Each must apply the filter, read pre-filtered data, or document the exemption.

### 4. Recency/window queries that starve under concurrency

`Tail(n)` or `Recent(k)` followed by filtering. If multiple partitions (session/user/workspace) write to the same log, the window fills with other partitions' data and the filtered result is empty.

Rule: `Tail(N × active_partitions)` then filter and cap.

### 5. Format/schema mismatches across boundaries

Producer writes RFC3339Nano; consumer parses RFC3339-only. Or `null` vs `[]` for empty collections. Records silently dropped.

For every serialization format, find the deserializer. Symmetric handling required for: timestamps, optional fields, empty collections, enum case.

### 6. Tests cover units but not seams

Every package has a unit test; no test traces input through ≥2 packages. The bugs from classes 1–5 never trip a test.

For the headline behavior change, is there ≥1 test that runs through the actual production path (real infra registry/store, not mocks)? If everything is pure-function tests → gap. Add at least one seam-level test.

### 7. Security at the new seams

Scoped to the diff — not a full audit of the repo. For every entry point, query,
file path and dependency the change **added or touched**:

| Check | Gap when | Look for |
|---|---|---|
| **Access control** | A new route or read path lacks an explicit role check, or trusts a database policy alone instead of filtering; an id from the client reaches a query unscoped (IDOR) | the route's auth check; a `WHERE` on the caller's tenant / owner; a test where the wrong role gets zero rows or 403 |
| **Injection** | User input reaches SQL, a shell, a path or code | string-built SQL (`f"SELECT`, `+ user_input`), `eval`/`exec`, `subprocess(..., shell=True)`, `dangerouslySetInnerHTML`, input in `open()` / `Path()` |
| **Fail-open** | An error on a security path allows instead of denies | `except Exception: pass`, auth or parse failure falling through to success, a timeout that skips a check |
| **Secrets & PII** | A key, token or user data leaves where it belongs | keys in code or `.env*` committed; user PII in logs, errors, analytics or a third-party call |
| **Disabled safety** | A check turned off to make it work | `verify=False`, `--insecure`, CORS `*` on an authed route, a new `# noqa` / `type: ignore` on a security line |
| **New dependencies** | A package added without scrutiny | the lockfile moved with it; the name is the real package (typosquats); the ecosystem's audit advisories for it |

Severity: auth bypass, cross-tenant data exposure, injection or a committed
secret → **Critical**, fixed before done. Everything else → Important, with
`path:line` and the concrete attack in one line ("a member of org B reads
org A's records via `?org_id=`").

## Procedure

1. **Read the goal.** `scripts/goal show` (or `scripts/goal --debug show` for a bug fix) — the state reached, its forbids, and `git diff` for what actually changed. Note the headline behavior.
2. **Walk classes 1–7.** Record gaps in a table with severity (Critical / Important / Minor).
3. **Verify every `forbid` on the state.** Each one — was it actually respected?
4. **Production-entry trace.** Pick the real entry point (HTTP handler, queue consumer, CLI). Does the new code execute? At what depth?
5. **Fix Critical inline; punch-list Important/Minor.** Re-run build + tests after each fix.

## Output

```markdown
## Audit results

| # | Gap | Severity | Status |
|---|---|---|---|
| 1 | <one-line with file:line> | Critical | ✅ Fixed |

## What's now wired end-to-end

<entry point → ... → effect>

## Feature gate

<how it's gated, what flips it on>

## Remaining gaps (deferred)

- <gap>: <why deferred + when to revisit>
```

## Reference

Worked example (event-log focus stack, another repo). Implementation passed `go test ./...` cleanly and looked complete. This audit caught:

- **Class 1** — assembler `FocusScope` field added but `artist.go:129` never populated it. Feature unreachable.
- **Class 1** — `cmd/agent.go` never constructed the event registry. Wiring nil-safe-fallback to legacy.
- **Class 2** — local `entityNameKey` diverged from canonical `Slugify` for punctuation. Lookups silently missed entities like "Mr. Smith".
- **Class 3** — assembler filtered the text prompt; `artist.go:155` re-attached refs from `job.ReferenceImages` directly.
- **Class 4** — `Tail(6)` starved out the requesting session under concurrent workspace sessions.

Four Critical gaps in a feature that "looked done."
