# Open GitHub issue triage and execution plan (branch `gh_issues`)

Evaluated 2026-09-10 against `main` at `d724201`. Every open issue was read and
checked against the code; the "Validity" column records what the code actually
showed. Priority drives the execution order below. Status is updated as work
lands on this branch.

| # | Title (short) | Valid? | Priority | Decision |
|---|---------------|--------|----------|----------|
| 15 | `mix test` red on clean checkout; debug scripts in `test/` | Yes. `test/support/{data_case,conn_case}.ex` were missing; 9 scratch scripts in `test/`; `mix format` failed on `config/prod.exs` | P0 | Work |
| 14 | Build artifacts / scratch files tracked; `.gitignore` gaps | Yes. `bindocsis` escript (4.5 MB), `bindocsis.db`, `json`, two `.DS_Store`, two root scratch `.exs` tracked | P0 | Work |
| 10 | Prod `check_origin: false` | Yes. `config/prod.exs` disables the origin check for the cookie-session LiveView app on Fly | P1 (security, trivial) | Work |
| 11 | `String.to_atom` on user input; unguarded `String.to_integer` | Yes. 1 atom-table leak, ~20 crash sites across four LiveViews | P1 (security) | Work |
| 12 | Upload pipeline: `accept: :any`, `File.read!`, unbounded ETS | Yes. All three verified | P1 (security) | Work |
| 13 | Auth: open registration, magic-link enumeration, no rate limit | Yes. Enumeration message already fixed in the working tree; registration gate and throttling absent | P1 (security) | Work |
| 5 | Binary parser drops tails / ignores validator | Partly. Mid-stream truncation already errors; a lone trailing byte, a non-TLV byte after a 0x00, and a 0xFF-with-trailing-bytes are swallowed; validator result is discarded | P1 (correctness) | Work |
| 9 | MTA parser fabricates zero-length TLV on `0x84` | Yes. Two heuristic branches emit a TLV that consumed 1 wire byte and re-encodes as 2 | P1 (correctness) | Work |
| 8 | Silent value rewrites (int widen/truncate, zero-pad, MIC tuple) | Yes. All three verified; `parse/2` `@spec` contradicts the MIC error shape | P1 (correctness) | Work |
| 7 | JSON/YAML round-trip: parent `formatted_value`, size math, hex heuristic | Yes. Enricher + YAML emit `formatted_value` on parents; both generators use a 1-or-2-byte length size; the JSON hex heuristic can rewrite unenriched `:string` values | P1 (correctness) | Work |
| 6 | ConfigParser names contradict DocsisSpecs; divergent length encoding | Yes, and worse than reported: the parser and generator each carry a hand-written table, they disagree with each other and with the spec (e.g. parser `cmic=>9`, generator `9=>NTPServer`; spec: 9 = SW Upgrade Filename), and nested compounds cannot round-trip | P1 (spec compliance) | Work. Breaking change to the text config format; documented in CHANGELOG |
| 16 | Release/docs/CI hygiene | Yes. Version drift (0.11.0 / v0.8.1 / v0.7.0 / config `0.9.0`), stale CHANGELOG, no test CI, SQLite without WAL/busy_timeout | P2 | Work, except the dependency-update pass (deferred, see below) |
| 17 | Feature: full-screen TUI | Already shipped: Phases 1+2 committed in `676c812`, Phase 3 declined by the maintainer in the issue thread | Done | Defer: nothing left to build; close the issue |

## Execution order

1. #15 + #14 — make the suite green on a clean checkout, drop artifacts.
2. #10, #11, #12, #13 — web/security hardening (small, independent).
3. Shared TLV length codec (`Bindocsis.TlvLength`) — prerequisite for #6 and #7.
4. #5, #9, #8, #7, #6 — parser / round-trip correctness.
5. #16 — version, CHANGELOG, CI workflow, SQLite pragmas.
6. Full suite, `mix format`, update this document.

Each issue lands as its own commit referencing the issue number.

## Deferred items and why

- **#17**: implemented and merged before this branch (`676c812`); Phase 3
  declined by the maintainer. No work remains. Recommend closing.
- **#16 dependency-update pass** (`bandit`, `phoenix`, `swoosh`, `ecto_sqlite3`):
  a lock-file bump is not reviewable alongside behavioural fixes and needs
  its own verification run against the Fly deployment. Left for a dedicated
  follow-up PR; `mix hex.outdated` output is recorded below.
- **#16 dialyzer in CI**: `dialyxir` is a dev dependency but the project has
  no PLT or baseline; adding it to CI would start red. The workflow added
  here runs `mix test` and `mix format --check-formatted`.
- **#12 spill-to-disk/SQLite for uploads**: the issue offers this as an
  alternative to caps. Caps plus LRU eviction fully address the memory
  exhaustion; persisting uploads is a product decision (they are explicitly
  temporary today) and is not done here.
- **#13 admin role**: the issue offers "allowlist / admin role" as
  alternatives. An allowlist (plus a registration on/off switch) is
  implemented; a role model would need schema changes and UI and is not
  required to close the exposure.

## Status (2026-09-10, end of branch)

| # | Status | Commit(s) |
|---|--------|-----------|
| 15 | Done: suite green on a clean checkout (`mix test` creates/migrates `bindocsis_test.db`), debug scripts removed, tree formatted | `5938dd9`, `7377381` |
| 14 | Done: artifacts untracked, `.gitignore` extended | `5938dd9` |
| 10 | Done: `check_origin: :conn` + `CHECK_ORIGIN` override, config-level guard test | `e2d0754` |
| 11 | Done: `BindocsisWeb.Params`, all `String.to_integer/to_atom` call sites replaced, LiveView tests | `333aa87` |
| 12 | Done: accept list + server-side check, `File.read`, bounded `ConfigStore` (entries/bytes/per-owner, LRU), parse failures rejected | `3af9d1a` |
| 13 | Done: registration policy (open/closed/allowlist), ETS rate limiter on login/magic-link/registration/uploads, uniform magic-link reply | `5938dd9` (message), `5c556eb` |
| 5 | Done: validator honoured, trailing byte / post-terminator garbage are errors | `cba88f9` |
| 9 | Done: no fabricated zero-length TLVs; malformed fixture asserted rejected | `cba88f9` |
| 8 | Done: range errors instead of widen/truncate, unenrich honours edits, MIC string error | `cba88f9` |
| 7 | Done: no parent `formatted_value`, correct size math via `TlvLength`, string values never hex-rewritten | `cba88f9` |
| 6 | Done: `ConfigNames` + parser/generator rewrite, byte-exact round trips, docs updated. **Breaking** for existing `.conf` files using the old fabricated names | `58a898f` |
| 16 | Done except deps update: version-derived doc links, CHANGELOG rewritten (0.8-0.11 + Unreleased), README claim reconciled, `elixir.yml` CI (format + test), SQLite WAL + busy_timeout | see final commit |
| 17 | No work: already shipped in `676c812`; Phase 3 declined by maintainer. Recommend closing | — |

Final `mix test`: see the commit message of the last commit on this branch
for the count. `mix format --check-formatted` passes.

### `mix hex.outdated` at branch time (2026-09-10)

| Dependency | Current | Latest | Status |
|------------|---------|--------|--------|
| bandit | 1.9.0 | 1.12.5 | update possible |
| dns_cluster | 0.1.3 | 0.3.0 | update not possible (requirement `~> 0.1.1`) |
| ecto_sql | 3.13.4 | 3.14.0 | update not possible |
| ecto_sqlite3 | 0.22.0 | 0.24.1 | update possible |
| finch | 0.20.0 | 0.23.0 | update possible |
| jason | 1.4.4 | 1.4.5 | update possible |
| phoenix | 1.8.3 | 1.8.13 | update possible |
| phoenix_live_view | 1.1.19 | 1.2.11 | update possible (minor bump) |
| swoosh | 1.20.0 | 1.28.0 | update possible |
| yaml_elixir | 2.11.0 | 2.12.2 | update possible |
| benchee / dialyxir / ex_doc (dev) | 1.5.0 / 1.4.5 / 0.38.2 | 1.5.1 / 1.4.8 / 0.40.4 | update possible |

### Recommended follow-ups (not done here)

- Dependency update pass (`bandit`, `phoenix`, `phoenix_live_view` 1.2,
  `swoosh`, `ecto_sqlite3`, `finch`, `yaml_elixir`) with a deploy
  verification on Fly. `dns_cluster` and `ecto_sql` report "update not
  possible" under the current requirements.
- Set `REGISTRATION_MODE=closed` (or `allowlist`) on the public Fly
  deployment; the default stays `open` to preserve current behaviour.
- The `ValueFormatter`/`ValueParser` pair disagrees for
  `:power_quarter_db` (formats `58.0 dBmV`, parser range is -32..31.75);
  the config generator falls back to hex for such values. Worth a spec
  check of the signed/unsigned interpretation.
- `mix compile` prints Elixir 1.20 type warnings from HEEx templates and a
  few dead clauses in `json_generator.ex`; `--warnings-as-errors` cannot be
  enabled in CI until those are cleared.
