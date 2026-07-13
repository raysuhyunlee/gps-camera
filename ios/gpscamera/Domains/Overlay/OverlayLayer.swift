import SwiftUI

/// The overlay layer content: enabled items as icon + value rows over a
/// semi-transparent background, plus the watermark. Rendered three ways
/// (overlay.md "Rendering"): live on Main, rasterized for burning, and as the
/// settings preview (later).
struct OverlayLayer: View {
    let snapshot: LocationSnapshot?
    let settings: OverlaySettings
    /// The map image (map item); nil while it is off or not yet rendered.
    var mapImage: UIImage? = nil
    /// Width available to the whole layer in reference-space points.
    var maximumWidth = OverlayLayerMetrics.maximumWidth

    /// Re-renders the live overlay when the language changes: none of the inputs
    /// above move, so SwiftUI would otherwise keep the old language's strings.
    @ObservedObject private var l10n = L10n.shared

    /// The map box shows left of the card; both need a fix to place the pin.
    private var showMap: Bool { settings.showMap && snapshot != nil }

    var body: some View {
        // The watermark badge sits above, aligned to the layer's right edge, and
        // moves with the layer (overlay.md "Watermark badge"). Map + card are one
        // layer (drag together) but read as separate objects, spaced apart
        // (overlay.md "Items"). Total width stays the same whether the map is on
        // or off, so anchoring is unaffected.
        VStack(alignment: .trailing, spacing: OverlayLayerMetrics.mapGap) {
            if settings.showWatermark { watermarkBadge }
            if snapshot != nil {
                HStack(alignment: .center, spacing: OverlayLayerMetrics.mapGap) {
                    if showMap { mapBox }
                    infoCard
                }
            }
        }
    }

    /// Brand badge: app logo + name, its own box separate from the info card.
    private var watermarkBadge: some View {
        HStack(spacing: 5) {
            Image("AppLogo").resizable()
                .frame(width: settings.style.fontSize * 1.3,
                       height: settings.style.fontSize * 1.3)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            Text(L("GPS Camera"))
                .font(settings.style.textFont(settings.style.fontSize * 0.9))
        }
        .foregroundStyle(settings.style.textColor)
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(settings.style.bgColor.opacity(settings.style.bgOpacity),
                    in: RoundedRectangle(cornerRadius: 8))
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let s = snapshot {
                Grid(alignment: .leadingFirstTextBaseline,
                     horizontalSpacing: 8, verticalSpacing: 6) {
                    rows(for: s)
                }
            }
        }
        .font(settings.style.textFont(settings.style.fontSize))
        .foregroundStyle(settings.style.textColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        // Keep a deterministic reference-space width so Grid does not collapse
        // to its minimum content width. The whole layer is still capped to the
        // live/media width through `maximumWidth`.
        .frame(width: cardWidth, alignment: .leading)
        .background(settings.style.bgColor.opacity(settings.style.bgOpacity),
                    in: RoundedRectangle(cornerRadius: 8))
    }

    private var mapBox: some View {
        ZStack {
            if let mapImage {
                Image(uiImage: mapImage).resizable()
            } else {
                settings.style.bgColor.opacity(settings.style.bgOpacity)
            }
        }
        .frame(width: OverlayLayerMetrics.mapSide, height: OverlayLayerMetrics.mapSide)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        // "You are here": the snapshot is centered on the coordinate.
        .overlay {
            Circle().fill(.red)
                .frame(width: 8, height: 8)
                .overlay(Circle().stroke(.white, lineWidth: 1.5))
        }
        // Lets the screenshot UI test wait for the async map snapshot to land
        // before capturing Main (screenshots.md); no-op in Release.
        .screenshotMapMarker(ready: mapImage != nil)
    }

    private var cardWidth: CGFloat {
        let mapWidth = showMap
            ? OverlayLayerMetrics.mapSide + OverlayLayerMetrics.mapGap
            : 0
        return max(0, maximumWidth - mapWidth)
    }

    /// Empty when there is nothing to show (no fix and the watermark off).
    var isEmpty: Bool { snapshot == nil && !settings.showWatermark }

    @ViewBuilder
    private func rows(for s: LocationSnapshot) -> some View {
        let style = settings.style
        if settings.showAddress, let address = s.address {
            GridRow {
                icon("mappin.and.ellipse")
                Text(address)
            }
        }
        if settings.showCoordinates {
            GridRow {
                icon("globe")
                Text(OverlayFormatter.coordinates(s.coordinate, format: style.coordFormat))
            }
        }
        // Altitude + accuracy share a row (both short), like the reference UI.
        if settings.showAltitude {
            GridRow {
                icon("mountain.2")
                HStack(spacing: 8) {
                    Text(OverlayFormatter.altitude(s.altitude, unit: style.unit))
                    if settings.showAccuracy {
                        Text("|").opacity(0.4)
                        icon("scope")
                        accuracy(s)
                    }
                }
            }
        } else if settings.showAccuracy {
            GridRow {
                icon("scope")
                accuracy(s)
            }
        }
        if settings.showHeading, let heading = s.heading {
            GridRow {
                icon("safari")
                Text(OverlayFormatter.heading(heading))
            }
        }
        if settings.showTime {
            GridRow {
                icon("clock")
                Text(OverlayFormatter.time(s.timestamp, locale: l10n.locale))
            }
        }
    }

    private func icon(_ systemName: String) -> some View {
        Image(systemName: systemName).font(.system(size: settings.style.fontSize))
    }

    private func accuracy(_ s: LocationSnapshot) -> some View {
        Text(OverlayFormatter.accuracy(s.accuracyMeters, unit: settings.style.unit))
            .foregroundStyle(color(for: s.accuracyLevel))
    }

    private func color(for level: AccuracyLevel) -> Color {
        switch level {
        case .good:   return .green
        case .normal: return .yellow
        case .bad:    return .red
        }
    }
}

private extension View {
    /// DEBUG-only marker the screenshot UI test polls before capturing Main, so
    /// the async map snapshot has arrived (else the map box shows blank). The
    /// identifier flips to `overlayMapReady` once the image loads. No-op in
    /// Release, where it must not alter the overlay's accessibility tree.
    @ViewBuilder func screenshotMapMarker(ready: Bool) -> some View {
        #if DEBUG
        accessibilityElement()
            .accessibilityIdentifier(ready ? "overlayMapReady" : "overlayMapLoading")
        #else
        self
        #endif
    }
}

#Preview {
    ZStack {
        Color.gray
        OverlayLayer(
            snapshot: LocationSnapshot(
                coordinate: Coordinate(latitude: 37.5326, longitude: 127.0246),
                altitude: 38.2, accuracyMeters: 8.5,
                heading: Heading(degrees: 275), timestamp: .now,
                address: "12 Hannam-daero, Yongsan-gu, Seoul", weather: nil),
            settings: OverlaySettings())
    }
}
