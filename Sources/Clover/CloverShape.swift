import CoreGraphics
import Foundation

/// The geometric four-leaf clover of the app icon, drawn for the menu bar. Each leaf is two
/// equal circles closed by the tangents from its tip; leaves sit on the diagonals with even gaps,
/// and the stem curves away below them. Gaps and stem are wider than the icon's, to stay legible
/// at menu bar size.
enum CloverShape {
    /// The leaves and the stem, fitted into `rect` (y up). Fill them one by one.
    static func parts(in rect: CGRect) -> [CGPath] {
        let gap: CGFloat = 0.1
        var parts: [CGPath] = [45.0, 135, 225, 315].map { degrees in
            let a = degrees * .pi / 180
            return leaf.copy(using: [CGAffineTransform(translationX: cos(a) * gap, y: sin(a) * gap).rotated(by: a - .pi / 2)])!
        }
        let stem = CGMutablePath()
        stem.move(to: CGPoint(x: 0, y: -0.82))
        stem.addCurve(to: CGPoint(x: 0.3, y: -1.14), control1: CGPoint(x: 0, y: -0.96), control2: CGPoint(x: 0.12, y: -1.08))
        parts.append(stem.copy(strokingWithWidth: 0.12, lineCap: .round, lineJoin: .round, miterLimit: 1))

        let box = parts.map(\.boundingBoxOfPath).reduce(CGRect.null) { $0.union($1) }
        let s = min(rect.width / box.width, rect.height / box.height)
        let fit = CGAffineTransform(translationX: rect.midX - box.midX * s, y: rect.midY - box.midY * s).scaledBy(x: s, y: s)
        return parts.map { $0.copy(using: [fit])! }
    }

    /// A leaf along +y with its tip at the origin: circles of radius r at (±a, h), closed by
    /// their outer tangents.
    private static var leaf: CGPath {
        let r: CGFloat = 0.33, a: CGFloat = 0.12, h: CGFloat = 0.6
        let len = hypot(a, h), beta = asin(r / len), t = sqrt(len * len - r * r)
        let left = CGPoint(x: -a, y: h), right = CGPoint(x: a, y: h)
        let tangentLeft = CGPoint(x: cos(atan2(h, -a) + beta) * t, y: sin(atan2(h, -a) + beta) * t)
        let tangentRight = CGPoint(x: cos(atan2(h, a) - beta) * t, y: sin(atan2(h, a) - beta) * t)
        let notch = CGPoint(x: 0, y: h + sqrt(r * r - a * a))
        func angle(_ p: CGPoint, around o: CGPoint) -> CGFloat { atan2(p.y - o.y, p.x - o.x) }

        let p = CGMutablePath()
        p.move(to: .zero)
        p.addLine(to: tangentLeft)
        p.addArc(center: left, radius: r, startAngle: angle(tangentLeft, around: left), endAngle: angle(notch, around: left), clockwise: true)
        p.addArc(center: right, radius: r, startAngle: angle(notch, around: right), endAngle: angle(tangentRight, around: right), clockwise: true)
        p.closeSubpath()
        return p
    }
}
