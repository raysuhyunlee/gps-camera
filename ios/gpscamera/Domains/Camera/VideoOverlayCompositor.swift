import AVFoundation
import UIKit

/// Burns a rendered overlay layer into a recorded movie - the video half of
/// camera.md pipeline step 2. `AVCaptureMovieFileOutput` cannot composite live,
/// so the overlay (rasterized once at record start, like the GPS metadata) is
/// exported onto the finished clip via an `AVVideoComposition` Core Animation
/// layer. Pure I/O over files; runs off the main actor.
nonisolated enum VideoOverlayCompositor {
    enum CompositeError: Error { case noVideoTrack, exportFailed }

    /// Export `source` with `overlay` burned in, writing to `output`.
    /// `completion` fires on an arbitrary queue.
    static func burn(_ overlay: RenderedOverlay,
                     from source: URL,
                     to output: URL,
                     completion: @escaping (Result<URL, Error>) -> Void) {
        Task {
            do {
                try await export(overlay, from: AVURLAsset(url: source), to: output)
                completion(.success(output))
            } catch {
                completion(.failure(error))
            }
        }
    }

    private static func export(_ overlay: RenderedOverlay,
                               from asset: AVURLAsset,
                               to output: URL) async throws {
        guard let sourceVideo = try await asset.loadTracks(withMediaType: .video).first
        else { throw CompositeError.noVideoTrack }
        let duration = try await asset.load(.duration)
        let range = CMTimeRange(start: .zero, duration: duration)

        // Copy video (+ audio, if any) into a composition we can re-encode.
        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        else { throw CompositeError.exportFailed }
        try videoTrack.insertTimeRange(range, of: sourceVideo, at: .zero)
        if let sourceAudio = try await asset.loadTracks(withMediaType: .audio).first,
           let audioTrack = composition.addMutableTrack(
            withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            try? audioTrack.insertTimeRange(range, of: sourceAudio, at: .zero)
        }

        // The recorded clip carries its rotation as a preferred transform, not
        // rotated pixels. Apply it so frames are upright in `renderSize`; the
        // overlay then places at the same world-space anchor as the photo burn.
        let transform = try await sourceVideo.load(.preferredTransform)
        let natural = try await sourceVideo.load(.naturalSize)
        let oriented = natural.applying(transform)
        let renderSize = CGSize(width: abs(oriented.width), height: abs(oriented.height))

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        layerInstruction.setTransform(transform, at: .zero)
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = range
        instruction.layerInstructions = [layerInstruction]

        // Core Animation tool composites in a bottom-left origin space.
        let videoLayer = CALayer()
        videoLayer.frame = CGRect(origin: .zero, size: renderSize)
        let parent = CALayer()
        parent.frame = videoLayer.frame
        parent.addSublayer(videoLayer)
        parent.addSublayer(overlayLayer(overlay, in: renderSize))

        let videoComposition = AVMutableVideoComposition()
        videoComposition.instructions = [instruction]
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer, in: parent)

        guard let session = AVAssetExportSession(
            asset: composition, presetName: AVAssetExportPresetHighestQuality)
        else { throw CompositeError.exportFailed }
        session.videoComposition = videoComposition
        session.outputURL = output
        session.outputFileType = .mov
        try? FileManager.default.removeItem(at: output)

        await session.export()
        guard session.status == .completed else {
            throw session.error ?? CompositeError.exportFailed
        }
    }

    /// Overlay CALayer placed at its world-space anchor, matching the photo burn
    /// (`PhotoCaptureService.burn`) but flipped into the bottom-left origin space
    /// the Core Animation tool renders in.
    private static func overlayLayer(_ overlay: RenderedOverlay,
                                     in renderSize: CGSize) -> CALayer {
        let scale = renderSize.width / OverlayLayerMetrics.designWidth
        let size = CGSize(width: overlay.image.size.width * scale,
                          height: overlay.image.size.height * scale)
        let margin = OverlayLayerMetrics.margin * scale
        let anchor = overlay.anchor.unit   // x right, y down (top = 0)
        let x = margin + anchor.x * (renderSize.width - size.width - 2 * margin)
        let yTop = margin + anchor.y * (renderSize.height - size.height - 2 * margin)
        let layer = CALayer()
        layer.contents = overlay.image.cgImage
        layer.contentsGravity = .resizeAspect
        // Flip: Core Animation origin is bottom-left, the anchor math is top-left.
        layer.frame = CGRect(x: x, y: renderSize.height - size.height - yTop,
                             width: size.width, height: size.height)
        return layer
    }
}
