import Combine
import CoreLocation
import UIKit

/// CoreLocation-backed `LocationProviding`. Publishes the latest snapshot.
final class LocationProvider: NSObject, ObservableObject, LocationProviding {
    @Published private(set) var snapshot: LocationSnapshot?
    @Published private(set) var authorization: PermissionStatus = .notDetermined

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    /// Locale for reverse-geocoded addresses. Bound by the composition root to
    /// the app language; the system locale until then.
    var preferredLocale: Locale = .current

    private var lastLocation: CLLocation?
    private var lastHeading: Heading?
    private var lastAddress: String?
    private var lastGeocodedAt: Date?
    private var permissionCompletions: [(PermissionStatus) -> Void] = []

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        authorization = Self.map(manager.authorizationStatus)
        #if DEBUG
        // Screenshot demo mode: seed a curated snapshot; start()/requestPermission()
        // become no-ops below so a real fix never overwrites it.
        if ScreenshotDemo.current.isActive {
            snapshot = ScreenshotDemo.current.snapshot
            authorization = .authorized
        }
        #endif
    }

    func start() {
        #if DEBUG
        if ScreenshotDemo.current.isActive { return }
        #endif
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
        NotificationCenter.default.addObserver(
            self, selector: #selector(orientationChanged),
            name: UIDevice.orientationDidChangeNotification, object: nil)
        orientationChanged()
    }

    func stop() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
        NotificationCenter.default.removeObserver(
            self, name: UIDevice.orientationDidChangeNotification, object: nil)
    }

    func requestPermission(_ completion: @escaping (PermissionStatus) -> Void) {
        #if DEBUG
        if ScreenshotDemo.current.isActive {
            completion(.authorized)
            return
        }
        #endif

        let status = Self.map(manager.authorizationStatus)
        guard status == .notDetermined else {
            completion(status)
            return
        }
        permissionCompletions.append(completion)
        manager.requestWhenInUseAuthorization()
    }

    // MARK: - Orientation (keeps compass correct in portrait/landscape)

    @objc private func orientationChanged() {
        let o = UIDevice.current.orientation
        guard o.isValidInterfaceOrientation,
              let cl = CLDeviceOrientation(rawValue: Int32(o.rawValue)) else { return }
        manager.headingOrientation = cl
    }

    // MARK: - Snapshot assembly

    private func rebuildSnapshot() {
        guard let loc = lastLocation else { return }
        snapshot = LocationSnapshot(
            coordinate: Coordinate(latitude: loc.coordinate.latitude,
                                   longitude: loc.coordinate.longitude),
            altitude: loc.altitude,
            accuracyMeters: loc.horizontalAccuracy,
            heading: lastHeading,
            timestamp: loc.timestamp,
            address: lastAddress,
            weather: nil)
    }

    /// Re-geocodes the last fix, e.g. after `preferredLocale` changed. Clears the
    /// throttle: the language moved, not the place.
    func refreshAddress() {
        guard let loc = lastLocation else { return }
        lastGeocodedAt = nil
        reverseGeocode(loc)
    }

    private func reverseGeocode(_ loc: CLLocation) {
        let now = Date()
        if let last = lastGeocodedAt, now.timeIntervalSince(last) < 15 { return }
        lastGeocodedAt = now
        geocoder.reverseGeocodeLocation(loc, preferredLocale: preferredLocale) { [weak self] placemarks, _ in
            guard let self, let p = placemarks?.first else { return }
            self.lastAddress = [p.name, p.locality, p.administrativeArea, p.country]
                .compactMap { $0 }.joined(separator: ", ")
            self.rebuildSnapshot()
        }
    }

    private static func map(_ status: CLAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways: return .authorized
        case .denied, .restricted:                    return .denied
        default:                                      return .notDetermined
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationProvider: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = Self.map(manager.authorizationStatus)
        authorization = status
        guard status != .notDetermined else { return }

        let completions = permissionCompletions
        permissionCompletions.removeAll()
        completions.forEach { $0(status) }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        lastLocation = loc
        rebuildSnapshot()
        reverseGeocode(loc)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard newHeading.headingAccuracy >= 0 else { return }
        let deg = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        lastHeading = Heading(degrees: deg)
        rebuildSnapshot()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Non-fatal; keep last known snapshot.
    }
}
