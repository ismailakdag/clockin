import AppKit
import SwiftUI

/// A live figure (timer, earnings) whose changed characters roll into place.
///
/// SwiftUI's `numericText` transition re-renders the view for every frame and
/// cost 40-50% CPU per second tick here, so the roll is a Core Animation
/// animation on per-character text layers that the render server plays alone.
/// Reduce Motion swaps the characters instantly.
struct RollingText: View {
    let text: String
    /// Rising values roll upwards, falling ones downwards.
    let value: Double
    let size: CGFloat
    var weight: Font.Weight = .regular
    var design: Font.Design = .default
    var color: Color = .primary
    var tracking: CGFloat = 0

    init(_ text: String, value: Double, size: CGFloat, weight: Font.Weight = .regular,
         design: Font.Design = .default, color: Color = .primary, tracking: CGFloat = 0) {
        self.text = text
        self.value = value
        self.size = size
        self.weight = weight
        self.design = design
        self.color = color
        self.tracking = tracking
    }

    var body: some View {
        let font = Self.font(size: size, weight: weight, design: design)
        RollingTextView(text: text, value: value, font: font, color: color, tracking: tracking)
            .alignmentGuide(.firstTextBaseline) { _ in ceil(font.ascender) }
            .alignmentGuide(.lastTextBaseline) { _ in ceil(font.ascender) }
            .accessibilityElement()
            .accessibilityLabel(text)
    }

    static func font(size: CGFloat, weight: Font.Weight, design: Font.Design) -> NSFont {
        let nsWeight: NSFont.Weight = switch weight {
        case .ultraLight: .ultraLight
        case .thin: .thin
        case .light: .light
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        default: .regular
        }
        let systemDesign: NSFontDescriptor.SystemDesign = switch design {
        case .rounded: .rounded
        case .monospaced: .monospaced
        case .serif: .serif
        default: .default
        }
        var descriptor = NSFont.systemFont(ofSize: size, weight: nsWeight).fontDescriptor
        descriptor = descriptor.withDesign(systemDesign) ?? descriptor
        // Tabular digits, so a changing digit never shifts its neighbours.
        descriptor = descriptor.addingAttributes([.featureSettings: [[
            NSFontDescriptor.FeatureKey.typeIdentifier: kNumberSpacingType,
            NSFontDescriptor.FeatureKey.selectorIdentifier: kMonospacedNumbersSelector,
        ]]])
        return NSFont(descriptor: descriptor, size: size) ?? .monospacedDigitSystemFont(ofSize: size, weight: nsWeight)
    }
}

private struct RollingTextView: NSViewRepresentable {
    let text: String
    let value: Double
    let font: NSFont
    let color: Color
    let tracking: CGFloat

    func makeNSView(context: Context) -> RollingTextLayerView { RollingTextLayerView() }

    func updateNSView(_ view: RollingTextLayerView, context: Context) {
        view.update(text: text, value: value, font: font, tracking: tracking,
                    color: color.resolve(in: context.environment).cgColor,
                    animated: !context.environment.accessibilityReduceMotion)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: RollingTextLayerView, context: Context) -> CGSize? {
        RollingTextLayerView.size(of: text, font: font, tracking: tracking)
    }
}

final class RollingTextLayerView: NSView {
    private var glyphs: [CATextLayer] = []
    private var characters: [Character] = []
    private var font = NSFont.systemFont(ofSize: 13)
    private var tracking: CGFloat = 0
    private var color = CGColor(gray: 0, alpha: 1)
    private var value = 0.0

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var isFlipped: Bool { true }

    static func lineHeight(_ font: NSFont) -> CGFloat {
        ceil(font.ascender - font.descender)
    }

    /// Each character's x offset and the total width, from the laid-out line,
    /// so kerning and spacing match a plain SwiftUI Text.
    static func layout(of text: String, font: NSFont, tracking: CGFloat) -> (offsets: [CGFloat], width: CGFloat) {
        let attributed = NSAttributedString(string: text, attributes: [.font: font, .kern: tracking])
        let line = CTLineCreateWithAttributedString(attributed)
        var offsets: [CGFloat] = []
        var index = text.startIndex
        while index < text.endIndex {
            let utf16 = text.utf16.distance(from: text.utf16.startIndex, to: index)
            offsets.append(CTLineGetOffsetForStringIndex(line, utf16, nil))
            index = text.index(after: index)
        }
        let width = CTLineGetTypographicBounds(line, nil, nil, nil) - (text.isEmpty ? 0 : tracking)
        return (offsets, ceil(max(0, width)))
    }

    static func size(of text: String, font: NSFont, tracking: CGFloat) -> CGSize {
        CGSize(width: layout(of: text, font: font, tracking: tracking).width, height: lineHeight(font))
    }

    func update(text: String, value: Double, font: NSFont, tracking: CGFloat, color: CGColor, animated: Bool) {
        let styleChanged = font != self.font || tracking != self.tracking || color != self.color
        let newCharacters = Array(text)
        guard styleChanged || newCharacters != characters else { return }
        let rising = value >= self.value
        self.font = font
        self.tracking = tracking
        self.color = color
        self.value = value

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        // Only an in-place change of the same shape rolls; anything else (a new
        // style, an extra digit) is laid out afresh.
        guard animated, !styleChanged, window != nil, newCharacters.count == characters.count else {
            glyphs.forEach { $0.removeFromSuperlayer() }
            glyphs = []
            characters = newCharacters
            for (index, x) in positions(for: newCharacters).enumerated() {
                let glyph = makeGlyph(newCharacters[index], x: x)
                layer?.addSublayer(glyph)
                glyphs.append(glyph)
            }
            return
        }

        let height = Self.lineHeight(font)
        let offset = rising ? height : -height
        let positions = positions(for: newCharacters)
        for index in newCharacters.indices where newCharacters[index] != characters[index] {
            let old = glyphs[index]
            let new = makeGlyph(newCharacters[index], x: positions[index])
            layer?.insertSublayer(new, above: old)
            glyphs[index] = new
            roll(new, from: CGPoint(x: new.position.x, y: new.position.y + offset), to: new.position, fadeIn: true)
            let exit = CGPoint(x: old.position.x, y: old.position.y - offset)
            roll(old, from: old.position, to: exit, fadeIn: false)
            old.position = exit
            old.opacity = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.duration + 0.05) { old.removeFromSuperlayer() }
        }
        characters = newCharacters
    }

    private static let duration: CFTimeInterval = 0.32

    private func roll(_ glyph: CATextLayer, from: CGPoint, to: CGPoint, fadeIn: Bool) {
        let move = CABasicAnimation(keyPath: "position")
        move.fromValue = NSValue(point: from)
        move.toValue = NSValue(point: to)
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = fadeIn ? 0 : 1
        fade.toValue = fadeIn ? 1 : 0
        let group = CAAnimationGroup()
        group.animations = [move, fade]
        group.duration = Self.duration
        group.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1)
        glyph.add(group, forKey: "roll")
    }

    private func positions(for characters: [Character]) -> [CGFloat] {
        Self.layout(of: String(characters), font: font, tracking: tracking).offsets
    }

    private func makeGlyph(_ character: Character, x: CGFloat) -> CATextLayer {
        let glyph = CATextLayer()
        glyph.string = NSAttributedString(string: String(character), attributes: [
            .font: font, .foregroundColor: NSColor(cgColor: color) ?? .labelColor,
        ])
        glyph.contentsScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        let width = ceil((String(character) as NSString).size(withAttributes: [.font: font]).width) + 2
        glyph.frame = CGRect(x: x, y: 0, width: width, height: Self.lineHeight(font))
        glyph.actions = ["position": NSNull(), "opacity": NSNull(), "contents": NSNull(), "bounds": NSNull()]
        return glyph
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        let scale = window?.backingScaleFactor ?? 2
        glyphs.forEach { $0.contentsScale = scale }
    }
}
