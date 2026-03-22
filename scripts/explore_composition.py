"""Fetch ETF composition data from justETF."""
import json
import sys
from playwright.sync_api import sync_playwright


ISINS = [
    ("IE00B4L5Y983", "SWDA"),  # iShares Core MSCI World
    ("IE00BKM4GZ66", "EIMI"),  # iShares Core EM IMI
    ("LU0908500753", "MEUD"),  # Amundi STOXX Europe 600
    ("LU0290358497", "XEON"),  # Xtrackers EUR Overnight Rate
    ("LU1650487413", "EM13"),  # Amundi Euro Gov Bond 1-3Y
    ("IE00B53H0131", "CCUSAS"),  # UBS CMCI Composite
    ("IE00B3VWN179", "CSBGU3"),  # iShares Treasury 1-3Y
    ("JE00B1VS3770", "PHAU"),  # WisdomTree Physical Gold
]


def main():
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

        isin = sys.argv[1] if len(sys.argv) > 1 else "IE00B4L5Y983"
        ticker = sys.argv[2] if len(sys.argv) > 2 else "SWDA"

        url = f"https://www.justetf.com/en/etf-profile.html?isin={isin}"
        print(f"[INFO] Loading {url}...", file=sys.stderr)
        page.goto(url, timeout=30000, wait_until="domcontentloaded")
        page.wait_for_timeout(3000)

        print(f"[INFO] Title: {page.title()}", file=sys.stderr)

        # Extract all data tables and chart data
        data = page.evaluate("""
            () => {
                const results = {};

                // Find all section headings
                const headings = document.querySelectorAll('h2, h3, h4, .h2, .h3');
                results.headings = Array.from(headings)
                    .map(h => h.textContent.trim())
                    .filter(t => t.length > 0 && t.length < 100);

                // Find all tables with their preceding headings
                results.tables = [];
                const tables = document.querySelectorAll('table');
                for (const table of tables) {
                    // Look for a heading above this table
                    let heading = '';
                    let prev = table.previousElementSibling;
                    for (let i = 0; i < 5 && prev; i++) {
                        if (['H2','H3','H4'].includes(prev.tagName)) {
                            heading = prev.textContent.trim();
                            break;
                        }
                        prev = prev.previousElementSibling;
                    }

                    const rows = Array.from(table.querySelectorAll('tr')).map(r =>
                        Array.from(r.querySelectorAll('td, th')).map(c => c.textContent.trim())
                    ).filter(r => r.length > 0);

                    if (rows.length > 0) {
                        results.tables.push({heading, rows: rows.slice(0, 30)});
                    }
                }

                // Look for div-based lists (justETF uses divs for some data)
                const chartContainers = document.querySelectorAll('[class*="allocation"], [class*="composition"], [class*="breakdown"], [id*="allocation"], [id*="composition"]');
                results.chartContainers = Array.from(chartContainers).map(c => ({
                    id: c.id,
                    class: c.className?.substring?.(0, 100) || '',
                    text: c.textContent.trim().substring(0, 1000)
                }));

                // Check for any data attributes or embedded JSON
                const allText = document.body.innerText;
                // Find sections with percentage data
                const pctRegex = /(\d+\.\d+)\s*%/g;
                let match;
                const pctSections = [];
                while ((match = pctRegex.exec(allText)) !== null) {
                    const start = Math.max(0, match.index - 50);
                    const end = Math.min(allText.length, match.index + 50);
                    pctSections.push(allText.substring(start, end).replace(/\\n/g, ' ').trim());
                }
                results.percentageSections = [...new Set(pctSections)].slice(0, 50);

                return results;
            }
        """)

        print(json.dumps(data, indent=2))
        browser.close()


if __name__ == "__main__":
    main()
