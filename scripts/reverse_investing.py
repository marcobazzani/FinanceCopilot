"""Reverse-engineer Investing.com historical data API using Playwright."""
import json
import sys
from playwright.sync_api import sync_playwright

def main():
    ticker = sys.argv[1] if len(sys.argv) > 1 else "SWDA"

    captured = []

    with sync_playwright() as p:
        # Use headed Chromium (not headless) to bypass Cloudflare
        browser = p.chromium.launch(
            headless=False,
            args=["--disable-blink-features=AutomationControlled"],
        )
        context = browser.new_context(
            user_agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            viewport={"width": 1280, "height": 800},
        )

        # Remove webdriver flag
        page = context.new_page()
        page.add_init_script("""
            Object.defineProperty(navigator, 'webdriver', { get: () => undefined });
        """)

        # Capture all API network responses
        def on_response(response):
            url = response.url
            if any(kw in url for kw in ["historical", "chart", "financialdata", "candle", "price"]):
                try:
                    ct = response.headers.get("content-type", "")
                    if "json" in ct or "text" in ct:
                        body = response.text()
                        captured.append({
                            "url": url,
                            "status": response.status,
                            "content_type": ct,
                            "body": body[:2000] if body else ""
                        })
                        print(f"[CAPTURED] {response.status} {url}", file=sys.stderr)
                except:
                    pass

        page.on("response", on_response)

        # Step 1: Go directly to a known SWDA page on investing.com
        print(f"[INFO] Navigating to investing.com for {ticker}...", file=sys.stderr)
        page.goto("https://www.investing.com/etfs/ishares-msci-world---acc", timeout=60000)
        page.wait_for_timeout(5000)
        print(f"[INFO] Page loaded: {page.url}", file=sys.stderr)
        print(f"[INFO] Title: {page.title()}", file=sys.stderr)

        # Step 2: Click on Historical Data tab
        print(f"[INFO] Looking for Historical Data tab...", file=sys.stderr)
        for label in ["Historical Data", "Dati Storici", "Dati storici"]:
            try:
                link = page.locator(f"a:has-text('{label}')").first
                if link.is_visible(timeout=3000):
                    print(f"[INFO] Clicking '{label}'...", file=sys.stderr)
                    link.click()
                    page.wait_for_timeout(5000)
                    break
            except:
                continue

        print(f"[INFO] Now on: {page.url}", file=sys.stderr)

        # Step 3: Try to expand the date range
        # Look for a date picker or "Show more" type element
        try:
            # Check if there's a date range selector
            date_inputs = page.locator("input[type='text']").all()
            print(f"[INFO] Found {len(date_inputs)} text inputs", file=sys.stderr)
        except:
            pass

        page.wait_for_timeout(3000)

        # Step 4: Now let's also try directly hitting the API with the browser's cookies
        print(f"\n[INFO] Testing API with browser cookies...", file=sys.stderr)
        api_response = page.evaluate("""
            async () => {
                const resp = await fetch('https://api.investing.com/api/financialdata/historical/46925?start-date=2024-01-01&end-date=2024-03-01&time-frame=Daily&add-missing-rows=false', {
                    credentials: 'include',
                    headers: {
                        'Accept': 'application/json',
                        'Domain-Id': 'it',
                    }
                });
                const text = await resp.text();
                return { status: resp.status, body: text.substring(0, 3000) };
            }
        """)
        print(f"[API TEST] Status: {api_response['status']}", file=sys.stderr)
        print(f"[API TEST] Body: {api_response['body'][:1000]}", file=sys.stderr)

        # Output everything
        result = {
            "captured_responses": captured,
            "api_test": api_response,
        }
        print(json.dumps(result, indent=2))

        browser.close()

if __name__ == "__main__":
    main()
