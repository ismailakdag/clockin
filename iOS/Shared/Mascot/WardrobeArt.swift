import Foundation
import CoreGraphics
import ImageIO

struct WardrobeOverlay {
    let id: String
    let image: CGImage
    let origin: WardrobePoint
    let tilt: Double
    let behind: Bool
}

enum WardrobeArt {
    static func url(_ file: String, folder: String, bundle: Bundle = .main) -> URL? {
        guard !file.contains("/"), !file.contains("..") else { return nil }
        let name = (file as NSString).deletingPathExtension
        let ext = (file as NSString).pathExtension
        for directory in [nil, folder, "Mascot/\(folder)"] as [String?] {
            if let url = bundle.url(forResource: name, withExtension: ext, subdirectory: directory) { return url }
        }
        return nil
    }
    static func read<T: Decodable>(_ type: T.Type, _ file: String, folder: String) -> T? {
        url(file, folder: folder).flatMap { try? Data(contentsOf: $0) }.flatMap { try? JSONDecoder().decode(type, from: $0) }
    }
    static let anchors = read([String: WardrobeAnchors].self, "mascot-anchors.json", folder: "Frames") ?? [:]
    static let sprites = read([String: WardrobeSprite].self, "wardrobe-sprites.json", folder: "Wardrobe") ?? [:]
    static let colorways = read([String: WardrobeColorway].self, "colorways.json", folder: "Frames") ?? [:]
    static let home = read(WardrobeHome.self, "home-items.json", folder: "Home") ?? WardrobeHome()

    static func available(_ item: WardrobeItem) -> Bool {
        switch item.slot {
        case .colorway: return item.id == "classic" || colorways[item.id] != nil
        case .room: return home.rooms[item.id].flatMap { url($0.file, folder: "Home") } != nil
        default:
            if WardrobeSlot.furniture.contains(item.slot) {
                guard let entry = home.items[item.id], entry.slot == item.slot.rawValue else { return false }
                return url(entry.file, folder: "Home") != nil
            }
            guard let entry = sprites[item.id], entry.slot == item.slot.rawValue,
                  ["front", "back"].contains(entry.layer) else { return false }
            return url(item.id + ".png", folder: "Wardrobe") != nil && !anchors.isEmpty
        }
    }

    static func decode(_ file: String, folder: String) -> CGImage? {
        guard let url = url(file, folder: folder), let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
    }

    static func recolor(_ image: CGImage, colorway: String) -> CGImage {
        recolor(image, map: colorways[colorway]?.map ?? [:])
    }

    static func recolor(_ image: CGImage, map: [String: String]) -> CGImage {
        guard !map.isEmpty else { return image }
        let width = image.width, height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let info = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        bytes.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: info) else { return }
            context.interpolationQuality = .none
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        WardrobePalette.recolor(&bytes, map: map)
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return image }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                       space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: info),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) ?? image
    }

    static func overlays(frame: String, outfit: WardrobeState, images: [String: CGImage]) -> [WardrobeOverlay] {
        guard let anchors = anchors[frame] else { return [] }
        return WardrobeSlot.outfit.compactMap { slot in
            guard let id = outfit.equipped[slot.rawValue], let sprite = sprites[id], sprite.slot == slot.rawValue,
                  ["front", "back"].contains(sprite.layer), let image = images[id],
                  let origin = WardrobeGeometry.placement(sprite: sprite, frame: anchors) else { return nil }
            return WardrobeOverlay(id: id, image: image, origin: origin, tilt: anchors.tilt, behind: sprite.layer == "back")
        }
    }

    static func composite(frame: String, outfit: WardrobeState, size: Int) -> CGImage? {
        guard let base = MascotResources.decode(frame) else { return nil }
        let robot = recolor(base, colorway: outfit.colorway)
        let images = outfit.equipped.values.reduce(into: [String: CGImage]()) { result, id in
            result[id] = decode(id + ".png", folder: "Wardrobe")
        }
        let parts = overlays(frame: frame, outfit: outfit, images: images)
        return composite(robot: robot, parts: parts, size: size)
    }

    static func composite(robot: CGImage, parts: [WardrobeOverlay], size: Int) -> CGImage? {
        guard size > 0, size <= 2048 else { return nil }
        guard let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .none
        context.translateBy(x: 0, y: CGFloat(size))
        context.scaleBy(x: CGFloat(size) / 314, y: -CGFloat(size) / 314)
        func draw(_ image: CGImage, _ rect: CGRect) {
            context.saveGState()
            context.translateBy(x: rect.minX, y: rect.maxY)
            context.scaleBy(x: 1, y: -1)
            context.draw(image, in: CGRect(origin: .zero, size: rect.size))
            context.restoreGState()
        }
        func overlay(_ part: WardrobeOverlay) {
            context.saveGState()
            context.translateBy(x: part.origin.x, y: part.origin.y)
            context.rotate(by: part.tilt * .pi / 180)
            draw(part.image, CGRect(x: 0, y: 0, width: part.image.width, height: part.image.height))
            context.restoreGState()
        }
        parts.filter(\.behind).forEach(overlay)
        draw(robot, CGRect(x: 0, y: 0, width: 314, height: 314))
        parts.filter { !$0.behind }.forEach(overlay)
        return context.makeImage()
    }
}
