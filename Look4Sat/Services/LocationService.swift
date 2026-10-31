import CoreLocation
import Observation

@MainActor @Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    @ObservationIgnored private let manager = CLLocationManager()
    var gps: CLLocation?
    var heading: Double?                       // degrees, true north if available
    var authorization: CLAuthorizationStatus = .notDetermined
    var lastError: String?

    /// Manual override from Settings takes priority over GPS.
    var observer: Observer? {
        let d = UserDefaults.standard
        if d.bool(forKey: "useManualLocation") {
            return Observer(latitude: d.double(forKey: "manualLat"),
                            longitude: d.double(forKey: "manualLon"),
                            altitude: 0)
        }
        guard let l = gps else { return nil }
        return Observer(latitude: l.coordinate.latitude,
                        longitude: l.coordinate.longitude,
                        altitude: l.altitude)
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.headingFilter = 3
        authorization = manager.authorizationStatus
    }

    func start() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
            if CLLocationManager.headingAvailable() { manager.startUpdatingHeading() }
        default:
            break
        }
    }

    /// Called by the "Use my location" button.
    func requestLocation() {
        lastError = nil
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else {
            manager.requestLocation()              // one-shot fix
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        let status = m.authorizationStatus
        Task { @MainActor in
            self.authorization = status
            if status == .authorizedWhenInUse || status == .authorizedAlways { self.start() }
        }
    }

    nonisolated func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        Task { @MainActor in self.gps = locs.last; self.lastError = nil }
    }

    nonisolated func locationManager(_ m: CLLocationManager, didUpdateHeading h: CLHeading) {
        let v = h.trueHeading >= 0 ? h.trueHeading : h.magneticHeading
        Task { @MainActor in self.heading = v }
    }

    nonisolated func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {
        let msg = error.localizedDescription
        Task { @MainActor in self.lastError = msg }
    }
}
