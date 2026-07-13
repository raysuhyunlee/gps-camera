import Foundation

protocol LocationProviding: AnyObject {
    /// Latest snapshot, nil until the first fix.
    var snapshot: LocationSnapshot? { get }
    var authorization: PermissionStatus { get }

    func start()
    func stop()
    func requestPermission(_ completion: @escaping (PermissionStatus) -> Void)
}

extension LocationProviding {
    func requestPermission() {
        requestPermission { _ in }
    }
}
