//
//  CameraSettings.swift
//  Camera - settings schema + typed read (camera.md "Settings").
//

import AVFoundation
import Foundation

nonisolated enum CameraSettingKey {
    static let shutterSound = "camera.shutterSound"
    static let orientationLock = "camera.orientationLock"
    static let photoResolution = "camera.photo.resolution"
    static let photoFormat = "camera.photo.format"
    static let saveOriginal = "camera.photo.saveOriginal"
    static let saveToPhotos = "camera.saveToPhotos"
    static let videoResolution = "camera.video.resolution"
    static let videoFPS = "camera.video.fps"
    static let exifLocation = "camera.exif.location"
}

/// Concrete capture capabilities of the back wide camera - the source of the
/// resolution options offered in Settings. Falls back to nominal options when
/// no camera is present (simulator).
nonisolated enum CameraCapabilities {
    private static var backWide: AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    }

    /// Distinct 4:3 photo output sizes, largest first.
    static func photoDimensions() -> [CaptureQuality.Dimensions] {
        guard let device = backWide else {
            return [CaptureQuality.Dimensions(width: 4032, height: 3024)]
        }
        var seen = Set<Int64>()
        let dims = device.formats
            .flatMap(\.supportedMaxPhotoDimensions)
            .filter { Int64($0.width) * 3 == Int64($0.height) * 4 }
            .map { CaptureQuality.Dimensions(width: $0.width, height: $0.height) }
            .sorted { $0.area > $1.area }
            .filter { seen.insert($0.area).inserted }
        return dims.isEmpty ? [CaptureQuality.Dimensions(width: 4032, height: 3024)] : dims
    }

    /// Video presets the hardware supports, highest first.
    static func videoOptions() -> [(value: String, title: L10nKey, preset: AVCaptureSession.Preset)] {
        let all: [(String, L10nKey, AVCaptureSession.Preset)] = [
            ("2160p", "4K (3840x2160)", .hd4K3840x2160),
            ("1080p", "1080p (1920x1080)", .hd1920x1080),
            ("720p", "720p (1280x720)", .hd1280x720),
        ]
        guard let device = backWide else { return all }
        let supported = all.filter { device.supportsSessionPreset($0.2) }
        return supported.isEmpty ? all : supported
    }
}

/// Typed snapshot of the camera settings, read at use time (shutter / record /
/// session configure) so edits apply immediately.
nonisolated struct CameraSettings {
    let shutterSound: Bool
    let orientationLock: Bool
    let saveOriginal: Bool
    let photoFormat: PhotoFormat
    let quality: CaptureQuality

    enum PhotoFormat: String {
        case jpg, heic
        var ext: String { rawValue }
    }

    init(from store: SettingsStore) {
        shutterSound = store.bool(CameraSettingKey.shutterSound)
        orientationLock = store.bool(CameraSettingKey.orientationLock)
        saveOriginal = store.bool(CameraSettingKey.saveOriginal)
        photoFormat = PhotoFormat(rawValue: store.string(CameraSettingKey.photoFormat)) ?? .jpg
        let videoPreset = CameraCapabilities.videoOptions()
            .first { $0.value == store.string(CameraSettingKey.videoResolution) }?
            .preset ?? .high
        quality = CaptureQuality(
            // Unparseable value (fresh device swap) -> nil -> largest available.
            photo: CaptureQuality.Dimensions(store.string(CameraSettingKey.photoResolution)),
            videoPreset: videoPreset,
            fps: store.string(CameraSettingKey.videoFPS) == "60" ? 60 : 30)
    }

    // Permission-coupled reads (foundation.md): effective = on && granted;
    // revocation skips the feature and may post the mismatch popup.

    static func effectiveExifLocation(_ store: SettingsStore) -> Bool {
        store.effectiveBool(CameraSettingKey.exifLocation, permission: .location)
    }

    static func effectiveSaveToPhotos(_ store: SettingsStore) -> Bool {
        store.effectiveBool(CameraSettingKey.saveToPhotos, permission: .photoAddOnly)
    }
}

/// Session quality knobs derived from the resolution/fps settings.
nonisolated struct CaptureQuality: Equatable {
    /// nil = largest the active format supports.
    var photo: Dimensions? = nil
    var videoPreset: AVCaptureSession.Preset = .high
    var fps: Int = 30

    /// A photo output size; persisted as "WxH" (the select option value).
    struct Dimensions: Equatable {
        var width: Int32
        var height: Int32

        var area: Int64 { Int64(width) * Int64(height) }
        var value: String { "\(width)x\(height)" }
        var title: L10nKey {
            let mp = (Double(area) / 1_000_000).rounded()
            return "\(Int(mp)) MP (\(width)x\(height))"
        }

        init(width: Int32, height: Int32) {
            self.width = width
            self.height = height
        }

        init?(_ value: String) {
            let parts = value.split(separator: "x").compactMap { Int32($0) }
            guard parts.count == 2 else { return nil }
            self.init(width: parts[0], height: parts[1])
        }
    }
}

/// Capture -> Photo / Video / EXIF sections (camera.md "Settings"; placement
/// from overview.md). Resolution options are concrete values read from the
/// hardware; the default is the highest available.
nonisolated struct CameraSettingsProvider: SettingsProviding {
    var settingsSections: [SettingsSection] {
        let photoDims = CameraCapabilities.photoDimensions()
        let videoOptions = CameraCapabilities.videoOptions()
        return [SettingsSection(id: "camera.capture", titleKey: "Capture", items: [
            SettingItem(key: CameraSettingKey.shutterSound, titleKey: "Shutter sound",
                        control: .toggle, defaultValue: .bool(true)),
            SettingItem(key: CameraSettingKey.orientationLock, titleKey: "Orientation lock",
                        control: .toggle, defaultValue: .bool(false)),
            SettingItem(key: CameraSettingKey.exifLocation, titleKey: "Include EXIF location",
                        footnoteKey: "Includes location data in the photo file.",
                        control: .toggle, defaultValue: .bool(true),
                        requiresPermission: .location),
            SettingItem(key: "camera.nav.photo", titleKey: "Photo",
                        control: .navigation(sectionRef: "camera.photo")),
            SettingItem(key: "camera.nav.video", titleKey: "Video",
                        control: .navigation(sectionRef: "camera.video")),
        ]),
        SettingsSection(id: "camera.photo", titleKey: "Photo", items: [
            SettingItem(key: CameraSettingKey.photoResolution, titleKey: "Resolution",
                        control: .select(photoDims.map {
                            SelectOption(value: $0.value, titleKey: $0.title)
                        }),
                        defaultValue: .string(photoDims[0].value)),
            SettingItem(key: CameraSettingKey.photoFormat, titleKey: "Format",
                        control: .select([SelectOption(value: "jpg", titleKey: "JPG"),
                                          SelectOption(value: "heic", titleKey: "HEIC")]),
                        defaultValue: .string("jpg")),
            SettingItem(key: CameraSettingKey.saveOriginal, titleKey: "Also save original",
                        footnoteKey: "Keeps a copy without the overlay.",
                        control: .toggle, defaultValue: .bool(true)),
            SettingItem(key: CameraSettingKey.saveToPhotos, titleKey: "Save to Camera Roll",
                        control: .toggle, defaultValue: .bool(true),
                        requiresPermission: .photoAddOnly),
        ]),
        SettingsSection(id: "camera.video", titleKey: "Video", items: [
            SettingItem(key: CameraSettingKey.videoResolution, titleKey: "Resolution",
                        control: .select(videoOptions.map {
                            SelectOption(value: $0.value, titleKey: $0.title)
                        }),
                        defaultValue: .string(videoOptions[0].value)),
            SettingItem(key: CameraSettingKey.videoFPS, titleKey: "FPS",
                        control: .select([SelectOption(value: "30", titleKey: "30"),
                                          SelectOption(value: "60", titleKey: "60")]),
                        defaultValue: .string("30")),
        ])]
    }
}
