# FinanceCopilot

A personal wealth management desktop app built with Flutter. Replaces spreadsheet-based tracking with a reactive, offline-first platform backed by a local SQLite database — no cloud accounts, no subscriptions.

Track net worth over time, manage multi-currency portfolios, import bank and broker exports, and monitor investment performance across accounts, stocks, ETFs, and funds.

## Screenshots

### Dashboard — Charts
Price changes table with period selector (1d–All), followed by a combined Totals chart and individual breakdowns (Total Assets, Cash, Saving, Invested). Series are populated automatically from all active accounts, assets, and adjustments.

![Dashboard Charts](docs/screenshots/dashboard.png)

### Dashboard — Allocation
Portfolio breakdown across geographic regions, sectors, asset types, currencies, top holdings, and concentration risk — aggregated automatically from per-asset composition data fetched from justETF and stockanalysis.com.

![Allocation](docs/screenshots/allocation.png)

### Asset Detail
Per-asset composition (asset class, geographic split, sector weights, top holdings) fetched weekly from justETF (ETFs/ETCs) or stockanalysis.com (stocks), with full buy/sell/dividend event history.

![Asset Detail](docs/screenshots/asset_detail.png)

### CSV / Excel Import
Flexible column mapping for any bank or broker export. Supports bank transactions, asset events (buy/sell/dividend), and income records. Re-importing the same file deduplicates automatically.

![Import](docs/screenshots/import.png)

## Features

### Dashboard
Six fixed charts, each dynamically populated from all active accounts, assets, and adjustments — no manual series configuration needed:

| Chart | Content |
|-------|---------|
| Price Changes | Daily price movements per asset with period selector |
| Totals | Combined total lines from all charts below |
| Total Assets | All accounts + all asset market values + spread adjustments |
| Cash | All accounts + spread adjustments |
| Saving | All accounts + all invested assets + all adjustments |
| Invested | All invested assets |

Charts support drag-to-zoom (2D rectangular selection), series toggle, component hide/show, and resizable height.

The Allocation tab shows geographic, sector, asset-type, currency, holdings, and concentration risk breakdowns aggregated across the whole portfolio.

### Assets
Unified model for all holding types — stocks, ETFs, ETCs, crypto, real estate, pension funds, liabilities — via timestamped buy/sell/dividend events. Market values are synced from Investing.com (with automatic Cloudflare bypass via embedded headless WebView) or optionally from Google Sheets via GOOGLEFINANCE. Composition data (geographic, sector, holdings breakdown) is fetched weekly from justETF for ETFs and stockanalysis.com for stocks.

### Accounts
Multi-account balance tracking across banks, brokers, and crypto platforms. Balances are derived from imported transactions with running `balance_after` totals.

### Adjustments
Two types of recurring financial adjustments:

- **Spread adjustments** — Amortise a large purchase over time (e.g. spread a €12,000 car purchase over 36 months). Appears in Cash, Saving, and Total Assets charts.
- **Income adjustments** — Subtract a lump-sum income item and add it back gradually (e.g. a €10,000 bonus spread quarterly). Appears in Saving chart only.

Both support configurable step frequency (weekly, monthly, quarterly, yearly) and are linked to account buffers for cash-flow tracking.

### Import
CSV and Excel import with saved column mappings per source. Imports bank transactions, asset events, and income records. SHA-256 deduplication prevents double-counting on re-import.

### Multi-Currency
FX rates for 13 currencies (EUR, USD, GBP, CHF, JPY, SEK, NOK, DKK, PLN, CZK, HUF, CAD, AUD) synced from the Frankfurter API (ECB data) with full daily history from 1999. All values converted to the configured base currency for display.

### Income
Track income events and income adjustments separately from account transactions.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter / Dart ^3.8.1 |
| State management | Riverpod 2 |
| Database | Drift (SQLite ORM), 22 tables, schema v19 |
| Charts | fl_chart |
| HTTP | Dio |
| HTML parsing | html (DOM traversal) |
| Cloudflare bypass | flutter_inappwebview (headless WebView) |
| Import | csv, excel (git), file_picker |
| Localisation | intl — en_US, en_GB, it_IT, de_DE, fr_FR, es_ES |

## Project Structure

```
lib/
├── main.dart                        # App shell, navigation, settings dialog
├── version.dart                     # Version constant (0.1.45)
├── database/
│   ├── database.dart                # Drift DB definition, migrations v1→v19
│   ├── tables.dart                  # 22 table definitions and enums
│   └── providers.dart               # Database Riverpod provider
├── services/
│   ├── providers.dart               # All Riverpod service/stream providers
│   ├── asset_service.dart           # Asset CRUD
│   ├── asset_event_service.dart     # Buy/sell/dividend events
│   ├── composition_service.dart     # ETF/stock composition fetcher
│   ├── exchange_rate_service.dart   # FX rates (Frankfurter API)
│   ├── market_price_service.dart    # Abstract price service interface
│   ├── investing_com_service.dart   # Investing.com + Cloudflare bypass
│   ├── capex_service.dart           # Spread/income adjustment schedules
│   ├── buffer_service.dart          # Account buffer management
│   ├── import_service.dart          # CSV/Excel parsing and dedup
│   ├── income_service.dart          # Income records
│   └── ...
└── ui/
    ├── screens/
    │   ├── dashboard_screen.dart    # Charts + Allocation tabs
    │   ├── assets_screen.dart       # Asset list and detail
    │   ├── accounts_screen.dart     # Account list
    │   ├── capex_screen.dart        # Adjustments (Spread / Income)
    │   ├── income_screen.dart       # Income tracking
    │   └── import_screen.dart       # CSV/Excel import
    └── widgets/
```

## Getting Started

### Prerequisites

- Flutter SDK ^3.8.1
- Xcode (macOS builds)

### Build & Run

```bash
# Install dependencies
flutter pub get

# Generate code (Drift, Riverpod, JSON serialization)
dart run build_runner build --delete-conflicting-outputs

# Run in debug mode
flutter run -d macos

# Build release
flutter build macos --release
open build/macos/Build/Products/Release/FinanceCopilot.app
```

### Run Tests

```bash
flutter test
```

## Architecture

- **Offline-first** — All data lives in a local SQLite database; market data and composition are cached after sync and refreshed on a schedule.
- **Single source of truth** — All data flows through Drift; services are stateless query/mutation wrappers.
- **Reactive UI** — Riverpod `StreamProvider`s watch DB tables and rebuild widgets automatically on any change.
- **Asset-agnostic model** — No separate tables per asset type; a unified event model handles all holding types.
- **Pure Flutter/Dart runtime** — No Python scripts or external processes at runtime; the `.app` bundle is fully self-contained.

## License

MIT
