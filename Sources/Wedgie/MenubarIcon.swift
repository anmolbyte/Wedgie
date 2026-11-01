import AppKit

enum MenubarIcon {
    /// Renders a side-view MacBook silhouette with the lid at a given angle.
    /// `lidProgress`: 0 = lid fully closed (flush on base), 1 = lid fully open.
    static func image(lidProgress: Double) -> NSImage? {
        let progress = max(0, min(1, lidProgress))
        let size = NSSize(width: 22, height: 16)
        let image = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.setFillColor(NSColor.black.cgColor)
            drawLaptop(in: ctx, rect: rect, lidProgress: CGFloat(progress))
            return true
        }
        image.isTemplate = true
        return image
    }

    /// Convenience for the binary state.
    static func image(isOn: Bool) -> NSImage? {
        image(lidProgress: isOn ? 1.0 : 0.0)
    }

    private static func drawLaptop(in ctx: CGContext, rect: NSRect, lidProgress: CGFloat) {
        let baseWidth = rect.width * 0.78
        let baseHeight: CGFloat = 2.4
        let originX = rect.midX - baseWidth / 2
        let baseY = rect.minY + 2.5

        // Base slab
        let baseRect = CGRect(x: originX, y: baseY, width: baseWidth, height: baseHeight)
        ctx.addPath(NSBezierPath(roundedRect: baseRect, xRadius: 0.9, yRadius: 0.9).cgPath)
        ctx.fillPath()

        // Lid: hinged on the right end of the base top edge. Drawn pointing
        // LEFT initially (closed = flush on top of base). Rotates UP as
        // lidProgress increases.
        let lidLength = baseWidth - 1.0
        let lidThickness: CGFloat = 2.0
        let hingeX = originX + baseWidth - 0.4
        let hingeY = baseY + baseHeight

        // Negative angle rotates the lid visually upward (CCW from screen
        // viewer when the Y axis points up, which it does here).
        let maxOpenDeg: CGFloat = 40
        let angleRad = -maxOpenDeg * .pi / 180 * lidProgress

        ctx.saveGState()
        ctx.translateBy(x: hingeX, y: hingeY)
        ctx.rotate(by: angleRad)

        // Lid rectangle extends LEFT from the hinge along the rotated frame.
        let lidRect = CGRect(
            x: -lidLength,
            y: 0,                  // sits flush on top of base when closed
            width: lidLength,
            height: lidThickness
        )
        ctx.addPath(NSBezierPath(roundedRect: lidRect, xRadius: 0.7, yRadius: 0.7).cgPath)
        ctx.fillPath()

        ctx.restoreGState()
    }
}

private extension NSBezierPath {
    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [CGPoint](repeating: .zero, count: 3)
        for i in 0..<elementCount {
            let type = element(at: i, associatedPoints: &points)
            switch type {
            case .moveTo:        path.move(to: points[0])
            case .lineTo:        path.addLine(to: points[0])
            case .curveTo, .cubicCurveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .quadraticCurveTo:
                path.addQuadCurve(to: points[1], control: points[0])
            case .closePath:     path.closeSubpath()
            @unknown default:    break
            }
        }
        return path
    }
}
