//
//  PermissionStatus.swift
//  Foundation - shared authorization state
//

import Foundation

/// Generic authorization state for any OS permission (location, camera,
/// photo library, ...). Each provider collapses platform-specific statuses
/// (e.g. restricted, limited, whenInUse/always) into these three.
nonisolated enum PermissionStatus {
    case notDetermined  // never asked; enabling the item should request it
    case denied         // asked and refused, or restricted
    case authorized     // granted (any granted variant)
}
