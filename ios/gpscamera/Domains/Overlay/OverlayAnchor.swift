import SwiftUI

/// The 9-grid anchor the overlay layer snaps to (overlay.md "Position & scale
/// editor"). World-space: the anchor names a corner of the upright scene, so it
/// is preserved across device rotation — a top-leading overlay stays at the
/// world top-left when the phone turns to landscape. Pure, unit-testable.
nonisolated enum OverlayAnchor: CaseIterable {
    case topLeading, top, topTrailing
    case leading, center, trailing
    case bottomLeading, bottom, bottomTrailing

    /// World unit position (x right, y down), components in {0, 0.5, 1}.
    var unit: CGPoint {
        switch self {
        case .topLeading:     return CGPoint(x: 0,   y: 0)
        case .top:            return CGPoint(x: 0.5, y: 0)
        case .topTrailing:    return CGPoint(x: 1,   y: 0)
        case .leading:        return CGPoint(x: 0,   y: 0.5)
        case .center:         return CGPoint(x: 0.5, y: 0.5)
        case .trailing:       return CGPoint(x: 1,   y: 0.5)
        case .bottomLeading:  return CGPoint(x: 0,   y: 1)
        case .bottom:         return CGPoint(x: 0.5, y: 1)
        case .bottomTrailing: return CGPoint(x: 1,   y: 1)
        }
    }

    /// Nearest anchor for a continuous world unit position (split in thirds).
    init(nearest unit: CGPoint) {
        func snap(_ v: CGFloat) -> CGFloat { v < 1 / 3 ? 0 : v > 2 / 3 ? 1 : 0.5 }
        let snapped = CGPoint(x: snap(unit.x), y: snap(unit.y))
        self = Self.allCases.first { $0.unit == snapped } ?? .center
    }

    /// Where the anchor sits on the portrait-locked screen for a device
    /// orientation. Same convention as camera's anchored controls: in
    /// landscapeLeft the world top edge is the screen's trailing edge.
    func screenUnit(for orientation: UIDeviceOrientation) -> CGPoint {
        let w = unit
        switch orientation {
        case .landscapeLeft:      return CGPoint(x: 1 - w.y, y: w.x)
        case .landscapeRight:     return CGPoint(x: w.y, y: 1 - w.x)
        case .portraitUpsideDown: return CGPoint(x: 1 - w.x, y: 1 - w.y)
        default:                  return w
        }
    }

    /// Inverse of `screenUnit`: the world unit for a screen unit position —
    /// used to resolve where a drag (screen space) landed in world space.
    static func worldUnit(fromScreen s: CGPoint,
                          orientation: UIDeviceOrientation) -> CGPoint {
        switch orientation {
        case .landscapeLeft:      return CGPoint(x: s.y, y: 1 - s.x)
        case .landscapeRight:     return CGPoint(x: 1 - s.y, y: s.x)
        case .portraitUpsideDown: return CGPoint(x: 1 - s.x, y: 1 - s.y)
        default:                  return s
        }
    }

    /// Counter-rotation that keeps the layer upright in world space.
    static func angle(for orientation: UIDeviceOrientation) -> Angle {
        switch orientation {
        case .landscapeLeft:      return .degrees(90)
        case .landscapeRight:     return .degrees(-90)
        case .portraitUpsideDown: return .degrees(180)
        default:                  return .degrees(0)   // portrait
        }
    }
}
