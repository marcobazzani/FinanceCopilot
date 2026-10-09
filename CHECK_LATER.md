# CHECK_LATER — suspicious findings during the code walkthrough

A running log of things that looked off while walking the codebase file by file.
These are **not confirmed bugs** — just things worth a second look. Each entry
cites the file + line so it can be verified independently.

---

## lib/main.dart

### 1. `_manualRefresh` doc-comment claims a Google Drive pull that never happens
- **Where:** `lib/main.dart:374-437`
- **What:** The doc comment reads *"Full manual refresh: pull from Google Drive,
  then refresh market data."* But the method body never touches the Drive sync
  service. It only: invalidates `currentDateProvider`, checks network, syncs
  market prices + FX rates, resyncs revalue-derived prices, and syncs
  compositions. There is no `googleDriveSyncProvider` / `restoreFromDrive` /
  `backupToDrive` call anywhere in the method.
- **Why it matters:** Either the comment is stale and misleading (the global
  Refresh button and mobile pull-to-refresh do NOT pull from Drive, contrary to
  what the comment implies), or a Drive-pull step was dropped and silently
  regressed. A maintainer reading the comment would assume a behavior that isn't
  there.
- **Severity:** Low (doc/behavior mismatch, not a crash).

### 2. Redundant/dead `if (_syncingDrive)` nested inside a branch already guarded by it
- **Where:** `lib/main.dart:499-518` (inner check at `:505`)
- **What:** Line 499 renders a `Padding` only when `_syncingDrive` is true
  (`if (_syncingDrive) Padding(...) else ...`). Inside that same `Padding`,
  line 505 checks `if (_syncingDrive) ...[` again — but execution can only reach
  line 505 when `_syncingDrive` is already true, so the inner condition is always
  true (dead conditional).
- **Why it matters:** Harmless at runtime, but confusing dead code; a reader
  assumes the two states differ. Likely a leftover from an earlier refactor.
- **Severity:** Trivial (cosmetic / dead code).

---

## lib/database/tables.dart

### 3. Dead / dormant schema — three tables + one feature defined but never used
Verified by grepping `lib/services/` and `lib/ui/` (ignoring the generated
`database.g.dart` and the table registration in `database.dart`):

- **`HealthReimbursements`** (`tables.dart:332-346`) — a full 14-column table.
  ZERO references anywhere except its definition and generated code. No service,
  no UI, no query. Completely dead.
- **`AssetSnapshots`** (`tables.dart:266-282`) — referenced only by two
  DELETE-cascade calls in `asset_service.dart:132,141`. Nothing ever INSERTs or
  SELECTs from it, so the only code touching it deletes rows that are never
  created. Effectively dead (write-never, read-never).
- **`AutoCategorizationRules`** (`tables.dart:208-215`) + the transaction
  categorization system (`Categories`, `Transactions.categoryId`,
  `Transactions.expenseType`, `Transactions.isEssential`) — `.categoryId` and
  `autoCategorizationRules` have no references in `lib/services/` or `lib/ui/`.
  The whole "auto-categorize transactions" feature is defined in the schema but
  not wired to any code path.
- **Why it matters:** ~4 tables' worth of schema (plus columns) is carried
  through every migration and merge but delivers no feature. It bloats the DB
  surface, confuses new readers ("where's the categorization UI?"), and the
  cross-DB merge logic still copies these tables. Candidate for removal OR a
  note that they're reserved for a planned feature.
- **Severity:** Low (no incorrect behavior; maintainability / dead-weight).

### 4. Legacy `AssetType` enum: superseded by InstrumentType + AssetClass, still required & mirrored
- **Where:** `tables.dart:15-29` (enum), `tables.dart:222` (required column, no default)
- **Confirmed leftover:** `database.dart:235` (migration v21) backfills the newer
  `instrument_type` / `asset_class` columns FROM the pre-existing `asset_type` —
  i.e. `AssetType` is the ORIGINAL taxonomy; `InstrumentType` + `AssetClass` were
  added later to replace it.
- **The naming smell (user-spotted):** `AssetType` crams TWO dimensions into single
  values — the wrapper AND the underlying: `stockEtf`, `bondEtf`, `commEtf`,
  `monEtf`, `goldEtc`. That is exactly the conflation the split fixed:
  `InstrumentType` = wrapper (etf/etc/bond/stock…), `AssetClass` = underlying
  (equity/fixedIncome/commodities/moneyMarket…). A bond ETF is one messy
  `AssetType.bondEtf` vs. the clean `InstrumentType.etf` + `AssetClass.fixedIncome`.
- **Still used, but as a legacy mirror:** written on every asset (required column,
  default `stockEtf` in `asset_service.dart:70`) and still has a UI dropdown
  (`create_dialog.dart:103`, `edit_dialog.dart:300`). BUT the newer pair is
  authoritative — `portfolio_rebalance_service.dart:712` `_defaultAssetTypeFor`
  DERIVES `AssetType` back FROM `(InstrumentType, AssetClass)`, and allocation /
  classification logic reads `instrumentType`/`assetClass` (~14 files) far more
  than `assetType` (~3 files).
- **Why it matters:** two parallel taxonomies on one row can silently disagree —
  nothing keeps the legacy `assetType` in sync when a user edits only
  instrumentType/assetClass (or vice-versa). Candidate for removal: derive it on
  the fly, then drop the column + its UI dropdown.
- **Severity:** Low → Medium (redundant source of truth for financial
  classification; the donuts trust the new pair, some code still trusts the old).

### 5. Minor: naming asymmetry + one unenforced foreign key
- `Accounts.includeInNetWorth` (`tables.dart:172`) vs `Assets.includeInSavings`
  (`tables.dart:239`) — sibling flags with different names (net-worth vs
  savings). **Resolved:** migration v42 (`database.dart:697-704`) renamed ONLY
  the assets column, on purpose, so the asymmetry is intentional (accounts feed
  net worth; assets feed savings). Leaving it here only as a readability footgun
  — the two similarly-purposed flags read as unrelated at a glance.
- `Buffers.linkedEventId` (`tables.dart:290`) is a bare `integer()` with only a
  comment saying it points at `ExtraordinaryEvents.id` — no real `.references()`
  constraint (unlike the reverse `ExtraordinaryEvents.bufferId`). Likely to avoid
  a circular FK, but means the DB won't catch a dangling link.
- **Severity:** Trivial → Low.

---

## lib/services/providers/app_state_providers.dart

### 6. Dead provider `appLanguageProvider` (+ never-written `LANGUAGE` config key)
- **Where:** `app_state_providers.dart:68-71`
- **What:** `appLanguageProvider` is a `StreamProvider<String>` reading the
  `LANGUAGE` key from `app_configs`. Grep shows it is referenced NOWHERE else in
  `lib/`, and the `'LANGUAGE'` config key is read ONLY here and written by
  nothing. The app's actual UI language comes from `portableLanguageProvider`
  (`:65`) → `appStringsProvider` (`:74`), seeded from a portable `settings.json`
  before the DB is even open.
- **Why it matters:** double-dead — a provider nobody watches, reading a key
  nobody writes. It's the vestige of an older DB-backed language scheme that was
  replaced by the portable-file approach. Confusing (a reader might think the DB
  drives language) and safe to delete.
- **Severity:** Low (dead code; no wrong behavior).

---

## lib/ui/widgets/privacy_text.dart

### 7. Nitpick: `PrivacyText` duplicates `PrivacyBlur`'s blur block instead of delegating
- **Where:** `privacy_text.dart:14-31` (`PrivacyBlur`) vs `:33-55` (`PrivacyText`)
- **What:** Both widgets independently `ref.watch(privacyModeProvider)` and wrap
  their child in the identical `ImageFiltered(ImageFilter.blur(...))`. `PrivacyText`
  could simply return `PrivacyBlur(child: Text(...))` and delete its own copy of
  the blur logic.
- **Why it matters:** only ~4 duplicated lines, BUT the project's own AGENTS.md
  rule is explicit — "Reuse > re-implement… the newer collapses into it via shared
  code." If the blur treatment ever changes (e.g. add a tint or a lock icon), it
  must be edited in two places. Trivial to collapse.
- **Severity:** Trivial (DRY nitpick, by the project's own standard).

---

## lib/services/domain/buffer_service.dart

### 8. `BufferTransaction.balanceAfter` — required column, computed-on-insert, never read, stale-on-backdate
- **Where:** written in `buffer_service.dart:90,101` (`createTransaction`); column
  declared NOT-nullable at `tables.dart:304`.
- **What:** `balanceAfter = computeBalance(bufferId) + amount` at insert, and
  `computeBalance` is an unordered `SUM(amount)` over the buffer — i.e. "grand
  total after adding this row." Grepping `lib/services/` + `lib/ui/` finds NO
  reader of a *buffer* transaction's `balanceAfter` (every `.balanceAfter` read is
  on account `Transaction`s in `account_detail_screen`/`transaction_edit_screen`).
  Unlike account balances, buffers have NO `recalculateBalances` equivalent.
- **Why it matters:** two smells at once — (a) a required column that is
  effectively write-only (dead data today), and (b) if a future screen ever shows
  it as a per-row running balance it's already wrong: a back-dated insert stores
  `grand_total + amount` (counting later-dated rows) and never re-computes
  siblings. Everything that actually needs a buffer balance goes through the live
  `computeBalance()` / `_totalReimbursed()` SUM (which is correct), making the
  stored column redundant.
- **Severity:** Low (dead write now; latent correctness trap if it's ever used).

---

## lib/version.dart

### 9. `appVersionDisplay` produces `0.0.0-dev-dev` on local builds (double suffix)
- **Where:** `version.dart:3-7`
- **What:** `appVersion` defaults to `'0.0.0-dev'` for local/dev builds, and
  `appVersionDisplay` appends `'-dev'` for the non-stable channel →
  `'0.0.0-dev-dev'` (visible bottom-left in the app screenshots). The file's own
  doc comment says nightly/local should read like `"0.4.4-dev"` (single suffix).
  On a CI release build the double-up doesn't happen (CI rewrites `appVersion` to
  a clean `0.4.4`), so it's local-only.
- **Why it matters:** purely cosmetic and clearly-not-a-release, but the doubled
  `-dev-dev` contradicts the documented format and looks like a bug at a glance.
- **Severity:** Trivial (cosmetic).

## lib/build_flags.dart

### 10. Stale doc comment: describes a DB-backed chart system that was removed
- **Where:** `build_flags.dart:14-22`
- **What:** The `debugChartsEnabled` doc says — Off: "DB seed for
  `dashboard_charts` skipped"; On: "DB-backed charts (with the JSON seed
  bootstrapping the table)." But the `dashboard_charts` table was DROPPED in
  migration v32 (`database.dart:493`), and charts are now purely JSON + in-memory
  (`service_providers.dart:39-41` literally says "no longer DB-backed";
  `editableChartsProvider` is an in-memory `StateNotifierProvider`).
- **Why it matters:** documentation rot — a maintainer reading this would believe
  there's a `dashboard_charts` table and DB seeding behind the debug flag, which
  hasn't been true for 16 schema versions.
- **Severity:** Low (misleading comment; behavior itself is fine).

---

## lib/app_shell/share_intent.dart

### 11. Android share-to-import silently drops PDFs, though PDF is a headline import format
- **Where:** `share_intent.dart:17`
- **What:** `_handleSharedFiles` only accepts `{'csv','xlsx','xls','tsv'}`; any
  other extension is logged as "unsupported type" and ignored. But PDF *is* a
  fully-supported import format everywhere else (`file_parser_service` has a whole
  `_parsePdfMain` path + the `PdfTableReconstructor`, and the in-app import wizard
  accepts PDFs).
- **Why it matters:** sharing a bank-statement PDF from a banking app / email /
  Files — arguably the most natural mobile import gesture — is silently dropped
  with only a log line. Inconsistent with the in-app picker, and a real UX gap for
  the app's flagship PDF-import feature. (Either intentionally out of scope, in
  which case it deserves a comment, or an oversight.)
- **Severity:** Low (feature gap / inconsistency; no data risk).

---

## lib/services/import/ (config + parsing support)

### 12. Hash-based import dedup is fully vestigial (`importHash` columns + `hashColumns` config all unused)
- **Where:** columns `Transactions.importHash` (`tables.dart:204`) & `AssetEvents.importHash`
  (`tables.dart:262`); config `ImportConfigs.hashColumnsJson` (`tables.dart:388`)
  written by `import_config_service.dart:77-138`.
- **What:** the config service still accepts/stores a `hashColumns` list, but a grep
  of `lib/services/import/` shows the ONLY `importHash`/`hashColumns` references are
  in `import_config_service` (which merely persists the config). Nothing ever WRITES
  the `importHash` columns during import, and nothing READS `hashColumns` for
  deduplication. (Repo-wide, the only other hits are the schema, migrations, and
  generated `database.g.dart`.) The real dedup is wipe-and-replace by date cutoff
  in `import_service`.
- **Why it matters:** a whole "hash rows for dedup" mechanism is implied by the
  schema + config surface but not implemented — a maintainer could wrongly assume
  imports are hash-deduplicated. Two nullable columns + one config field are carried
  through every migration and DB-merge for nothing. (Related to finding #3's dead
  schema, but specifically about the dedup mechanism.)
- **Severity:** Low (dead schema/config; the actual date-based dedup works).
- **Reinforced (import_service.dart):** the class doc (`:145`) still claims it
  "hashes rows for dedup", and `_ParsedTransactionRow.hash` (`:1052`) is a field
  ALWAYS set to `null` (`:416`) and never read — the leftover of the removed
  hashing scheme.

### 13. `_evaluateFormula`'s doc comment is torn in half by a mis-paste
- **Where:** `import_service.dart:203-229`
- **What:** the doc comment that belongs to `_evaluateFormula` starts at line 203
  ("Evaluate a formula: sum of terms…"), but `_computeBalanceDiffs`'s own doc +
  its entire method body (`:207-226`) are spliced into the MIDDLE of it. The
  result: `_computeBalanceDiffs` (line 213) is now documented by
  "Evaluate a formula…", and `_evaluateFormula` (line 229) is left with only the
  dangling tail fragment "row's amount surfaces as missing…" (line 228).
- **Why it matters:** classic botched-refactor artifact — a method was pasted into
  another method's doc comment. No behavior impact (Dart attaches each comment to
  the next declaration), but both functions are now mis-documented and confusing.
- **Severity:** Low (documentation corruption; behavior fine).

### 14. Preview and real import duplicate parsing/type/fee logic (a drift hazard that already bit once)
- **Where:** `asset_import_flow.dart` — `importAssetEventsGrouped` (`:68`) vs
  `previewAssetEventImport` (`:740`).
- **What:** the dry-run preview re-implements, in parallel, the same external-fee
  pre-pass (`:200-218` vs `:817-830`), sign-based buy/sell inference
  (`:433-438` vs `:872-877`), and date/amount validation as the real import.
  Shared helpers were extracted for the two trickiest bits (`autoCalcAmountFor`
  `:62`, `_parseEventType` in import_service), but the surrounding orchestration
  is copy-pasted.
- **Why it matters:** the file's OWN comment (`:58-60`) documents that this exact
  duplication already produced a bug — the preview "used to ignore `price`
  entirely and infer buy/sell from the quantity sign alone, so it could classify a
  row differently from the import it was previewing." The remaining duplicated
  logic can drift again. The project's AGENTS.md explicitly forbids duplicating
  business logic ("defined once and reused").
- **Severity:** Low → Medium (correctness-adjacent: a preview that disagrees with
  the import it previews defeats the purpose of the dry run).

---

## lib/app_shell/app_navigator.dart

### 15. Doc comment references a non-existent "AI chat overlay"; the navigator key's stated purpose is moot
- **Where:** `app_navigator.dart:3-8`
- **What:** the doc for `rootNavigatorKey` says: *"The AI chat overlay is rendered
  in `MaterialApp.builder` — above the Navigator … This key lets it reach a
  Navigator context."* But `main.dart`'s builder (`:111`) is just a `SafeArea` —
  there is NO AI chat overlay anywhere in `lib/` (grep for chat/overlay/aiChat is
  empty). And `rootNavigatorKey` is only ever *assigned* (`main.dart:81
  navigatorKey: rootNavigatorKey`); nothing reads `.currentState`/`.currentContext`
  to "reach a Navigator", so its documented reason to exist is gone.
- **Why it matters:** points to a planned-or-removed "AI chat" feature. The comment
  misleads a reader into hunting for an overlay that isn't there; the key remains
  wired to `MaterialApp` (harmless) but serves none of its stated purpose.
- **Severity:** Low (doc rot + effectively-purposeless key).
