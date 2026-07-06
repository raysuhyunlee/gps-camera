# Monetization

## Status

- 2026-07-06: Restore row in Settings implemented (section order 90,
  `Control.action`) and watermark force-on for free implemented in overlay.
  Still pending: ads, nudge orchestrator, in-app review, ad trigger.
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
  Successful purchase or restore dismisses the paywall.
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

- Free users only. Interstitial shown every **10 photos**; counter resets per
  session.
- Driven by the foundation usage-metrics bus (photo count). Removed for `.pro`.
- **Timing**: never at app launch, and never during/blocking an in-progress or
  queued capture. Fires only after a capture has saved, while the user is idle.
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
└── ProBanner.swift   - ProBannerProviding seam, Main + Settings banners, MonetizationSettingsProvider
ios/gpscamera.storekit - StoreKit test config (local purchases with the Apple key; wired in the shared scheme)
```

Dependency: `purchases-ios-spm` (RevenueCat, SPM).

Android: planned.

## Revision History

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
