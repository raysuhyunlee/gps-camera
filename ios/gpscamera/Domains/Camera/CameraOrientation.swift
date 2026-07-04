import SwiftUI

/// Maps device orientation to the angles the camera domain needs (camera.md
/// "Device Orientation"). Pure, so it is unit-testable and shared by the
/// on-screen controls and the capture connection.
enum CameraOrientation {
    /// Counter-rotation that keeps the SwiftUI controls/overlay upright.
    static func controlAngle(for orientation: UIDeviceOrientation) -> Angle {
        switch orientation {
        case .landscapeLeft:      return .degrees(90)
        case .landscapeRight:     return .degrees(-90)
        case .portraitUpsideDown: return .degrees(180)
        default:                  return .degrees(0)   // portrait
        }
    }

    /// Clockwise rotation (degrees) for an `AVCaptureConnection` so the captured
    /// photo/video is upright. 90 = portrait (home indicator down).
    static func videoRotationAngle(for orientation: UIDeviceOrientation) -> CGFloat {
        switch orientation {
        case .landscapeLeft:      return 180
        case .landscapeRight:     return 0
        case .portraitUpsideDown: return 270
        default:                  return 90   // portrait
        }
    }

    /// Alignment on the (portrait-locked) screen that puts an anchored control
    /// at the world-space top-middle for the given device orientation.
    static func anchorAlignment(for orientation: UIDeviceOrientation) -> Alignment {
        switch orientation {
        case .landscapeLeft:      return .trailing   // world top = right edge
        case .landscapeRight:     return .leading
        case .portraitUpsideDown: return .bottom
        default:                  return .top
        }
    }
}
