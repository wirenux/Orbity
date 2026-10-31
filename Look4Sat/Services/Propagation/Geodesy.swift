import Foundation
import simd

enum Geodesy {
    static let a = 6378.137                         // WGS84, km
    static let f = 1 / 298.257223563
    static let e2 = f * (2 - f)

    /// Greenwich mean sidereal time, radians.
    static func gmst(_ date: Date) -> Double {
        let jd = date.timeIntervalSince1970 / 86400 + 2440587.5
        let d = jd - 2451545.0
        let t = d / 36525
        var deg = 280.46061837 + 360.98564736629 * d
                + 0.000387933 * t * t - t * t * t / 38_710_000
        deg = deg.truncatingRemainder(dividingBy: 360)
        if deg < 0 { deg += 360 }
        return deg * .pi / 180
    }

    static func temeToECEF(_ r: SIMD3<Double>, at date: Date) -> SIMD3<Double> {
        let th = gmst(date), c = cos(th), s = sin(th)
        return SIMD3(r.x * c + r.y * s, -r.x * s + r.y * c, r.z)
    }

    static func observerECEF(_ o: Observer) -> SIMD3<Double> {
        let lat = o.latitude * .pi / 180, lon = o.longitude * .pi / 180
        let h = o.altitude / 1000
        let n = a / sqrt(1 - e2 * sin(lat) * sin(lat))
        return SIMD3((n + h) * cos(lat) * cos(lon),
                     (n + h) * cos(lat) * sin(lon),
                     (n * (1 - e2) + h) * sin(lat))
    }

    static func lookAngles(teme: SIMD3<Double>, observer o: Observer, at date: Date) -> LookAngles {
        let sat = temeToECEF(teme, at: date)
        let d = sat - observerECEF(o)
        let lat = o.latitude * .pi / 180, lon = o.longitude * .pi / 180

        let east  = -sin(lon) * d.x + cos(lon) * d.y
        let north = -sin(lat) * cos(lon) * d.x - sin(lat) * sin(lon) * d.y + cos(lat) * d.z
        let up    =  cos(lat) * cos(lon) * d.x + cos(lat) * sin(lon) * d.y + sin(lat) * d.z

        let range = simd_length(d)
        var az = atan2(east, north) * 180 / .pi
        if az < 0 { az += 360 }
        return LookAngles(azimuth: az, elevation: asin(up / range) * 180 / .pi, range: range)
    }

    static func subPoint(teme: SIMD3<Double>, at date: Date) -> SubPoint {
        let r = temeToECEF(teme, at: date)
        let lon = atan2(r.y, r.x)
        let p = hypot(r.x, r.y)
        var lat = atan2(r.z, p * (1 - e2))
        var n = a
        for _ in 0..<5 {
            n = a / sqrt(1 - e2 * sin(lat) * sin(lat))
            lat = atan2(r.z + e2 * n * sin(lat), p)
        }
        let alt = p / cos(lat) - n
        var lonDeg = lon * 180 / .pi
        if lonDeg > 180 { lonDeg -= 360 }
        return SubPoint(latitude: lat * 180 / .pi, longitude: lonDeg, altitudeKm: alt)
    }
}
