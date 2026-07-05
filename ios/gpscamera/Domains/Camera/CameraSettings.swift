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
        let videoPreset: AVCaptureSession.Preset = switch store.string(CameraSettingKey.videoResolution) {
        case "1080p": .hd1920x1080
        case "720p": .hd1280x720
        default: .high
        }
        quality = CaptureQuality(
            photoPreset: store.string(CameraSettingKey.photoResolution) == "1080p"
                ? .hd1920x1080 : .photo,
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
    var photoPreset: AVCaptureSession.Preset = .photo
    var videoPreset: AVCaptureSession.Preset = .high
    var fps: Int = 30
}

/// Capture -> Photo / Video / EXIF sections (camera.md "Settings"; placement
/// from overview.md).
nonisolated struct CameraSettingsProvider: SettingsProviding {
    var settingsSections: [SettingsSection] {
        [SettingsSection(id: "camera.capture", titleKey: "Capture", items: [
            SettingItem(key: CameraSettingKey.shutterSound, titleKey: "Shutter sound",
                        control: .toggle, defaultValue: .bool(true)),
            SettingItem(key: CameraSettingKey.orientationLock, titleKey: "Orientation lock",
                        control: .toggle, defaultValue: .bool(false)),
            SettingItem(key: "camera.nav.photo", titleKey: "Photo",
                        control: .navigation(sectionRef: "camera.photo")),
            SettingItem(key: "camera.nav.video", titleKey: "Video",
                        control: .navigation(sectionRef: "camera.video")),
            SettingItem(key: "camera.nav.exif", titleKey: "EXIF",
                        control: .navigation(sectionRef: "camera.exif")),
        ]),
        SettingsSection(id: "camera.photo", titleKey: "Photo", items: [
            SettingItem(key: CameraSettingKey.photoResolution, titleKey: "Resolution",
                        control: .select([SelectOption(value: "max", titleKey: "Maximum"),
                                          SelectOption(value: "1080p", titleKey: "1080p")]),
                        defaultValue: .string("max")),
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
                        control: .select([SelectOption(value: "max", titleKey: "Maximum"),
                                          SelectOption(value: "1080p", titleKey: "1080p"),
                                          SelectOption(value: "720p", titleKey: "720p")]),
                        defaultValue: .string("max")),
            SettingItem(key: CameraSettingKey.videoFPS, titleKey: "FPS",
                        control: .select([SelectOption(value: "30", titleKey: "30"),
                                          SelectOption(value: "60", titleKey: "60")]),
                        defaultValue: .string("30")),
        ]),
        SettingsSection(id: "camera.exif", titleKey: "EXIF", items: [
            SettingItem(key: CameraSettingKey.exifLocation, titleKey: "Include EXIF location",
                        footnoteKey: "Includes location data in the photo file.",
                        control: .toggle, defaultValue: .bool(true),
                        requiresPermission: .location),
        ])]
    }
}
