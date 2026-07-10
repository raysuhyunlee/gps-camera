//
//  GalleryValueTests.swift
//  Pure value-type logic for the gallery domain.
//

import Testing
import Foundation
@testable import gpscamera

struct GalleryItemTests {
    @Test func kindFollowsExtension() {
        #expect(GalleryItem(url: URL(fileURLWithPath: "/a/IMG_1.jpg")).kind == .photo)
        #expect(GalleryItem(url: URL(fileURLWithPath: "/a/IMG_2.heic")).kind == .photo)
        #expect(GalleryItem(url: URL(fileURLWithPath: "/a/IMG_3.MOV")).kind == .video)
        #expect(GalleryItem(url: URL(fileURLWithPath: "/a/IMG_4.mp4")).kind == .video)
    }

    @Test func nextSelectionTakesTheDeletedIndex() {
        let items = ["a", "b", "c"].map { GalleryItem(url: URL(fileURLWithPath: "/\($0).jpg")) }
        #expect(items.nextSelection(afterDeleting: items[1]) == items[2])
    }

    @Test func nextSelectionFallsBackToLast() {
        let items = ["a", "b", "c"].map { GalleryItem(url: URL(fileURLWithPath: "/\($0).jpg")) }
        #expect(items.nextSelection(afterDeleting: items[2]) == items[1])
    }

    @Test func nextSelectionIsNilWhenLastItemGoes() {
        let items = [GalleryItem(url: URL(fileURLWithPath: "/only.jpg"))]
        #expect(items.nextSelection(afterDeleting: items[0]) == nil)
    }

    @Test func selectedKeepsListOrderAndIgnoresUnknownIDs() {
        let items = ["a", "b", "c"].map { GalleryItem(url: URL(fileURLWithPath: "/\($0).jpg")) }
        let ids: Set<URL> = [items[2].url, items[0].url, URL(fileURLWithPath: "/gone.jpg")]
        #expect(items.selected(ids) == [items[0], items[2]])
    }

    @Test func selectedIsEmptyForNoIDs() {
        let items = ["a", "b"].map { GalleryItem(url: URL(fileURLWithPath: "/\($0).jpg")) }
        #expect(items.selected([]).isEmpty)
    }
}
