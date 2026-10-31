import SwiftUI

struct PolarPlotView: View {
    let track: [PolarPoint]
    var current: PolarPoint?          // the satellite "ball"; may be below the horizon
    var skyView = true                // true: east on the left (looking up at the sky)
    var rotation: Double = 0          // phone heading in degrees; 0 = north up
    var accent: Color = .green
    var grid: Color = .gray.opacity(0.5)

    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let R = min(size.width, size.height) / 2 - 24

            func point(az: Double, radius: CGFloat) -> CGPoint {
                let a = (az - rotation) * .pi / 180
                let dx = (skyView ? -1.0 : 1.0) * sin(a)
                return CGPoint(x: c.x + radius * CGFloat(dx), y: c.y - radius * CGFloat(cos(a)))
            }
            func pt(_ p: PolarPoint) -> CGPoint {
                point(az: p.azimuth, radius: R * CGFloat((90 - max(0, p.elevation)) / 90))
            }
            func circle(_ p: CGPoint, _ r: CGFloat) -> Path {
                Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r))
            }

            // Elevation rings: 0°, 30°, 60°
            for el in stride(from: 0.0, through: 60.0, by: 30.0) {
                let r = R * CGFloat((90 - el) / 90)
                ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)),
                           with: .color(grid), lineWidth: 1)
                if el > 0 {
                    ctx.draw(Text("\(Int(el))°").font(.system(size: 9)).foregroundStyle(grid),
                             at: CGPoint(x: c.x + 12, y: c.y - r - 6))
                }
            }
            // Azimuth spokes every 45°
            for az in stride(from: 0.0, to: 360.0, by: 45.0) {
                var p = Path()
                p.move(to: c)
                p.addLine(to: point(az: az, radius: R))
                ctx.stroke(p, with: .color(grid.opacity(0.5)), lineWidth: 0.5)
            }
            // Cardinal labels, just outside the horizon ring
            for (label, az) in [("N", 0.0), ("E", 90.0), ("S", 180.0), ("W", 270.0)] {
                ctx.draw(Text(label).font(.caption.bold()).foregroundStyle(accent),
                         at: point(az: az, radius: R + 14))
            }
            // Pass trajectory with AOS (filled) and LOS (ring) markers
            if track.count > 1 {
                var path = Path()
                path.move(to: pt(track[0]))
                track.dropFirst().forEach { path.addLine(to: pt($0)) }
                ctx.stroke(path, with: .color(accent),
                           style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                ctx.fill(circle(pt(track[0]), 4), with: .color(accent))
                ctx.stroke(circle(pt(track[track.count - 1]), 4), with: .color(accent), lineWidth: 1.5)
            }
            // The satellite ball
            if let cur = current {
                let p = pt(cur)             // below the horizon it sits on the rim, at its true azimuth
                if cur.elevation > 0 {
                    ctx.fill(circle(p, 14), with: .color(accent.opacity(0.25)))
                    ctx.fill(circle(p, 7), with: .color(.white))
                    ctx.stroke(circle(p, 7), with: .color(accent), lineWidth: 2)
                } else {
                    ctx.stroke(circle(p, 6), with: .color(accent.opacity(0.85)),
                               style: StrokeStyle(lineWidth: 2, dash: [3, 3]))
                    ctx.fill(circle(p, 2.5), with: .color(accent.opacity(0.85)))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
