# Monetization

## Status

- 2026-07-18: Paywall nudge now fires once per session, after the first capture
  (was lifetime milestones 25/50/100). Interstitial cadence tightened to every
  5th session capture (was 10th). Cadence predicates
  (`NudgeRules.paywallEarned`, `InterstitialAds.adEarned`) extracted and
  unit-tested (`MonetizationValueTests`).
- 2026-07-14: AdMob SKAdNetwork IDs synced to Google's current list.
- 2026-07-07: Nudge orchestrator + in-app review implemented on iOS
  (`NudgeOrchestrator`): paywall nudge at lifetime-capture milestones, review
  attempt on the first capture of a session from session 3; at most one nudge
  per capture, paywall precedes ad. Rules never separate photos from videos.
- 2026-07-07: Ads implemented on iOS (`InterstitialAds`, AdMob): every 10th
  saved photo, free users only; ATT prompt + SDK init at launch.
- 2026-07-06: Purchase success modal implemented (`PurchaseSuccessView`,
  lottie-ios).
- 2026-07-06: Restore row in Settings implemented (section order 90,
  `Control.action`) and watermark force-on for free implemented in overlay.
- 2026-07-06: Pro banner implemented on iOS, spec revised: thin tappable
  one-line banner on Main (no CTA), thicker banner with CTA in Settings
  (`Control.custom` row).
- 2026-07-06: iOS paywall + IAP implemented on RevenueCat: `ProStore`
  (offerings, purchase, restore, live entitlement + offline cache) and
  `PaywallView`; locked pro settings rows open the paywall.
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
  key.
- Store product IDs: `gps_camera_monthly_subscription`, `gpscamera_lifetime`.
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
  presented by Main over the settings sheet) or by the nudge orchestrator
  (presented over the top view controller). Always dismissible.

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

- **AdMob** interstitials, free users only. Shown every **10 captures**
  (photos + videos); the cadence reads foundation's session capture counts
  (`UsageMetrics`, reset per launch), so every capture counts regardless of
  entitlement at capture time. Removed for `.pro` (no SDK init, no ATT prompt).
- **Trigger**: the nudge orchestrator forwards every finished capture to
  `InterstitialAds.captureSaved()`. Runs after the capture has saved; an ad
  never shows at app launch or during/blocking a capture.
- **ATT**: tracking prompt after onboarding's camera/location prompts resolve
  (returning launches: at launch), first launch only, ~1s after UI settles;
  then SDK init + preload. Sequenced via `RootView.onOnboarded` so ATT never
  stacks on the onboarding page. One interstitial stays preloaded; dismissing
  loads the next. No fill / offline = the ad is silently skipped, never awaited.
- **IDs**: debug builds use Google's sample ID. Release uses the production
  interstitial ID bundled in the app. `GADApplicationIdentifier` is the
  production app ID.
- **Format**: only standard, always-dismissible interstitials. No deceptive,
  fake-system, or unclosable creatives - enforced via ad-network/format choice.

### In-App Review

- Attempted after the first photo or video of the session, from the third
  session on; every qualifying session attempts. The OS decides whether a
  prompt actually shows (throttled by the platform, max 3/year on iOS).
- Fired by the nudge orchestrator (`review_requested` event on attempt).

### Nudge orchestrator

- Consumes injected usage metrics (session count, photo count, ...) and applies
  a rule set to decide what a finished capture earns: paywall nudge, review
  prompt, or ad.
- Rules are data-driven (`NudgeRules`, one place) and easy to edit without
  touching call sites. Rules never separate photos from videos - a capture is
  a capture. Current rules:
	- Paywall nudge: lifetime capture count hits 25, 50, or 100; free users only.
	- Review: see "In-App Review" above.
- At most one nudge per capture. Paywall precedes ad (that capture's ad is
  suppressed, not deferred) and review (the review attempt moves to the next
  capture of the session).
- Bound to the usage-metrics `onCapture` hook at the root: nudges run after a
  capture has saved, never during one.

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
├── InterstitialAds.swift - AdMob executor + every-10-captures trigger; ATT prompt, SDK init, preload/show
├── NudgeOrchestrator.swift - NudgeRules + capture-hook dispatch: paywall nudge, review attempt, ad forward
└── ProBanner.swift   - ProBannerProviding seam, Main + Settings banners, MonetizationSettingsProvider
ios/gpscamera/Info.plist - AdMob app ID + SKAdNetworkItems (merged into the generated Info.plist)
ios/gpscamera.storekit - StoreKit test config (local purchases with the Apple key; wired in the shared scheme)
```

Dependencies: `purchases-ios-spm` (RevenueCat, SPM), `lottie-ios` (SPM),
`swift-package-manager-google-mobile-ads` (AdMob, SPM).

Android: planned.

## Revision History

- 2026-07-18: Paywall trigger changed to first-capture-per-session (was lifetime
  milestones); ad cadence 5 (was 10). Pure predicates `NudgeRules.paywallEarned`
  and `InterstitialAds.adEarned` added, covered by `MonetizationValueTests`.
- 2026-07-14: AdMob SKAdNetwork IDs synced.
- 2026-07-07: Photo/video nudge paths merged (`captureCompleted`, single
  `onCapture` hook); paywall milestones count lifetime captures.
- 2026-07-07: Ad cadence counts photos + videos, read from the `UsageMetrics`
  session counters (own session counter removed); videos now forward to the
  ad trigger too.
- 2026-07-07: Nudge orchestrator + in-app review (`NudgeOrchestrator`,
  `NudgeRules`); paywall-precedes-ad conflict rule; `review_requested` event
  + `nudge` paywall source.
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
