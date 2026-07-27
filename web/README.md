# Wanderlust share links (Universal Links)

The app parses both group invites and shared solo trips in
`NavigationRouter.handleDeepLink` and is hooked to `.onOpenURL`.

- **Production group invite:** `https://wanderlust.get-catalyst.app/join/<code>`
- **Production shared trip:** `https://wanderlust.get-catalyst.app/t/<code>`
- **Legacy:** Existing `https://www.get-catalyst.app/...` links stay supported.
- **Dev/testing:** `wanderlust://join/<code>` and `wanderlust://t/<code>`

## Test the deep link now (simulator, no domain needed)

```bash
xcrun simctl openurl booted "wanderlust://join/12345"
```

The app opens straight into the Join screen for code `12345`. To test a shared
trip, use an existing 32-character share code:

```bash
xcrun simctl openurl booted "wanderlust://t/<code>"
```

## Hosting

`vercel.json` proxies both production paths to Convex, which renders the
per-trip page and Open Graph preview. The AASA file is served directly at:

`https://wanderlust.get-catalyst.app/.well-known/apple-app-site-association`

It must return `200`, use `application/json`, and never redirect. The iOS target
keeps both `applinks:wanderlust.get-catalyst.app` and the legacy
`applinks:www.get-catalyst.app` entitlement.

After changing Associated Domains, install a fresh app build on the real device.
Test cold launch, warm launch, and repeated links. Apple's AASA CDN can take time
to refresh.
