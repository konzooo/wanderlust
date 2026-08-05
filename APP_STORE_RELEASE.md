# App Store relaunch checklist

## New record

- App Store name: `Wanderlust: Unique Trips`
- Fallback 1: `Wanderlust: Travel Your Way`
- Fallback 2: `Wanderlust: Made for You`
- Bundle ID: `app.kk.wanderlust`
- SKU: `wanderlust-ios-2026`
- Version/build: `1.0.0 (1)`
- Device display name: `Wanderlust`
- Privacy URL: `https://wanderlust.get-catalyst.app/privacy`

The old listing cannot be reused without an account transfer. This project is intentionally configured as a new App Store record.

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

## Final checks

- Deploy `web/privacy.html` so `/privacy` returns the policy over HTTPS.
- Verify the archive contains `app.kk.wanderlust`, `1.0.0 (1)`, the intended entitlements, and Amplitude’s `PrivacyInfo.xcprivacy`.
- Verify the archive contains no Firebase frameworks/packages and no `GoogleService-Info.plist`.
- Confirm screenshots, description, support URL, privacy URL, category, age rating, export compliance, and review notes.
- Verify TestFlight analytics before submitting build `1.0.0 (1)`.
