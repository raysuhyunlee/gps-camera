//
//  ScreenshotUITests.swift
//  Drives the app in screenshot demo mode (screenshots.md) and captures the
//  hero screens per locale via fastlane snapshot. The app itself synthesizes an
//  authentic camera screen (scene photo + curated overlay); this test only
//  navigates. The scene is chosen per App Store storefront (the fastlane locale)
//  via `sceneForStore`; `SCREENSHOT_SCENE`/`SCREENSHOT_PRO` env override it.
//

import XCTest

final class ScreenshotUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureScreens() throws {
        let env = ProcessInfo.processInfo.environment
        let pro = env["SCREENSHOT_PRO"] ?? "1"

        let app = XCUIApplication()
        setupSnapshot(app)   // populates Snapshot.deviceLanguage (the store locale)
        let scene = env["SCREENSHOT_SCENE"] ?? Self.sceneForStore(Snapshot.deviceLanguage)
        app.launchArguments += ["-ScreenshotDemo", "1", "-Scene", scene, "-ScreenshotPro", pro]
        app.launch()

        // 1. Main - live camera surface with the overlay card + map.
        snapshot("01Main")

        // 2. Settings - the customization surface (a sheet; dismiss after).
        //    Scroll to the Overlay section: it is the app's headline feature, so
        //    it should lead the shot rather than the generic Capture rows.
        let settings = app.buttons["settingsButton"]
        if settings.waitForExistence(timeout: 5) {
            settings.tap()
            // A controlled drag (not swipeUp's fling, which overshoots to the
            // bottom) lifts the Capture rows off so Overlay leads the shot.
            let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.82))
            let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.36))
            from.press(forDuration: 0.1, thenDragTo: to, withVelocity: .default,
                       thenHoldForDuration: 0.1)
            snapshot("02Settings")
            dismissSheet(app)   // back to Main so the gallery button is hittable
        }

        // 3. Gallery - the seeded captures grid, posed in multi-select with two
        //    items picked to show batch share/delete (last; no dismissal needed).
        let gallery = app.buttons["galleryButton"]
        if gallery.waitForExistence(timeout: 5) {
            gallery.tap()
            let select = app.buttons["selectButton"]
            if select.waitForExistence(timeout: 5) {
                select.tap()
                cell(app, col: 0, row: 0).tap()   // newest
                cell(app, col: 1, row: 0).tap()
            }
            snapshot("03Gallery")
        }
    }

    /// A gallery grid cell (3 columns), addressed by normalized position so no
    /// per-item accessibility id is needed. Row 0 sits just under the nav bar.
    private func cell(_ app: XCUIApplication, col: Int, row: Int) -> XCUICoordinate {
        let x = 0.17 + Double(col) * 0.33
        let y = 0.19 + Double(row) * 0.24
        return app.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y))
    }

    /// Drag from the top down to dismiss a presented sheet.
    private func dismissSheet(_ app: XCUIApplication) {
        let top = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08))
        let bottom = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.92))
        top.press(forDuration: 0.1, thenDragTo: bottom)
    }

    // MARK: - Store -> scene

    /// Camera scene (`screenshot-scene-<id>.jpg`) per App Store storefront, keyed
    /// by the fastlane locale (`Snapfile` languages). Every store falls back to
    /// `defaultScene`; override a single store by adding its locale here.
    private static let scenesByStore: [String: String] = [:]
    private static let defaultScene = "new-york"

    static func sceneForStore(_ locale: String) -> String {
        scenesByStore[locale] ?? defaultScene
    }
}
