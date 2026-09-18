import Foundation
import CoreGraphics
import ImageIO
#if canImport(UIKit)
import UIKit
#endif

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
        guard colorway != "classic", let rules = colorways[colorway] else { return image }
        return recolor(image, colorway: rules)
    }

    static func recolor(_ image: CGImage, colorway: WardrobeColorway) -> CGImage {
        guard !colorway.identity, !colorway.rules.isEmpty else { return image }
        let width = image.width, height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let info = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        let straight = image.bitsPerComponent == 8 && image.bitsPerPixel == 32 && image.alphaInfo == .last
            && image.bitmapInfo.intersection(.byteOrderMask).isEmpty
        if straight, let data = image.dataProvider?.data {
            let raw = data as Data
            for y in 0..<height {
                bytes.replaceSubrange((y * width * 4)..<((y + 1) * width * 4),
                    with: raw[(y * image.bytesPerRow)..<(y * image.bytesPerRow + width * 4)])
            }
        } else {
            bytes.withUnsafeMutableBytes { buffer in
                guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                              bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: info) else { return }
                context.interpolationQuality = .none
                context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            }
            // Sinir piksellerini duz RGBA ile isle.
            for i in stride(from: 0, to: bytes.count, by: 4) where bytes[i + 3] > 0 && bytes[i + 3] < 255 {
                for c in 0..<3 { bytes[i + c] = UInt8(min(255, (Int(bytes[i + c]) * 255 + Int(bytes[i + 3]) / 2) / Int(bytes[i + 3]))) }
            }
        }
        WardrobePalette.recolor(&bytes, colorway: colorway)
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return image }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                       space: straight ? (image.colorSpace ?? CGColorSpaceCreateDeviceRGB()) : CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) ?? image
    }

    static func overlays(frame: String, outfit: WardrobeState, images: [String: CGImage],
                         anchorManifest: [String: WardrobeAnchors] = anchors,
                         spriteManifest: [String: WardrobeSprite] = sprites) -> [WardrobeOverlay] {
        guard let anchors = anchorManifest[frame] else { return [] }
        return WardrobeSlot.outfit.compactMap { slot in
            guard let id = outfit.equipped[slot.rawValue], let sprite = spriteManifest[id], sprite.slot == slot.rawValue,
                  ["front", "back"].contains(sprite.layer), let image = images[id],
                  let origin = WardrobeGeometry.placement(sprite: sprite, frame: anchors) else { return nil }
            return WardrobeOverlay(id: id, image: image, origin: origin, tilt: WardrobeGeometry.tilt(sprite: sprite, frame: anchors), behind: sprite.layer == "back")
        }
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

// Actor icinde await yok; eszamanli istekler ayni kareyi tekrar boyamaz.
actor WardrobeFrameCache {
    static let shared = WardrobeFrameCache()
    private var frames: [String: CGImage] = [:]
    private var stills: [String: CGImage] = [:]
    private let decode: @Sendable (String, Bool) -> CGImage?

    init(decode: @escaping @Sendable (String, Bool) -> CGImage? = { id, fixedPose in
        if fixedPose {
            #if canImport(UIKit)
            return UIImage(named: id)?.cgImage
            #else
            return nil
            #endif
        }
        return MascotResources.decode(id)
    }) { self.decode = decode }

    func composite(frame: String, outfit: WardrobeState, size: Int) -> CGImage? {
        let key = "\(size)/\(frame)/\(outfit.colorway)/" + outfit.equipped.sorted { $0.key < $1.key }.map { $0.key + "=" + $0.value }.joined(separator: ";")
        if let image = stills[key] { return image }
        guard let robot = image(frame, colorway: outfit.colorway) else { return nil }
        let images = outfit.equipped.values.reduce(into: [String: CGImage]()) { result, id in
            result[id] = WardrobeArt.decode(id + ".png", folder: "Wardrobe")
        }
        let parts = WardrobeArt.overlays(frame: frame, outfit: outfit, images: images)
        let result = WardrobeArt.composite(robot: robot, parts: parts, size: size)
        if stills.count >= 32 { stills.removeAll() }
        stills[key] = result
        return result
    }

    func image(_ id: String, colorway: String, fixedPose: Bool = false) -> CGImage? {
        let key = (fixedPose ? "pose/" : "frame/") + colorway + "/" + id
        if let image = frames[key] { return image }
        guard let source = decode(id, fixedPose) else { return nil }
        let image = WardrobeArt.recolor(source, colorway: colorway)
        frames[key] = image
        return image
    }
}
