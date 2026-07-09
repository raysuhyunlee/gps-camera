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

    /// The map box shows left of the card; both need a fix to place the pin.
    private var showMap: Bool { settings.showMap && snapshot != nil }

    var body: some View {
        // Map + card are one layer (drag together) but read as separate objects,
        // spaced apart (overlay.md "Items"). Total width stays the same whether
        // the map is on or off, so anchoring is unaffected.
        HStack(alignment: .center, spacing: OverlayLayerMetrics.mapGap) {
            if showMap { mapBox }
            infoCard
        }
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let s = snapshot {
                Grid(alignment: .leadingFirstTextBaseline,
                     horizontalSpacing: 8, verticalSpacing: 6) {
                    rows(for: s)
                }
            }
            if settings.showWatermark {
                Text(L("Geotagged with GPS Camera"))
                    .font(settings.style.textFont(settings.style.fontSize * 0.85).italic())
                    .opacity(0.7)
            }
        }
        .font(settings.style.textFont(settings.style.fontSize))
        .foregroundStyle(settings.style.textColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        // Fixed card width so every item fits on one line, identically live and
        // burned; the map (fixed side + gap) eats into it when shown.
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
    }

    private var cardWidth: CGFloat {
        let full = OverlayLayerMetrics.designWidth - 2 * OverlayLayerMetrics.margin
        return showMap ? full - OverlayLayerMetrics.mapSide - OverlayLayerMetrics.mapGap : full
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
                Text(OverlayFormatter.time(s.timestamp))
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
