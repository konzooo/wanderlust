# Wanderlust — Group invite links (Universal Links)

The app already parses group invite deep links (`NavigationRouter.handleDeepLink`)
and is hooked to `.onOpenURL`. Two forms are supported:

- **Production:** Universal Link `https://get-catalyst.app/join/<code>`
- **Dev/testing:** custom scheme `wanderlust://join/<code>` (registered in
  `Info.plist`; works in the simulator today — see below)

## Test the deep link now (simulator, no domain needed)

```bash
xcrun simctl openurl booted "wanderlust://join/12345"
```

The app opens straight into the Join screen for code `12345`.

## Ship Universal Links (needs YOUR domain + Apple Team ID)

1. **Host the AASA file** at exactly:
   `https://get-catalyst.app/.well-known/apple-app-site-association`
   - Serve it as `application/json`, **no `.json` extension, no redirect**.
   - Use `web/.well-known/apple-app-site-association` here as the template and
     replace `REPLACE_TEAM_ID` with your Apple Developer Team ID (so the appID is
     `<TEAMID>.com.wanderlust.client`).
2. **Host the fallback page** `web/join.html` at `https://get-catalyst.app/join/<code>`
   (any static host: GitHub Pages, Vercel, Netlify, S3). It shows the code and an
   "Open in app" button for people without the app installed.
3. **Add the Associated Domains capability** in Xcode → target → Signing &
   Capabilities → Associated Domains → `applinks:get-catalyst.app`. (Do this in Xcode so
   the provisioning profile gets the entitlement — don't hand-edit the
   entitlements file.)
4. **In-app share URL** — already set to `https://get-catalyst.app/join/<code>`
   in `GroupTripMembersScreen.swift` and `GroupDashboardScreen.swift`.
5. Test **cold launch, warm launch, and a repeated link** on a real device
   (Universal Links don't fully work in the simulator). Apple's CDN can take a
   while to pick up the AASA — start early.
