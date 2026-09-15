import AppKit

enum MenuBarIcon {
    enum State: Sendable { case idle, running, paused }

    /// A template image for the menu bar, sized in points (default 18×18).
    @MainActor static func image(_ state: State, pointSize: CGFloat = 18) -> NSImage {
        precondition(pointSize.isFinite && pointSize > 0)
        let image = NSImage(size: NSSize(width: pointSize, height: pointSize), flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.saveGState()
            defer { context.restoreGState() }
            context.translateBy(x: rect.minX, y: rect.minY)
            context.scaleBy(x: rect.width / 18, y: rect.height / 18)
            context.setFillColor(CGColor(gray: 0, alpha: 1))
            context.setStrokeColor(CGColor(gray: 0, alpha: 1))
            context.setLineCap(.round)
            context.setLineJoin(.round)

            // Isolate the knockout so drawing directly over a menu background is safe.
            context.beginTransparencyLayer(auxiliaryInfo: nil)
            defer { context.endTransparencyLayer() }

            // Coordinates are in an unflipped 18-point canvas. The body sits low
            // to balance the crown, with at least one point of exterior padding.
            context.addPath(CGPath(roundedRect: CGRect(x: 7, y: 14.1, width: 4, height: 2.9),
                                   cornerWidth: 0.7, cornerHeight: 0.7, transform: nil))
            context.fillPath()
            context.setLineWidth(2.4)
            context.move(to: CGPoint(x: 13.6, y: 13.6))
            context.addLine(to: CGPoint(x: 14.9, y: 14.9))
            context.strokePath()

            let center = CGPoint(x: 9, y: 7.9)
            context.setLineWidth(2.2)
            switch state {
            case .idle:
                // A bottom gap remains visibly open even after the rounded caps.
                context.addArc(center: center, radius: 5.7,
                               startAngle: -.pi / 2 + .pi / 8,
                               endAngle: 3 * .pi / 2 - .pi / 8, clockwise: false)
                context.strokePath()
                context.move(to: center)
                context.addLine(to: CGPoint(x: 9, y: 11.5))
                context.strokePath()
            case .running:
                context.fillEllipse(in: CGRect(x: 2.2, y: 1.1, width: 13.6, height: 13.6))
                context.setBlendMode(.clear)
                context.move(to: center)
                // Long enough to read as a hand pointing at 2 o'clock, not a floating slit.
                context.addLine(to: CGPoint(x: 12.95, y: 10.2))
                context.strokePath()
            case .paused:
                context.strokeEllipse(in: CGRect(x: 3.3, y: 2.2, width: 11.4, height: 11.4))
                for x: CGFloat in [6.1, 9.9] {
                    context.addPath(CGPath(roundedRect: CGRect(x: x, y: 5, width: 2, height: 5.8),
                                           cornerWidth: 0.45, cornerHeight: 0.45, transform: nil))
                    context.fillPath()
                }
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
