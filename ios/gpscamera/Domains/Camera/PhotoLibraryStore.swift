//
//  PhotoLibraryStore.swift
//  Camera - the capture store (camera.md "Storage"): captures land straight in
//  the Photos library, and a local index records which assets are ours.
//  The index - not an album - is what scopes the gallery: a full-access grant
//  would otherwise list the user's whole library, and album fetches return
//  nothing under limited access.
//

import Photos
import UIKit

/// One capture the app wrote to the Photos library. `id` is the PHAsset
/// localIdentifier; `name` is the name `filename` assigned (no extension).
nonisolated struct CaptureEntry: Codable, Sendable, Hashable {
    let id: String
    let name: String
    let ext: String
    let date: Date

    var filename: String { "\(name).\(ext)" }
}

/// The app's own captures, newest first. Persisted next to the app (not in
/// Photos) and pruned whenever an indexed asset no longer exists - the user can
/// delete our media from the Photos app at any time.
nonisolated final class CaptureIndex: @unchecked Sendable {
    private let url: URL
    private let lock = NSLock()
    private var entries: [CaptureEntry]

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
        url = base.appendingPathComponent("captures.json")
        let data = (try? Data(contentsOf: url)) ?? Data()
        entries = (try? JSONDecoder().decode([CaptureEntry].self, from: data)) ?? []
    }

    func all() -> [CaptureEntry] {
        lock.withLock { entries }
    }

    /// Base names already taken - for filename auto-number.
    func baseNames() -> Set<String> {
        lock.withLock { Set(entries.map(\.name)) }
    }

    func add(_ entry: CaptureEntry) {
        lock.withLock {
            entries.append(entry)
            // Newest first; ties (a capture and its `_original`) by name, so the
            // capture precedes its `_original` copy.
            entries.sort { $0.date == $1.date ? $0.name < $1.name : $0.date > $1.date }
            save()
        }
    }

    /// Drops entries whose asset is gone (deleted in Photos, or access revoked).
    func keep(ids: Set<String>) {
        lock.withLock {
            guard entries.contains(where: { !ids.contains($0.id) }) else { return }
            entries.removeAll { !ids.contains($0.id) }
            save()
        }
    }

    func remove(ids: Set<String>) {
        lock.withLock {
            entries.removeAll { ids.contains($0.id) }
            save()
        }
    }

    // Callers hold the lock.
    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

/// Writes captures into the Photos library and indexes them. Reading back is
/// the `CaptureStoreBrowsing` seam (consumed by gallery).
nonisolated struct PhotoLibraryStore: Sendable {
    let index = CaptureIndex()

    enum StoreError: Error { case saveFailed }

    func existingBaseNames() -> Set<String> { index.baseNames() }

    /// Photo bytes -> one asset named `name.ext`. `date` is the capture moment: a
    /// photo and its `_original` share one, so gallery order does not depend on
    /// which of the two library writes lands first.
    func save(photo data: Data, name: String, ext: String, date: Date,
              completion: @escaping (Result<Void, Error>) -> Void) {
        create(name: name, ext: ext, date: date, completion: completion) { request, options in
            request.addResource(with: .photo, data: data, options: options)
        }
    }

    /// Recorded clip -> one asset named `name.ext`. The temp file is moved in.
    func save(video fileURL: URL, name: String, ext: String, date: Date,
              completion: @escaping (Result<Void, Error>) -> Void) {
        create(name: name, ext: ext, date: date, completion: completion) { request, options in
            options.shouldMoveFile = true
            request.addResource(with: .video, fileURL: fileURL, options: options)
        }
    }

    private func create(name: String, ext: String, date: Date,
                        completion: @escaping (Result<Void, Error>) -> Void,
                        body: @escaping (PHAssetCreationRequest,
                                         PHAssetResourceCreationOptions) -> Void) {
        var placeholder: PHObjectPlaceholder?
        PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.creationDate = date
            let options = PHAssetResourceCreationOptions()
            // Photos labels the asset IMG_xxxx in its own UI, but this is the
            // name the file carries on export/share (filename.md).
            options.originalFilename = "\(name).\(ext)"
            body(request, options)
            placeholder = request.placeholderForCreatedAsset
        } completionHandler: { ok, error in
            guard ok, let id = placeholder?.localIdentifier else {
                return completion(.failure(error ?? StoreError.saveFailed))
            }
            index.add(CaptureEntry(id: id, name: name, ext: ext, date: date))
            NotificationCenter.default.post(name: .captureStoreDidChange, object: nil)
            completion(.success(()))
        }
    }
}
