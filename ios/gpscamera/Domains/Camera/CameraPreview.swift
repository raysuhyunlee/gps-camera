import SwiftUI
import AVFoundation

/// Hosts an `AVCaptureVideoPreviewLayer` for the live camera feed. While
/// `freezeFrame` is non-nil the last frame is shown blurred on top, so lens /
/// facing / mode switches never flicker to black (camera.md "Device Orientation").
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    var freezeFrame: UIImage?

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.setFreeze(freezeFrame)
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

        private var freezeViews: [UIView] = []

        /// Non-nil: freeze `image` (blurred) over the feed. Nil: fade it out.
        func setFreeze(_ image: UIImage?) {
            if let image {
                guard freezeViews.isEmpty else { return }   // keep the first frozen frame
                let frame = UIImageView(image: image)
                frame.frame = bounds
                frame.contentMode = .scaleAspectFill
                frame.clipsToBounds = true
                let blur = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
                blur.frame = bounds
                for view in [frame, blur] {
                    view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                    addSubview(view)
                }
                freezeViews = [frame, blur]
            } else if !freezeViews.isEmpty {
                let views = freezeViews
                freezeViews = []
                UIView.animate(withDuration: 0.25) {
                    views.forEach { $0.alpha = 0 }
                } completion: { _ in
                    views.forEach { $0.removeFromSuperview() }
                }
            }
        }
    }
}
