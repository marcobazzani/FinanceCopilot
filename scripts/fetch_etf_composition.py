"""
Fetch ETF composition (countries + sectors + top holdings) from justETF.

Usage:
  # JSON output only
  python fetch_etf_composition.py IE00B4L5Y983,IE00BKM4GZ66,...

  # Fetch from DB assets and write back to asset_compositions table
  python fetch_etf_composition.py --db /path/to/asset_manager.db
"""
import json
import sqlite3
import sys
import time
from playwright.sync_api import sync_playwright


def fetch_composition(page, isin):
    """Fetch country/sector/holdings breakdown for a single ISIN from justETF."""
    url = f"https://www.justetf.com/en/etf-profile.html?isin={isin}"
    page.goto(url, timeout=30000, wait_until="domcontentloaded")
    page.wait_for_timeout(2000)

    data = page.evaluate("""
        () => {
            const result = { countries: [], sectors: [], holdings: [] };

            const tables = document.querySelectorAll('table');
            for (const table of tables) {
                // Find heading above table
                let heading = '';
                let prev = table.previousElementSibling;
                for (let i = 0; i < 5 && prev; i++) {
                    const tag = prev.tagName;
                    if (['H2','H3','H4'].includes(tag)) {
                        heading = prev.textContent.trim();
                        break;
                    }
                    prev = prev.previousElementSibling;
                }

                const rows = Array.from(table.querySelectorAll('tr')).map(r => {
                    const cells = Array.from(r.querySelectorAll('td, th'));
                    return cells.map(c => c.textContent.trim());
                }).filter(r => r.length === 2);

                if (heading.includes('Countries') || heading.includes('Country')) {
                    for (const [name, pct] of rows) {
                        const val = parseFloat(pct.replace('%', '').replace(',', '.'));
                        if (!isNaN(val) && val > 0) {
                            result.countries.push({ name, weight: val });
                        }
                    }
                } else if (heading.includes('Sectors') || heading.includes('Sector')) {
                    for (const [name, pct] of rows) {
                        const val = parseFloat(pct.replace('%', '').replace(',', '.'));
                        if (!isNaN(val) && val > 0) {
                            result.sectors.push({ name, weight: val });
                        }
                    }
                } else if (heading.includes('Top 10 Holdings') || heading.includes('Holdings')) {
                    for (const [name, pct] of rows) {
                        const val = parseFloat(pct.replace('%', '').replace(',', '.'));
                        if (!isNaN(val) && val > 0 && name.length > 1) {
                            result.holdings.push({ name, weight: val });
                        }
                    }
                }
            }

            return result;
        }
    """)

    # Try to expand "Show more" and re-scrape for full data
    try:
        show_more_links = page.locator('text=Show more').all()
        if show_more_links:
            for link in show_more_links:
                try:
                    link.click(timeout=2000)
                except:
                    pass
            page.wait_for_timeout(1000)

            expanded = page.evaluate("""
                () => {
                    const result = { countries: [], sectors: [] };

                    const tables = document.querySelectorAll('table');
                    for (const table of tables) {
                        let heading = '';
                        let prev = table.previousElementSibling;
                        for (let i = 0; i < 5 && prev; i++) {
                            if (['H2','H3','H4'].includes(prev.tagName)) {
                                heading = prev.textContent.trim();
                                break;
                            }
                            prev = prev.previousElementSibling;
                        }

                        const rows = Array.from(table.querySelectorAll('tr')).map(r => {
                            const cells = Array.from(r.querySelectorAll('td, th'));
                            return cells.map(c => c.textContent.trim());
                        }).filter(r => r.length === 2);

                        if (heading.includes('Countries') || heading.includes('Country')) {
                            for (const [name, pct] of rows) {
                                const val = parseFloat(pct.replace('%', '').replace(',', '.'));
                                if (!isNaN(val) && val > 0) {
                                    result.countries.push({ name, weight: val });
                                }
                            }
                        } else if (heading.includes('Sectors') || heading.includes('Sector')) {
                            for (const [name, pct] of rows) {
                                const val = parseFloat(pct.replace('%', '').replace(',', '.'));
                                if (!isNaN(val) && val > 0) {
                                    result.sectors.push({ name, weight: val });
                                }
                            }
                        }
                    }
                    return result;
                }
            """)
            if len(expanded['countries']) > len(data['countries']):
                data['countries'] = expanded['countries']
            if len(expanded['sectors']) > len(data['sectors']):
                data['sectors'] = expanded['sectors']
    except:
        pass

    return data


def write_to_db(db_path, results_by_isin, asset_map):
    """Write composition data to asset_compositions table.

    Args:
        db_path: Path to SQLite database
        results_by_isin: Dict of ISIN -> {countries, sectors, holdings}
        asset_map: Dict of ISIN -> asset_id
    """
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()

    # Ensure table exists
    cur.execute("""
        CREATE TABLE IF NOT EXISTS asset_compositions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            asset_id INTEGER NOT NULL REFERENCES assets(id),
            type TEXT NOT NULL,
            name TEXT NOT NULL,
            weight REAL NOT NULL,
            updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
        )
    """)

    now = int(time.time())

    for isin, data in results_by_isin.items():
        asset_id = asset_map.get(isin)
        if not asset_id:
            continue

        # Delete old composition data for this asset
        cur.execute("DELETE FROM asset_compositions WHERE asset_id = ?", (asset_id,))

        rows = []
        for entry in data.get('countries', []):
            rows.append((asset_id, 'country', entry['name'], entry['weight'], now))
        for entry in data.get('sectors', []):
            rows.append((asset_id, 'sector', entry['name'], entry['weight'], now))
        for entry in data.get('holdings', []):
            rows.append((asset_id, 'holding', entry['name'], entry['weight'], now))

        if rows:
            cur.executemany(
                "INSERT INTO asset_compositions (asset_id, type, name, weight, updated_at) VALUES (?, ?, ?, ?, ?)",
                rows,
            )
            print(f"[DB] {isin} (id={asset_id}): inserted {len(rows)} composition rows", file=sys.stderr)

    conn.commit()
    conn.close()


def main():
    db_path = None
    isins = None

    # Parse args
    args = sys.argv[1:]
    if '--db' in args:
        idx = args.index('--db')
        db_path = args[idx + 1]
        args = [a for i, a in enumerate(args) if i != idx and i != idx + 1]
    if args:
        isins = args[0].split(',')

    # If --db mode, read assets from DB
    asset_map = {}  # ISIN -> asset_id
    if db_path:
        conn = sqlite3.connect(db_path)
        cur = conn.cursor()
        cur.execute("SELECT id, isin FROM assets WHERE isin IS NOT NULL AND is_active = 1")
        for row in cur.fetchall():
            asset_map[row[1]] = row[0]
        conn.close()

        if not isins:
            isins = list(asset_map.keys())
        print(f"[INFO] Found {len(isins)} assets with ISINs in DB", file=sys.stderr)

    if not isins:
        isins = [
            "IE00B4L5Y983", "IE00BKM4GZ66", "LU0908500753",
            "LU0290358497", "LU1650487413", "IE00B53H0131",
            "IE00B3VWN179", "JE00B1VS3770",
        ]

    with sync_playwright() as p:
        browser = p.chromium.launch(
            headless=False,
            args=["--disable-blink-features=AutomationControlled"],
        )
        context = browser.new_context(
            user_agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            viewport={"width": 1280, "height": 800},
        )
        page = context.new_page()
        page.add_init_script("Object.defineProperty(navigator, 'webdriver', { get: () => undefined });")

        results = {}
        for isin in isins:
            print(f"[INFO] Fetching {isin}...", file=sys.stderr)
            try:
                data = fetch_composition(page, isin)
                results[isin] = data
                total = len(data['countries']) + len(data['sectors']) + len(data['holdings'])
                print(f"[OK] {isin}: {len(data['countries'])} countries, {len(data['sectors'])} sectors, {len(data['holdings'])} holdings", file=sys.stderr)
            except Exception as e:
                print(f"[ERR] {isin}: {e}", file=sys.stderr)
                results[isin] = {"countries": [], "sectors": [], "holdings": []}
            time.sleep(1)

        browser.close()

    # Write to DB if --db mode
    if db_path and asset_map:
        write_to_db(db_path, results, asset_map)
        print(f"[DONE] Composition data written to {db_path}", file=sys.stderr)
    else:
        print(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
