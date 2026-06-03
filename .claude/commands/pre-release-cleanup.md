---
description: Long-running pre-release sweep — branch/DB sanity, UI consistency, dedup, silent-default eradication, locale enforcement, date semantics, LoC reduction, Dart best-practices audit, dead code, provider-name leak check, bug hunt loop. Run before every major release.
---

Mission: harden the codebase before a major release. Long-running and exhaustive — keep iterating until a full pass produces zero findings in every phase. Behavior must be preserved unless a phase explicitly fixes a bug (in which case a failing test must exist first). Read the project guidelines file (`AGENTS.md`, or `CLAUDE.md` if that is what the repo uses) in full before starting.

Do not hardcode-trust the paths/filenames mentioned in this command — the codebase refactors over time. Treat every path below as a hint, not a guarantee: if a referenced file does not exist, locate the current equivalent by its role (grep/glob for the canonical implementation) and proceed. The phase intent is authoritative; the example path is not.

## Phase 0 — Sanity gate (do once, never skip)
1. Confirm current branch is `develop` (or whatever target the user specified). If not, STOP and ask.
2. Confirm `DB_FILE_NAME` in `.env` matches the intended dev DB. Never let tests/builds touch the user's real production DB (the sandboxed app DB — see the "Database & Sandbox" section of the guidelines file for the current per-platform location). Tests/builds must always run against a disposable dev/test DB.
3. Capture green baseline (all four MUST pass before proceeding). Integration runs MUST target the disposable test DB — never the dev/real DB:
   - `dart fix --apply && dart analyze lib/ test/ integration_test/`  (zero warnings/infos)
   - `flutter test`
   - `flutter test integration_test/all_tests.dart -d macos --dart-define=DB_FILE_NAME=finance_copilot_test.db`
   - `flutter test integration_test/live_data_fetch_test.dart -d macos --dart-define=DB_FILE_NAME=finance_copilot_test.db`
   (If the test entrypoints have been renamed, discover the current ones under `integration_test/` before running. Always pass `DB_FILE_NAME=finance_copilot_test.db` — integration tests delete that file.)
4. Record starting LoC: `find lib -name '*.dart' -not -name '*.g.dart' | xargs wc -l | tail -1`.
5. If anything in step 3 is red, STOP — fix the existing red before this command can do anything else.

## Phase 1 — UI consistency audit (report only, no edits)
Catalog every instance of these patterns and flag deviations from the canonical reference:
- **Delete affordances**: trashcan icon in detail view + swipe-to-delete in lists is canonical. Any long-press-to-delete is a violation. Any three-dot menu offering delete must be reconciled.
- **Collapsible cards**: chevron + header layout MUST match the canonical Cash Flow tab implementation (currently `lib/ui/screens/dashboard/cashflow_tab.dart`; if renamed/split, find it by role). Header must NOT change on expand/collapse; expand must scroll smoothly, not snap.
- **Wizard "Next" button bars**: must use one shared widget, not per-screen reimplementations.
- **Empty states**: same icon + tagline pattern across screens.
- **Error toasts / snackbars**: same component, same placement.
Output: a markdown table of `screen | pattern | canonical? | action`. Then proceed to fix only the ones that are clear-cut; leave ambiguous ones for the user.

## Phase 2 — Duplication kill (pinning test required)
For each suspected duplication:
1. Grep for the duplicated function body / widget tree / SQL fragment.
2. Identify the older / canonical implementation. The older one wins; the newer collapses into it.
3. Write a pinning test that captures current behavior of BOTH sites.
4. Extract to a single shared utility / service method / widget.
5. Re-run the pinning test — must pass with byte-identical output.
NEVER copy/paste. NEVER start a new implementation when one exists — fit into the current codebase.

## Phase 3 — Silent-default eradication
Hunt and fix every silent fallback that hides incorrect financial data:
- Every `?? <number>` in money/FX/quantity paths.
- Every `try/catch` in conversion code that returns the original amount on failure.
- Every `return amount` after a failed FX lookup.
- Every per-asset price fallback (FORBIDDEN — missing price → asset shows "—" and is excluded from totals with a footnote count).
For each: replace with one of (a) surface to user via visible indicator + log warning, (b) skip the calculation entirely, (c) propagate the error. NEVER hide.

## Phase 4 — Locale enforcement
1. Grep for literal user-visible text in `lib/ui/`:
   `grep -rEn "Text\\(['\"]" lib/ui/ | grep -v AppStrings | grep -v '//'`
   Every hit must move to `AppStrings` / l10n.
2. Grep for hardcoded decimal-separator parsing (`.replaceAll('.', '')`, `.split(',')` on numbers, `double.parse` on un-normalized strings). Replace with locale-aware `NumberFormat(localeTag).parse()`.
3. Grep for hardcoded date format strings (`DateFormat('dd/MM/yyyy')` without locale arg). Route through `lib/utils/date_parser.dart`.
4. Verify all l10n bundles (en, it, …) cover every key — no missing translations.

## Phase 5 — Date semantics audit
1. List every `Date` column in `lib/database/tables.dart`. For each, classify as `valueDate`-style or `operationDate`-style.
2. Grep every consumer (queries, widgets, charts). Verify display/sort/charts use `valueDate`. `operationDate` may ONLY appear in import dedup cutoff logic.
3. Confirm `assetEvents` and `incomes` tables both have a populated `valueDate` column. If not — bug. Add a failing test, then fix.

## Phase 6 — LoC reduction (no behavior change)
Tests are NOT in scope for shrinking. Each pass:
- Collapse remaining duplicated logic into single source of truth.
- Inline one-shot helpers used only once.
- Replace verbose `if/else` chains with expression form, `switch`, or collection methods where it stays readable.
- Remove unreachable branches and redundant null checks where the type system already proves non-null.
- Prefer one Drift SQL statement over a Dart loop that re-queries.
- Merge near-identical widgets behind a parameterized constructor ONLY when the result is genuinely smaller AND clearer.
Forbidden:
- Touching tests to make them pass.
- Renaming public APIs without grep-verifying every caller.
- Refactors without a pinning test (per CLAUDE.md).

## Phase 7 — Dart best-practices audit
Run code against Dart/Flutter idioms. Each finding fixed must keep all four suites green. Avoid blanket refactors — fix the cluster, re-run tests, move on.

1. **Tooling baseline**:
   - `dart fix --apply` and `dart format .` produce zero residual diffs.
   - `analysis_options.yaml` includes the project's chosen lint set (currently `flutter_lints`) and `dart analyze` is clean under it. Do NOT add a stricter lint package (e.g. `package:lints/recommended.yaml`) as part of this sweep unless the user explicitly asks — that is a separate, opt-in decision, not a pre-release fix. No `// ignore:` line lacks an inline justification comment.
2. **Null-safety hygiene**:
   - Grep `\\![\\s\\.\\[\\(]` in `lib/` — every bang operator on a nullable must justify why null is impossible; otherwise rewrite with `?.`, `??`, `case ... when`, or an explicit guard.
   - No `late` without a comment explaining the init contract; replace with `?` + null-check when feasible.
3. **Const correctness**: every `StatelessWidget` constructor with only compile-time-constant fields must be `const`. Widget literals at call sites must be `const` when all args are constant. Dart analyzer's `prefer_const_constructors` and `prefer_const_literals_to_create_immutables` must be on and clean.
4. **Final / var discipline**: locals never reassigned should be `final`. Top-level/class fields never reassigned should be `final` or `const`.
5. **Type clarity**: zero `dynamic` in production code unless interfacing with `Object?` from JSON or platform channels (and then immediately narrowed). No untyped `Map`/`List` literals — always `Map<K,V>` / `List<T>`. Replace stringly-typed flags with enums.
6. **Logging**: zero `print(` in `lib/` — route through the project logger. `debugPrint` only in dev-only paths.
7. **Async hygiene**:
   - Every `Future`-returning call is `await`ed or wrapped in `unawaited(...)`.
   - No `async` function without an `await` inside.
   - Independent awaits in loops → `Future.wait`.
   - No `Timer`/`Future.delayed` longer than 10s in product code (per CLAUDE.md).
8. **Resource hygiene**: every `TextEditingController`, `ScrollController`, `AnimationController`, `FocusNode`, `StreamSubscription`, `Timer`, and `OverlayEntry` is disposed in `dispose()` / `onDispose`. Riverpod providers use `ref.onDispose` for non-AutoDispose-managed resources.
9. **Cast safety**: prefer `is`-checks + smart promotion over `as` casts. Remaining `as` must be on values where the type is provably correct (document it).
10. **Widget hygiene**:
    - Stable keys on every dynamically-built list child.
    - Builders never trigger setState during build.
    - No `BuildContext` use across an async gap without a `mounted` check.
11. **Equality & hashing**: every value type that overrides `==` also overrides `hashCode` (and vice versa). Prefer `Equatable` or generated equality only where it earns its keep.
12. **Lint diffs**: after fixes, `dart analyze` is clean and the diff is reviewed for accidental behavior change. Add a pinning test for anything non-trivial (per CLAUDE.md).

## Phase 8 — Dead code sweep
"Unused" is a CLAIM that must be verified by grep across `lib/`, `test/`, `integration_test/`, `tool/`, l10n keys, AND `pubspec.yaml` assets.
Hunt and delete:
- Functions/classes/widgets/files with zero references.
- Private members never read.
- Unused imports, unused parameters, unused locals.
- Unreachable code after `return`/`throw`.
- **Dead enums and dead enum values**: any enum or enum case never constructed AND never matched against. For each enum, list cases and prove each is either produced or consumed; delete the rest and the switch arms that handled them.
- Dead Riverpod providers, dead `AppStrings` keys, dead theme tokens, dead `pubspec.yaml` assets.
- Commented-out code blocks.
NEVER add `// removed` markers or backwards-compat shims.

## Phase 9 — External provider name leak check
`grep -rEn -i "investing|yahoo|google\\.finance|<other provider names>" README* CHANGELOG* lib/ test/ integration_test/ tool/ .github/ ios/ android/ macos/ windows/ linux/ web/` — must return zero hits. Replace any with generic terms ("market data provider", "composition data"). Also check screenshots' alt text and OG metadata.

## Phase 10 — Bug hunt loop (until exhausted)
Loop until a full pass yields no new findings:
1. Re-read recent diffs from this session.
2. Run analyzer + all four test suites; investigate every warning/info.
3. Look for the recurring failure modes in this project:
   - Silent financial fallbacks (re-check Phase 3 territory).
   - `operationDate` vs `valueDate` confusion.
   - Missing localization (re-check Phase 4 territory).
   - Async race conditions / missing `await`.
   - Off-by-one in date ranges, timezone drift.
   - Resource leaks: undisposed controllers/streams/subscriptions.
   - Drift migrations that assume schema state.
   - Platform-specific path drift (macOS sandbox vs Windows `%AppData%` vs Android `/data/data/`).
   - Wrong-DB targeting in tests/builds.
4. For each suspected bug:
   a. Write a failing unit OR integration test that reproduces it (TDD).
   b. Fix the code, NOT the test.
   c. Re-run all four suites — must be green.

## Phase 11 — Overreach review
Re-read the full diff of this run (`git diff <baseline-commit>..HEAD`). For every new file, abstraction, parameter, or class:
- Is there a current call site that strictly needs it? If no → inline or revert.
- Does it duplicate something Phase 2 missed? If yes → collapse.
- Is it more complex than the simplest thing that works? If yes → simplify.
"keep it simple", "fit my requests in the current app" — these are non-negotiable.

## Phase 12 — Verify & report
- Run all four suites — must be green.
- Compute LoC delta vs baseline.
- Print a final report:
  - Files touched, LoC removed
  - Dead symbols / enums / providers / l10n keys / assets deleted (counts + names)
  - Locale violations fixed (count + locations)
  - Duplications collapsed (count + canonical target)
  - Dart best-practice fixes (count + categories: null-bangs, missing-const, dynamic, print, async, dispose, casts)
  - Bugs fixed (with reproducing test names)
  - Provider-name leaks removed (count)
  - UI inconsistencies reconciled (count + screens)
  - Next candidate areas for the following pass
- Do NOT commit. Do NOT push. Wait for explicit approval.

## Hard rules (non-negotiable)
- NEVER modify or delete an existing test to make it pass.
- NEVER skip a test suite or commit with red.
- NEVER add `Co-Authored-By` to commits.
- NEVER bump `lib/version.dart` (auto-stamped from git tag).
- NEVER use `--no-verify`, `--break-system-packages`, `git add -A`, or `git push --tags`.
- NEVER mention external data providers by name (anywhere — code, docs, comments, CI, screenshots).
- NEVER start from scratch when a similar implementation already exists. Fit into the current codebase.
- NEVER target the wrong branch or DB. Confirm both before any edit.
- Build → kill → launch ordering for app runs.
- Stop and ASK before any destructive git op.
- Never sleep > 10s in any command. Long tasks → background + poll.

## Stopping condition
A full pass through all 12 phases yields:
- Zero UI inconsistencies left to reconcile,
- Zero duplications left to collapse,
- Zero silent defaults in money paths,
- Zero locale violations,
- Zero date-semantics confusion,
- Zero further LoC reductions that preserve clarity AND behavior,
- Zero Dart best-practice violations (bangs, missing-const, dynamic, print, async, dispose, casts),
- Zero dead symbols,
- Zero provider-name leaks,
- Zero new bugs,
- Zero overreach in the diff.
Then report final totals and stop.
