import CoreGraphics
import Foundation

/// The four-leaf clover of the menu bar glyph (the app icon, Resources/Clover.icns, shows the
/// same shape). Geometry is in a unit square with y up; `rect` places it.
enum CloverShape {
    /// Four heart-shaped leaves on the diagonals, tips meeting just above the middle.
    static func leaves(in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        // A wide gap keeps the leaves apart at menu bar size.
        let center = CGPoint(x: 0.5, y: 0.56), length = 0.36, gap = 0.06
        for degrees in [45.0, 135, 225, 315] {
            let a = degrees * .pi / 180
            let place = CGAffineTransform(translationX: center.x + cos(a) * gap, y: center.y + sin(a) * gap)
                .rotated(by: a - .pi / 2)
                .scaledBy(x: length, y: length)
            path.addPath(heart, transform: place)
        }
        return path.copy(using: [unit(to: rect)])!
    }

    /// A stem curving down and to the right from the middle.
    static func stem(in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0.5, y: 0.52))
        path.addCurve(to: CGPoint(x: 0.66, y: 0.08), control1: CGPoint(x: 0.53, y: 0.34), control2: CGPoint(x: 0.58, y: 0.18))
        return path.copy(using: [unit(to: rect)])!
    }

    /// The stem's width relative to the square's side.
    static let stemWidth = 0.05

    /// A heart with its tip at the origin, its lobes reaching y = 1.
    private static var heart: CGPath {
        let p = CGMutablePath()
        p.move(to: .zero)
        p.addCurve(to: CGPoint(x: -0.5, y: 0.62), control1: CGPoint(x: -0.14, y: 0.16), control2: CGPoint(x: -0.5, y: 0.36))
        p.addCurve(to: CGPoint(x: 0, y: 0.8), control1: CGPoint(x: -0.5, y: 0.96), control2: CGPoint(x: -0.1, y: 1.02))
        p.addCurve(to: CGPoint(x: 0.5, y: 0.62), control1: CGPoint(x: 0.1, y: 1.02), control2: CGPoint(x: 0.5, y: 0.96))
        p.addCurve(to: .zero, control1: CGPoint(x: 0.5, y: 0.36), control2: CGPoint(x: 0.14, y: 0.16))
        p.closeSubpath()
        return p
    }

    private static func unit(to rect: CGRect) -> CGAffineTransform {
        CGAffineTransform(translationX: rect.minX, y: rect.minY).scaledBy(x: rect.width, y: rect.height)
    }
}
