# Monetization

## Status

- 2026-07-07: Ads implemented on iOS (`InterstitialAds`, AdMob): every 10th
  saved photo, free users only; ATT prompt + SDK init at launch. TODO: create
  the gpscamera AdMob app and replace the sample app ID (Info.plist) and
  release unit ID (`InterstitialAds.swift`). Still pending: nudge
  orchestrator, in-app review.
- 2026-07-06: Purchase success modal implemented (`PurchaseSuccessView`,
  lottie-ios).
- 2026-07-06: Restore row in Settings implemented (section order 90,
  `Control.action`) and watermark force-on for free implemented in overlay.
- 2026-07-06: Pro banner implemented on iOS, spec revised: thin tappable
  one-line banner on Main (no CTA), thicker banner with CTA in Settings
  (`Control.custom` row).
- 2026-07-06: iOS paywall + IAP implemented on RevenueCat: `ProStore`
  (offerings, purchase, restore, live entitlement + offline cache) and
  `PaywallView`; locked pro settings rows open the paywall. TODO: create the
  gpscamera RevenueCat project and replace the placeholder API keys in
  `ProStore.swift`.
- 2026-07-05: `Entitlement` + `EntitlementProviding` seam added;
  `FixedEntitlement` stub kept for previews/tests.
- 2026-06-30: Initial spec.

## Domain Definition

- **Interests**: Pro subscription, IAP products, the paywall, feature gating
  (the `Entitlement`), interstitial ads, and the nudge orchestrator.
- **Non-interests**: the gated features themselves - each domain reads
  `Entitlement` and gates its own settings/behavior.

## Details

### Entitlement

- `EntitlementProviding` seam exposes `.free` / `.pro`.
- Read by every domain for gating; by `SettingsRegistry` to lock `.pro` items.
- Pro unlocks: remove ads · remove watermark · overlay style settings ·
  filename settings.

### Products & purchase

- One-time **$12** (lifetime Pro) · monthly **$4**, sold through **RevenueCat**
  (same setup as Travel English) on both platforms.
- RevenueCat config: entitlement `pro`; current offering carries the monthly +
  lifetime packages; debug builds use the Test Store key, release the platform
  key (placeholders in `ProStore.swift` until the project is created).
- Store product IDs: `com.raysuhyunlee.gpscamera.pro.monthly`,
  `com.raysuhyunlee.gpscamera.pro.lifetime`.
- Reference: competitor one-time ₩15,000.
- **Restore purchase**: re-validates entitlement via RevenueCat. Reachable
  from the paywall link row and the Settings restore row (result alert:
  restored / nothing found / error).
- Last known entitlement is persisted locally so pro survives offline launches.

### Paywall

- Layout borrowed from the Travel English paywall (close row, hero, feature
  rows, selectable price cards, pinned CTA + restore/terms/legal links);
  restyled to this app's native look (system colors, SF Symbols, light/dark).
- Purchase and restore run through `ProStore` (RevenueCat packages).
- Successful purchase or restore dismisses the paywall. Purchase additionally
  shows the success modal (Lottie celebration, "Pro unlocked!" /
  "Enjoy all features", Continue): `PurchaseSuccess.present()` opens it in its
  own alert-level window, so it shows over any screen or sheet stack.
- Opened by tapping a locked pro row in Settings (`PaywallProviding` seam,
  presented by Main over the settings sheet). Always dismissible for now;
  nudge-driven presentation lands with the orchestrator.

### Pro banner

Two variants, both owned by monetization; each opens the paywall itself so
hosts stay monetization-unaware:

- **Main**: thin one-line strip under the top controls, no CTA - the banner
  itself is the button. Hidden for pro. Hosted via `ProBannerProviding`
  (`mainBanner()`), disabled while recording.
- **Settings**: thicker two-line banner row (`Control.custom`, section order 0)
  with a CTA:
	- Free → "Upgrade" (paywall).
	- Subscribed → status + "Manage" (store management URL; hidden when there
	  is none, e.g. lifetime).
- A purchase while Settings is open posts `.settingsGatingChanged`
  (foundation) so locked rows unlock in place.

### Ads

- **AdMob** interstitials, free users only. Shown every **10 photos**; counter
  resets per session. Removed for `.pro` (no SDK init, no ATT prompt).
- **Trigger**: `UsageMetrics.onPhotoCapture` (foundation) ->
  `InterstitialAds.photoSaved()`, bound at the root. Runs after the photo has
  saved; an ad never shows at app launch or during/blocking a capture.
- **ATT**: tracking prompt at launch (first launch only, ~1s after UI settles),
  then SDK init + preload. One interstitial stays preloaded; dismissing loads
  the next. No fill / offline = the ad is silently skipped, never awaited.
- **IDs**: debug builds use Google's sample IDs; the release unit ID and
  `GADApplicationIdentifier` are placeholders until the AdMob app is created.
- **Format**: only standard, always-dismissible interstitials. No deceptive,
  fake-system, or unclosable creatives - enforced via ad-network/format choice.

### In-App Review 

- Shown after the first photo or video is taken in the session
- Only shown from the third session

### Nudge orchestrator

- Consumes injected usage metrics (session count, photo count, …) and applies a
  rule set to decide when to present subscription nudges.
- Rules are data-driven and easy to edit without touching call sites.
- TODO: define the review-nudge period (when to prompt for the platform's
  in-app review).

## Settings

Contributed sections (see overview.md ordering):

| order | key | title | control | gate |
|---|---|---|---|---|
| 0 | `monetization.proBanner` | Pro banner | custom | free |
| 90 | `monetization.restore` | Restore purchase | action | free |

## Implementation

### iOS

```
ios/gpscamera/Domains/Monetization/
├── Entitlement.swift - Entitlement enum, EntitlementProviding seam, FixedEntitlement (previews/tests)
├── ProStore.swift    - RevenueCat: API keys, offerings, purchase/restore, live entitlement + offline cache
├── PaywallView.swift - PaywallProviding seam + the paywall screen
├── PurchaseSuccessView.swift - post-purchase success modal in its own window (Lottie; expects bundled PurchaseSuccess.json)
├── InterstitialAds.swift - AdMob executor + every-10-photos trigger; ATT prompt, SDK init, preload/show
└── ProBanner.swift   - ProBannerProviding seam, Main + Settings banners, MonetizationSettingsProvider
ios/gpscamera/Info.plist - AdMob app ID + SKAdNetworkItems (merged into the generated Info.plist)
ios/gpscamera.storekit - StoreKit test config (local purchases with the Apple key; wired in the shared scheme)
```

Dependencies: `purchases-ios-spm` (RevenueCat, SPM), `lottie-ios` (SPM),
`swift-package-manager-google-mobile-ads` (AdMob, SPM).

Android: planned.

## Revision History

- 2026-07-07: iOS ads (`InterstitialAds`, AdMob SPM, ATT at launch, Info.plist
  AdMob keys, `ad_shown` event, ads debug section).
- 2026-07-06: Purchase success modal (`PurchaseSuccessView`, lottie-ios dep);
  presented window-level (`PurchaseSuccess.present()`) so it shows over any
  screen;
- 2026-07-06: `ProStore.refresh()` (force customer-info refetch) for the debug
  surface's pro status section (camera.md "Individual controls").
- 2026-07-06: Settings restore row (`Control.action`, order 90); domain-side
  watermark gating landed in overlay.
- 2026-07-06: Pro banner spec revised (Main: thin tappable line; Settings:
  thicker + CTA) and implemented on iOS (`ProBanner.swift`).
- 2026-07-06: IAP switched to RevenueCat (`purchases-ios-spm`); offerings
  replace direct StoreKit products.
- 2026-07-06: iOS paywall + IAP (`ProStore`, `PaywallView`, `PaywallProviding`);
  composition root swaps `FixedEntitlement` for `ProStore`.
- 2026-07-05: Entitlement seam + dev stub (settings framework gating consumer).
- 2026-06-30: Initial monetization spec (subscription, ads, nudge).
