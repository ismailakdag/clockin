import AppKit

// Run from the package root; this standalone harness needs no app or display server.
@MainActor func bitmap(width: Int, height: Int, scale: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width * scale,
                               pixelsHigh: height * scale, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: width, height: height)
    return rep
}

@MainActor func draw(into rep: NSBitmapImageRep, _ body: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    let graphics = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = graphics
    // AppKit derives the backing scale from pixelsWide / size.width already.
    graphics.cgContext.clear(CGRect(origin: .zero, size: rep.size))
    body()
    graphics.flushGraphics()
}

@MainActor func alphaBytes(_ rep: NSBitmapImageRep) -> [UInt8] {
    // Reading through the rep avoids assuming a byte order or premultiplication format.
    var result: [UInt8] = []
    for y in 0..<rep.pixelsHigh {
        for x in 0..<rep.pixelsWide {
            result.append(UInt8((rep.colorAt(x: x, y: y)!.alphaComponent * 255).rounded()))
        }
    }
    return result
}

@MainActor func run() throws {
    var checks = 0
    func check(_ condition: Bool, _ message: String) {
        guard condition else { fatalError(message) }
        checks += 1
    }
    let states: [MenuBarIcon.State] = [.idle, .running, .paused]
    for scale in 1...3 {
        var masks: [[UInt8]] = []
        for state in states {
            let icon = MenuBarIcon.image(state)
            check(icon.isTemplate, "\(state): not a template at \(scale)x")
            let rep = bitmap(width: 18, height: 18, scale: scale)
            draw(into: rep) {
                icon.draw(in: CGRect(x: 0, y: 0, width: 18, height: 18),
                          from: .zero, operation: .sourceOver, fraction: 1)
            }
            let mask = alphaBytes(rep)
            let side = 18 * scale
            var edge: [UInt8] = []
            for i in 0..<side {
                edge.append(mask[i])
                edge.append(mask[(side - 1) * side + i])
                edge.append(mask[i * side])
                edge.append(mask[i * side + side - 1])
            }
            check(edge.allSatisfy { $0 == 0 }, "\(state): clipped edge at \(scale)x")
            check(mask.contains(255), "\(state): no solid artwork at \(scale)x")
            masks.append(mask)
        }
        let coverage = masks.map { $0.reduce(0) { $0 + Int($1) } }
        check(Double(coverage[1]) > Double(coverage[0]) * 1.35,
              "Running must have at least 35% more alpha coverage at \(scale)x: \(coverage)")
        for (a, b) in [(0, 1), (0, 2), (1, 2)] {
            check(masks[a] != masks[b], "States \(a) and \(b) match at \(scale)x")
        }
    }

    // Three columns, light and dark rows, all rendered at exactly 2x.
    let sheet = bitmap(width: 450, height: 144, scale: 2)
    draw(into: sheet) {
        for dark in [false, true] {
            let y: CGFloat = dark ? 0 : 72
            let background: CGFloat = dark ? 30.0 / 255 : 236.0 / 255
            NSColor(deviceRed: background, green: background, blue: background, alpha: 1).setFill()
            NSBezierPath(rect: CGRect(x: 0, y: y, width: 450, height: 72)).fill()
            for (column, state) in states.enumerated() {
                let x = CGFloat(column * 150 + 20)
                // Tint with sourceIn in a separate image to preserve transparent holes.
                let tinted = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
                    MenuBarIcon.image(state).draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
                    (dark ? NSColor.white : NSColor.black).setFill()
                    rect.fill(using: .sourceIn)
                    return true
                }
                tinted.draw(in: CGRect(x: x, y: y + 22, width: 18, height: 18),
                            from: .zero, operation: .sourceOver, fraction: 1)
                if column != 0 {
                    let color: NSColor = column == 2
                        ? NSColor(calibratedWhite: dark ? 0.65 : 0.42, alpha: 1)
                        : (dark ? .white : .black)
                    ("01:07" as NSString).draw(at: CGPoint(x: x + 24, y: y + 22), withAttributes: [
                        .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold),
                        .foregroundColor: color
                    ])
                }
                (["IDLE", "RUNNING", "PAUSED"][column] as NSString).draw(
                    at: CGPoint(x: x, y: y + 49), withAttributes: [
                        .font: NSFont.systemFont(ofSize: 9, weight: .medium),
                        .foregroundColor: NSColor(calibratedWhite: dark ? 0.65 : 0.42, alpha: 1)
                    ])
            }
        }
    }
    let output = URL(fileURLWithPath: "Tests/manual/menubaricon/preview.png")
    try sheet.representation(using: .png, properties: [:])!.write(to: output)
    print("\(checks) menu bar icon checks passed")
}

try run()
