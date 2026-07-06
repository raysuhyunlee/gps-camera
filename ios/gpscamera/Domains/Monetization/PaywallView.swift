//
//  PaywallView.swift
//  Monetization - the paywall (monetization.md "Paywall"). Layout borrowed from
//  Travel English's paywall (close row, hero, feature rows, selectable price
//  cards, pinned CTA + link row); restyled to this app's native look.
//

import RevenueCat
import SwiftUI

/// Seam consumed by screens that route to the paywall (overview.md "Domain
/// wiring"). Domains never import each other's UI, so it returns an AnyView.
protocol PaywallProviding {
    func paywallScreen() -> AnyView
}

extension ProStore: PaywallProviding {
    func paywallScreen() -> AnyView {
        AnyView(PaywallView(store: self, source: .lockedSetting))
    }
}

struct PaywallView: View {
    @ObservedObject var store: ProStore
    /// Where the paywall was opened from; fires paywall_shown (event.md).
    let source: Event.PaywallSource
    @Environment(\.dismiss) private var dismiss
    @State private var selectedID: String?
    @State private var purchasing = false
    @State private var failureMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            closeRow
            ScrollView {
                VStack(spacing: 28) {
                    hero
                    featureList
                    pricing
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
            }
            ctaArea
        }
        .background(Color(.systemBackground))
        .onAppear { store.events.track(.paywallShown(source: source)) }
        .task { await store.loadOfferings() }
        .alert("Purchase failed", isPresented: .init(
            get: { failureMessage != nil },
            set: { if !$0 { failureMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(failureMessage ?? "")
        }
    }

    // MARK: - Sections

    private var closeRow: some View {
        HStack {
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 8)
    }

    private var hero: some View {
        VStack(spacing: 12) {
            Image(systemName: "location.viewfinder")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)
            Text("GPS Camera Pro")
                .font(.largeTitle.bold())
            Text("Unlock every feature.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    /// Pro unlocks (overview.md "Business Model").
    private let features: [(icon: String, title: String)] = [
        ("rectangle.slash", "No ads"),
        ("signature", "Remove watermark"),
        ("paintbrush", "Customize geotag"),
        ("textformat", "Add logo and notes"),
    ]

    /// Hugs the longest feature text and centers in the parent; single line.
    private var featureList: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(features, id: \.title) { feature in
                HStack(spacing: 12) {
                    Image(systemName: feature.icon)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 30, height: 30)
                        .background(Color.accentColor.opacity(0.12),
                                    in: RoundedRectangle(cornerRadius: 9))
                    Text(feature.title)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
        }
    }

    @ViewBuilder
    private var pricing: some View {
        if !store.loaded {
            ProgressView().padding(.top, 12)
        } else if store.packages.isEmpty {
            Text("The store is unavailable right now.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 12)
        } else {
            VStack(spacing: 12) {
                ForEach(store.packages, id: \.identifier) { package in
                    card(package)
                }
            }
        }
    }

    private func card(_ package: Package) -> some View {
        let selected = package.identifier == selectedPackage?.identifier
        return Button { selectedID = package.identifier } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title(package)).font(.headline)
                    Text(priceLine(package))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if package.packageType == .lifetime {
                    Text("BEST VALUE")
                        .font(.caption2.bold())
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.12),
                                    in: Capsule())
                }
            }
            .padding(16)
            .background(selected ? Color.accentColor.opacity(0.08)
                                 : Color(.secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }

    private var ctaArea: some View {
        VStack(spacing: 12) {
            Button {
                Task { await buy() }
            } label: {
                Group {
                    if purchasing {
                        ProgressView()
                    } else {
                        Text("Continue").font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedPackage == nil || purchasing)
            linkRow
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var linkRow: some View {
        HStack(spacing: 6) {
            Button("Restore Purchase") {
                Task { await restore() }
            }
            .disabled(purchasing)
            divider
            Link("Terms", destination:
                    URL(string: "https://www.raysuhyunlee.com/gpscamera/tos")!)
            divider
            Link("Legal", destination:
                    URL(string: "https://www.raysuhyunlee.com/gpscamera/legal")!)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .tint(.secondary)
    }

    private var divider: some View {
        Text("|").font(.footnote).foregroundStyle(.tertiary)
    }

    // MARK: - Purchase

    /// Explicit tap, or the recommended default: lifetime (highest price).
    private var selectedPackage: Package? {
        store.packages.first { $0.identifier == selectedID } ?? store.packages.last
    }

    private func buy() async {
        guard let package = selectedPackage else { return }
        purchasing = true
        defer { purchasing = false }
        do {
            if try await store.purchase(package) { dismiss() }
            // false = user cancelled; no alert.
        } catch {
            failureMessage = "The purchase could not be completed. Please try again."
        }
    }

    private func restore() async {
        purchasing = true
        defer { purchasing = false }
        do {
            if try await store.restore() {
                dismiss()
            } else {
                failureMessage = "No previous purchase was found."
            }
        } catch {
            failureMessage = "Restore could not be completed. Please try again."
        }
    }

    private func title(_ package: Package) -> String {
        switch package.packageType {
        case .lifetime: return "Lifetime"
        case .monthly:  return "Monthly"
        default:        return package.storeProduct.localizedTitle
        }
    }

    private func priceLine(_ package: Package) -> String {
        let price = package.storeProduct.localizedPriceString
        return package.packageType == .monthly ? "\(price) / month" : "\(price) once"
    }
}

#Preview {
    PaywallView(store: ProStore(), source: .lockedSetting)
}
