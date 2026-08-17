# App Store relaunch checklist

## Transferred record

Apple transferred the original listing to team `JVC4H9U29T` on 2026-08-14. This
ships as a **new version of the existing app**, not a new record — so the bundle
ID is fixed forever at the value the original app shipped with, and the version
must climb past the `1.2.2` already on the store.

- Apple ID: `6746957492`
- App Store name: `Wanderlust: Travel Inspiration` (rename to `Wanderlust: Unique Trips` with this version)
- Bundle ID: `com.wanderlust.client` — **immutable, do not change**
- SKU: `com.wandrlust.app` (inherited, cannot be edited)
- Previous store version: `1.2.2`
- Version/build: `2.0.0 (1)`
- Device display name: `Wanderlust`
- Privacy URL: `https://wanderlust.get-catalyst.app/privacy`
- Support URL: `https://wanderlust.get-catalyst.app/support`

The AASA `appIDs` entry must stay in sync with the bundle ID
(`JVC4H9U29T.com.wanderlust.client`) or Universal Links break silently.

## Amplitude handoff

1. EU-residency project `Wanderlust Production` (project ID `100053341`) is created.
2. Its client API key is configured in the Release build setting `AMPLITUDE_API_KEY`; Debug remains offline by default. A missing key still selects no-op analytics.
3. Upload to TestFlight and confirm events arrive in the EU project.
4. Confirm no event contains IP/location/IDFV data, names, codes, URLs, raw errors, or free-form content.
5. Create the five dashboards described in `ANALYTICS.md`.

## Conservative App Privacy answers

Declare third-party SDK behavior as well as app behavior:

- **Identifiers → Device ID:** Analytics; linked to the device; not used for tracking.
- **Usage Data → Product Interaction:** Analytics; linked to the device; not used for tracking.
- **Browsing/Search History or Other User Content:** destinations and structured travel preferences used for app functionality and analytics.
- **Contact Info → Name and Other User Content:** group-trip functionality.
- **User Content → Customer Support** and **Identifiers → Device ID:** feedback functionality.
- No data is used to track users across other companies’ apps or websites. Do not add an ATT prompt.

Review the answers against the final binary and Apple’s current guidance before submission: <https://developer.apple.com/app-store/app-privacy-details/>.

## Convex: promote dev to prod before every release

Release builds talk to `prod:clean-bulldog-349`; Debug builds talk to
`dev:affable-pika-176` (gated in `ConvexConfiguration`). Prod does **not**
inherit anything from dev automatically, so run both of these — functions and
environment variables drift independently, and a missing env var fails at
runtime, not at deploy time:

```bash
cd ConvexBackend && npx convex deploy -y && npx convex env list --prod
```

Compare that output against `npx convex env list`. Any key on dev and missing on
prod must be set with `npx convex env set <KEY> <value> --prod`.

## Final checks

- Deploy `web/privacy.html` and `web/support.html` so `/privacy` and `/support` return over HTTPS.
- Verify the archive contains `com.wanderlust.client`, `2.0.0 (1)`, the intended entitlements, and Amplitude’s `PrivacyInfo.xcprivacy`.
- Install the store build of `1.2.2` first, then build over it, and confirm saved trips and Traveller DNA profiles survive the upgrade.
- Verify the archive contains no Firebase frameworks/packages and no `GoogleService-Info.plist`.
- Confirm screenshots, description, support URL, privacy URL, category, age rating, export compliance, and review notes.
- Verify TestFlight analytics before submitting build `2.0.0 (1)`.
- Mint fresh App Review invite codes on **prod** and put them in the review notes. A code is only demoable while its group is `collecting`; once generation runs the group flips to `ready` and the reviewer can no longer join it.
