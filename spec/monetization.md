# Monetization

## Status

- 2026-06-30: Initial spec.

## Domain Definition

- **Interests**: Pro subscription, IAP products, the paywall, feature gating
  (the `Entitlement`), interstitial ads, and the nudge orchestrator.
- **Non-interests**: the gated features themselves — each domain reads
  `Entitlement` and gates its own settings/behavior.

## Details

### Entitlement

- `EntitlementProviding` seam exposes `.free` / `.pro`.
- Read by every domain for gating; by `SettingsRegistry` to lock `.pro` items.
- Pro unlocks: remove ads · remove watermark · overlay style settings ·
  filename settings.

### Products & purchase

- One-time **$12** (lifetime Pro) · monthly **$4**, sold through the platform's
  in-app purchase/billing API (StoreKit on iOS, Play Billing on Android).
- Reference: competitor one-time ₩15,000.
- **Restore purchase**: re-validates entitlement.

### Paywall

- Reuses the Travel English paywall component; design restyled only, logic intact.

### Pro banner

A shared widget (`Control.custom`) with two states:

- **Free** → nudging CTA to subscribe.
- **Subscribed** → status display + manage-subscription CTA.

### Ads

- Free users only. Interstitial shown every **10 photos**; counter resets per
  session.
- Driven by the foundation usage-metrics bus (photo count). Removed for `.pro`.

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

## Revision History

- 2026-06-30: Initial monetization spec (subscription, ads, nudge).
