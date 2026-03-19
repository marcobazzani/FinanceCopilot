"""
Investing.com price scraper using Playwright to bypass Cloudflare.

Usage:
  # Search for a ticker and get its investing.com ID
  python investing_scraper.py search SWDA MIL

  # Fetch historical prices (outputs JSON lines: {"date":"YYYY-MM-DD","close":123.45})
  python investing_scraper.py history 46925 2020-01-01 2024-03-18

  # Full pipeline: search + fetch all history
  python investing_scraper.py sync '{"assets":[{"ticker":"SWDA","exchange":"MIL","cid":null,"from":"2020-01-01"}]}'
"""
import json
import sys
import time
from datetime import datetime, timedelta
from playwright.sync_api import sync_playwright


# Map internal exchange codes to Investing.com exchange labels
EXCHANGE_MAP = {
    'MIL': 'Milano',
    'NYQ': 'NYSE',
    'NMS': 'NASDAQ',
    'NYS': 'NYSE',
    'ASE': 'AMEX',
    'XETRA': 'Francoforte',
    'FRA': 'Francoforte',
    'LON': 'Londra',
    'AMS': 'Amsterdam',
    'PAR': 'Parigi',
    'SIX': 'Svizzera',
    'TSE': 'Toronto',
    'HKG': 'Hong Kong',
    'TYO': 'Tokyo',
}

# Also try English labels as fallback
EXCHANGE_MAP_EN = {
    'MIL': 'Milan',
    'NYQ': 'NYSE',
    'NMS': 'NASDAQ',
    'NYS': 'NYSE',
    'ASE': 'AMEX',
    'XETRA': 'Frankfurt',
    'FRA': 'Frankfurt',
    'LON': 'London',
    'AMS': 'Amsterdam',
    'PAR': 'Paris',
    'SIX': 'Switzerland',
    'TSE': 'Toronto',
    'HKG': 'Hong Kong',
    'TYO': 'Tokyo',
}


def create_browser(playwright):
    """Launch browser and pass Cloudflare challenge."""
    browser = playwright.chromium.launch(
        headless=False,
        args=["--disable-blink-features=AutomationControlled"],
    )
    context = browser.new_context(
        user_agent=(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
            "AppleWebKit/537.36 (KHTML, like Gecko) "
            "Chrome/120.0.0.0 Safari/537.36"
        ),
        viewport={"width": 1280, "height": 800},
    )
    page = context.new_page()
    page.add_init_script(
        "Object.defineProperty(navigator, 'webdriver', { get: () => undefined });"
    )
    return browser, context, page


def pass_cloudflare(page):
    """Navigate to investing.com to pass Cloudflare challenge."""
    page.goto("https://www.investing.com/", timeout=60000, wait_until="domcontentloaded")
    page.wait_for_timeout(3000)


def search_ticker(page, ticker, exchange_code):
    """Search for a ticker on investing.com and return the cid for the matching exchange."""
    exchange_label = EXCHANGE_MAP.get(exchange_code, exchange_code)
    exchange_label_en = EXCHANGE_MAP_EN.get(exchange_code, exchange_code)

    result = page.evaluate(f"""
        async () => {{
            const resp = await fetch(
                'https://api.investing.com/api/search/v2/search?q={ticker}',
                {{ credentials: 'include', headers: {{ 'Accept': 'application/json' }} }}
            );
            return await resp.json();
        }}
    """)

    quotes = result.get("quotes", [])
    if not quotes:
        return None

    # Find matching exchange
    for q in quotes:
        ex = q.get("exchange", "")
        if (exchange_label.lower() in ex.lower() or
            exchange_label_en.lower() in ex.lower()):
            return {"cid": q["id"], "name": q["description"], "symbol": q["symbol"], "exchange": ex}

    # If no exchange match, return first result
    q = quotes[0]
    return {"cid": q["id"], "name": q["description"], "symbol": q["symbol"], "exchange": q.get("exchange", "")}


def fetch_history(page, cid, start_date, end_date):
    """Fetch historical prices for a given cid. Returns list of {date, close}."""
    all_prices = []

    # API limits to ~5000 rows, so chunk by year
    current_start = datetime.strptime(start_date, "%Y-%m-%d")
    final_end = datetime.strptime(end_date, "%Y-%m-%d")

    while current_start < final_end:
        current_end = min(current_start + timedelta(days=365), final_end)
        sd = current_start.strftime("%Y-%m-%d")
        ed = current_end.strftime("%Y-%m-%d")

        result = page.evaluate(f"""
            async () => {{
                const resp = await fetch(
                    'https://api.investing.com/api/financialdata/historical/{cid}?start-date={sd}&end-date={ed}&time-frame=Daily&add-missing-rows=false',
                    {{ credentials: 'include', headers: {{ 'Accept': 'application/json', 'Domain-Id': 'it' }} }}
                );
                if (!resp.ok) return {{ error: resp.status }};
                return await resp.json();
            }}
        """)

        if "error" in result:
            print(f"[WARN] API error {result['error']} for cid={cid} {sd}-{ed}", file=sys.stderr)
            break

        data = result.get("data", [])
        for row in data:
            close_raw = row.get("last_closeRaw")
            date_ts = row.get("rowDateTimestamp")
            if close_raw is not None and date_ts:
                # Parse date from ISO timestamp
                dt = date_ts[:10]  # "YYYY-MM-DD"
                all_prices.append({"date": dt, "close": float(str(close_raw))})

        print(f"[INFO] cid={cid} {sd}→{ed}: {len(data)} rows", file=sys.stderr)

        current_start = current_end + timedelta(days=1)
        time.sleep(0.5)  # Rate limit

    return all_prices


def cmd_search(args):
    ticker = args[0]
    exchange = args[1] if len(args) > 1 else "MIL"

    with sync_playwright() as p:
        browser, context, page = create_browser(p)
        pass_cloudflare(page)
        result = search_ticker(page, ticker, exchange)
        print(json.dumps(result, indent=2))
        browser.close()


def cmd_history(args):
    cid = int(args[0])
    start_date = args[1] if len(args) > 1 else "2010-01-01"
    end_date = args[2] if len(args) > 2 else datetime.now().strftime("%Y-%m-%d")

    with sync_playwright() as p:
        browser, context, page = create_browser(p)
        pass_cloudflare(page)
        prices = fetch_history(page, cid, start_date, end_date)
        # Output as JSON array
        print(json.dumps(prices))
        browser.close()


def cmd_sync(args):
    """Full sync: search + fetch history for multiple assets.

    Input JSON: {"assets": [{"ticker": "SWDA", "exchange": "MIL", "cid": null, "from": "2020-01-01"}, ...]}
    Output JSON lines: {"ticker": "SWDA", "cid": 46925, "prices": [{date, close}, ...]}
    """
    config = json.loads(args[0])
    assets = config["assets"]
    today = datetime.now().strftime("%Y-%m-%d")

    with sync_playwright() as p:
        browser, context, page = create_browser(p)
        pass_cloudflare(page)

        results = []
        for asset in assets:
            ticker = asset["ticker"]
            exchange = asset.get("exchange", "MIL")
            cid = asset.get("cid")
            from_date = asset.get("from", "2010-01-01")

            # Search if no cid
            if not cid:
                print(f"[INFO] Searching {ticker} on {exchange}...", file=sys.stderr)
                search_result = search_ticker(page, ticker, exchange)
                if not search_result:
                    print(f"[WARN] No result for {ticker}", file=sys.stderr)
                    results.append({"ticker": ticker, "cid": None, "prices": []})
                    continue
                cid = search_result["cid"]
                print(f"[INFO] {ticker} → cid={cid} ({search_result['name']})", file=sys.stderr)

            # Fetch history
            print(f"[INFO] Fetching history for {ticker} (cid={cid}) from {from_date}...", file=sys.stderr)
            prices = fetch_history(page, cid, from_date, today)
            results.append({"ticker": ticker, "cid": cid, "prices": prices})

            time.sleep(1)  # Rate limit between assets

        print(json.dumps(results))
        browser.close()


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    cmd = sys.argv[1]
    args = sys.argv[2:]

    if cmd == "search":
        cmd_search(args)
    elif cmd == "history":
        cmd_history(args)
    elif cmd == "sync":
        cmd_sync(args)
    else:
        print(f"Unknown command: {cmd}")
        sys.exit(1)
