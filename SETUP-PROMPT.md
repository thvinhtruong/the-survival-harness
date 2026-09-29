# One-shot setup prompt

Open Claude Code at the root of the target repo and paste everything below the
line. Change `HARNESS` if the template lives somewhere other than
`https://github.com/thvinhtruong/the-survival-harness`.

---

Install and adopt my goal-driven Claude Code harness in this repo.
HARNESS=https://github.com/thvinhtruong/the-survival-harness

**0. Preconditions.** This repo must be a git repo with a clean tree, and `jq`
must be installed. If the tree is dirty, stop and ask me. Don't commit anything.
I review and commit.

**1. Install.** Run `$HARNESS/install.sh "$(pwd)"`. It never overwrites anything.
Look at every `skip` line it prints:
- If `.claude/settings.json` was skipped, merge the `hooks` block from
  `$HARNESS/.claude/settings.json` into the existing file with `jq`. Keep the
  existing hooks and permissions. Without this step, none of the guards run.
- If `CLAUDE.md` exists, the template was saved as `CLAUDE.md.harness-template`.
  Merge its Doc map section and rules into the existing `CLAUDE.md`, keep the
  project's own content, then delete `CLAUDE.md.harness-template`.
- For any other skipped file, tell me what already existed. Don't replace it.

**2. Learn the repo before configuring it.** Read the manifests (package.json,
pyproject.toml, go.mod, Cargo.toml, pom.xml, etc.), the Makefile or task
runner, the CI workflows and the README. Find the real lint, type-check, build
and test commands. Take them from CI when CI exists, because CI shows what the
project actually enforces. Find any generated files: OpenAPI specs, schema
dumps, codegen output, lockfiles that a tool writes. Note the regenerate
command for each.

**3. Gates (`.claude/harness.conf` → `GATES`, and the `Makefile`).**
- Write one make target per gate, ordered from fastest to fail to slowest
  (usually `lint test`). Use `build` as well if the project has a compile step
  that lint doesn't cover.
- Each recipe runs the project's real commands. Its last line must be
  `@scripts/gate-record.sh <target>`.
- If there's no Makefile, create one that only wraps the existing commands. If
  there is one, add the record line to the existing targets and don't rewrite
  them.
- If a generated file has a `--check` or diff mode, call it from `lint`.
- Run every gate and show me the result. If a gate fails on the current tree,
  report it and don't fix it. If there are no tests at all, say so plainly: the
  gates are the only thing in the harness that stop bad work.

**4. `DOC_SYNC_CONTRACT_PATHS`.** Write an extended regex over repo-relative
paths where a change can break a documented contract: API routes and response
models, DB schema and migrations, the route table, design tokens, shared UI
primitives, public exported interfaces. Don't include services, internals or
tests. Adjust `DOC_SYNC_DOC_PATHS` if the docs live outside `docs/` and
`CLAUDE.md`.

**5. `GENERATED_FILES`.** Space-separated list of the files from step 2 that
must never be hand-edited.

**6. `GAP_AUDIT_EXTENSIONS`.** Trim or extend the list to the languages
actually present.

**7. Optional skills. Adopt each one only if it applies, otherwise leave it as a
`.template`.**
- `api-lookup`: adopt it if the repo generates an OpenAPI 3 JSON spec. Set
  `API_SPEC`, add the spec to `GENERATED_FILES`, rename `SKILL.md.template` to
  `SKILL.md` and fill every `{{…}}`.
- `verify`: adopt it if the project has a browser UI. Fill the launch commands,
  ports, health checks, prerequisites (env vars, services, seed) and 3–5 flows
  worth driving, using real values from the repo. Rename it to `SKILL.md` and
  set `BROWSER_VERIFY_SKILL="verify"`. If you can't determine a value from the
  repo, leave it as `{{TODO: …}}` and list it for me.

**8. `CLAUDE.md`.** Replace every `{{…}}`. Write one paragraph on what the
project is, its stack and how it splits. Build the Doc map with one row per real
code surface, using real globs and real regenerate commands. Keep the two
generic rows (product question, recurring bug). If the repo has no product doc,
delete the product row rather than inventing a path. Only list docs that exist.
If there's no known open work, delete that section.

**9. Verify.** Run all of these and paste the output:
- `.claude/hooks/test-guard.sh`: every line must PASS.
- `scripts/goal` prints its usage.
- `grep -rn '{{' CLAUDE.md .claude/ --include='*.md' --include='*.conf'` finds
  nothing outside the `.template` files, except TODOs you listed.
- `jq . .claude/settings.json` parses.

**10. Report.** End with a short table of each setting, its value and where the
value came from (file:line). Then list anything left as TODO and any gate that
is red on the current tree. Keep it brief.
