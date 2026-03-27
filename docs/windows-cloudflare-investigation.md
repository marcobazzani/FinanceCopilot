# Windows Cloudflare Investigation — Journey to Working Price Sync

## The Problem

FinanceCopilot fetches market prices from Investing.com's API (`api.investing.com/api/financialdata/historical/`). This API is protected by Cloudflare. On macOS, the app worked perfectly. On Windows, every API call returned **403 Forbidden**.

## Phase 1: Initial Assumption — Cookie Extraction Bug

**Theory**: The headless WebView on Windows isn't extracting cookies correctly.

**Investigation**: Compared cookie counts between platforms:
- macOS (WKWebView): 23 cookies including `cf_clearance`
- Windows (WebView2): 22 cookies, **`cf_clearance` missing**

**Attempted fix**: Tried extracting cookies from multiple domains (`www.investing.com`, `api.investing.com`, `investing.com`). Still no `cf_clearance`.

**Result**: ❌ Cookie was never there to extract.

## Phase 2: HttpOnly Cookie Theory

**Theory**: WebView2's `CookieManager` filters HttpOnly cookies.

**Investigation**: Read the `flutter_inappwebview_windows` C++ source code. Found it uses Chrome DevTools Protocol `Network.getCookies` which **does return HttpOnly cookies**. No filtering.

**Result**: ❌ Not a filtering issue. `cf_clearance` simply isn't set by Cloudflare on Windows.

## Phase 3: Browser Headers (sec-ch-ua)

**Theory**: Cloudflare needs browser security headers (`sec-ch-ua`, `sec-fetch-*`).

**Investigation**: Captured HAR files from Edge on Windows. Found that Edge's XHR calls to `api.investing.com` include `sec-ch-ua`, `sec-fetch-dest: empty`, `sec-fetch-mode: cors`, etc.

**Attempted fix**: Added all `sec-*` headers to Dio requests.

**Result**: ❌ Still 403. Headers alone weren't enough.

## Phase 4: TLS Fingerprinting Discovery

**Theory**: Cloudflare blocks based on TLS fingerprint (JA3/JA4), not cookies or headers.

**Investigation**:
- Loaded the API URL **directly in the visible WebView** → got **400** (Bad Request: "Domain required"), NOT 403
- This proved: **Cloudflare does NOT block WebView2** — the 403 only happens with Dio/HttpClient

**Key insight**: The API works fine when called from a real browser engine (WebView2). The 403 is from Cloudflare detecting Dio's TLS handshake as non-browser.

## Phase 5: Why macOS Works

**Investigation**: On macOS, WKWebView completes Cloudflare's challenge and `cf_clearance` is issued. With `cf_clearance` cookie, Cloudflare skips TLS fingerprint checks — the cookie proves the client already passed verification. So Dio + `cf_clearance` works on macOS.

On Windows, headless WebView2 never triggers the Cloudflare challenge (the page loads directly with 200), so `cf_clearance` is never issued. Without it, Cloudflare falls back to TLS fingerprint verification, which Dio fails.

## Phase 6: Navigation-Based Fetch (The Solution)

**Solution**: On Windows, route API calls **through the WebView** by navigating to the API URL and reading `document.body.innerText`.

### How it works:

1. **On startup**: Show a visible `InAppWebView` dialog that loads `www.investing.com` (CF solves, WebView gets cookies)
2. **For API calls**: Navigate the same WebView to `api.investing.com/api/financialdata/historical/...` with custom headers (`domain-id: www`)
3. **Read response**: Poll `document.body.innerText` for JSON content
4. **Parse**: Clean and decode the JSON response
5. **After sync**: Dismiss the dialog

### Key details:
- Navigation is **sequential** (one URL at a time via mutex)
- The `domain-id: www` header must be included in the navigation request
- JSON pages render in a `<pre>` tag on WebView2 — extracted via `document.querySelector("pre")?.textContent`
- macOS continues using Dio + cookies (faster, parallel)

## Platform-Specific Architecture

```
macOS:
  HeadlessInAppWebView → solve CF → extract cf_clearance
  Dio + cf_clearance cookie → api.investing.com → 200 ✓

Windows:
  Visible InAppWebView dialog → solve CF (no cf_clearance issued)
  WebView.loadUrl(api URL + domain-id header) → read body → parse JSON → 200 ✓
```

## Files Changed

- `lib/services/investing_com_service.dart` — Platform-specific `_ensureWebView()`, `_fetchViaNavigation()`, `_solveHeadless()`, `_solveVisible()`
- `lib/main.dart` — Set `InvestingComService.appContext`, dismiss dialog after sync

## What We Tried That Didn't Work

| Attempt | Why it failed |
|---------|--------------|
| Extract cookies from multiple subdomains | `cf_clearance` not set at all |
| Add `sec-ch-ua` / `sec-fetch-*` headers to Dio | TLS fingerprint still detected |
| Use Dart `HttpClient` instead of Dio | Same TLS fingerprint issue |
| Use `fetch()` / `XMLHttpRequest` in WebView JS | CORS blocks cross-origin from www to api |
| `callAsyncJavaScript` with fetch | Same CORS issue |
| Headless WebView2 | Never triggers CF challenge → no `cf_clearance` |
| Visible WebView loading API URL directly | API returns 400 (missing domain-id header on page navigation) |

## What Worked

Navigate the visible WebView to the API URL with `domain-id` header included in the `URLRequest`. The WebView's browser engine handles TLS natively, Cloudflare accepts it, and the JSON response is readable from `document.body.innerText`.
