//
//  GalleryValueTests.swift
//  Pure value-type logic for the gallery domain.
//

import Testing
import Foundation
@testable import gpscamera

/// A gallery item over a capture-store entry (the media itself lives in Photos).
private func item(_ name: String, ext: String = "jpg") -> GalleryItem {
    GalleryItem(entry: CaptureEntry(id: name, name: name, ext: ext, date: .now))
}

struct GalleryItemTests {
    @Test func kindFollowsExtension() {
        #expect(item("IMG_1", ext: "jpg").kind == .photo)
        #expect(item("IMG_2", ext: "heic").kind == .photo)
        #expect(item("IMG_3", ext: "MOV").kind == .video)
        #expect(item("IMG_4", ext: "mp4").kind == .video)
    }

    @Test func nextSelectionTakesTheDeletedIndex() {
        let items = ["a", "b", "c"].map { item($0) }
        #expect(items.nextSelection(afterDeleting: items[1]) == items[2])
    }

    @Test func nextSelectionFallsBackToLast() {
        let items = ["a", "b", "c"].map { item($0) }
        #expect(items.nextSelection(afterDeleting: items[2]) == items[1])
    }

    @Test func nextSelectionIsNilWhenLastItemGoes() {
        let items = [item("only")]
        #expect(items.nextSelection(afterDeleting: items[0]) == nil)
    }

    @Test func selectedKeepsListOrderAndIgnoresUnknownIDs() {
        let items = ["a", "b", "c"].map { item($0) }
        let ids: Set<String> = [items[2].id, items[0].id, "gone"]
        #expect(items.selected(ids) == [items[0], items[2]])
    }

    @Test func selectedIsEmptyForNoIDs() {
        let items = ["a", "b"].map { item($0) }
        #expect(items.selected([]).isEmpty)
    }
}
