import ImageIO
import SwiftUI

enum MascotResources {
    static func url(_ name: String, extension ext: String = "png", bundle: Bundle = .main) -> URL? {
        for folder in [nil, "Frames", "Mascot/Frames"] as [String?] {
            if let url = bundle.url(forResource: name, withExtension: ext, subdirectory: folder) { return url }
        }
        return nil
    }

    static func frameURL(_ id: String, bundle: Bundle = .main) -> URL? {
        MascotFrameFallback.resolve(id) { url($0, bundle: bundle) != nil }
            .flatMap { url($0, bundle: bundle) }
    }

    static func decode(_ id: String, maxPixelSize: Int = 314) -> CGImage? {
        guard let url = frameURL(id),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true
        ] as CFDictionary)
    }

    static let library: MascotLibrary? = url("mascot-clips", extension: "json")
        .flatMap { try? Data(contentsOf: $0) }
        .flatMap { try? MascotLibrary(data: $0) }
}

// Widget sadece tek kucuk kareyi tutar; hareket onbellegini kullanmaz.
struct ClockinMascotStill: View {
    private let image: CGImage?

    init(mood: MascotMood, accessory: CompanionAccessory? = nil, maxPixelSize: Int = 192,
         outfit: WardrobeState = WardrobeState()) {
        let rest = MascotResources.library?[mood].rest ?? "h01"
        image = WardrobeArt.composite(frame: rest, outfit: outfit, size: maxPixelSize)
    }

    var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: 1).resizable().interpolation(.none).scaledToFit()
            } else {
                Image(systemName: "face.smiling").resizable().scaledToFit()
            }
        }
        .accessibilityHidden(true)
    }
}

#if !WIDGET_EXTENSION
@MainActor
final class MascotFrames {
    static let shared = MascotFrames()
    let library = MascotResources.library
    private var images: [String: CGImage] = [:]
    private var loading: [String: Task<Void, Never>] = [:]
    private(set) var overlayImages: [String: CGImage] = [:]

    func image(_ id: String, colorway: String = "classic") -> CGImage? { images[colorway + "/" + id] }

    func preload(_ mood: MascotMood, colorway: String = "classic") async {
        guard let library else { return }
        let key = colorway + "/" + mood.rawValue
        if let task = loading[key] { return await task.value }
        let missing = library[mood].frames.filter { images[colorway + "/" + $0] == nil }
        let missingSprites = WardrobeArt.sprites.keys.filter { overlayImages[$0] == nil }
        // Paylasilan decode isi gorunum kapaninca sonucunu onbellege birakir.
        let task = Task {
            let decoded = await Task.detached(priority: .utility) {
                let frames = missing.compactMap { id in
                    MascotResources.decode(id).map { (id, WardrobeArt.recolor($0, colorway: colorway)) }
                }
                let sprites = missingSprites.compactMap { id in
                    WardrobeArt.decode(id + ".png", folder: "Wardrobe").map { (id, $0) }
                }
                return (frames, sprites)
            }.value
            for (id, image) in decoded.0 { images[colorway + "/" + id] = image }
            for (id, image) in decoded.1 { overlayImages[id] = image }
        }
        loading[key] = task
        await task.value
    }
}
#endif
