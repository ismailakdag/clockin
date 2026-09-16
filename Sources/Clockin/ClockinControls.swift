import AppKit
import SwiftUI

// Clockin's controls. Every clickable thing looks clickable: buttons have a
// surface or a fill, the pointer turns into a hand over them, they brighten on
// hover and give a little on press. Menus and fields use the same field chrome
// so pickers no longer look like small system pop-ups.
//
// Everything is sized through `S(_:)` and reads the selected theme itself, so a
// screen only picks the kind of control it needs.

// MARK: Tokens

enum ClockinFont {
    /// Screen titles.
    static var title: Font { .system(size: S(17), weight: .bold) }
    /// Section titles above grouped rows.
    static var section: Font { .system(size: S(11.5), weight: .semibold) }
    /// Row titles and control labels.
    static var body: Font { .system(size: S(12.5), weight: .medium) }
    /// Secondary lines under a row title.
    static var caption: Font { .system(size: S(10.5)) }
}

extension ClockinPalette {
    /// A raised surface for controls that sit on a card.
    var control: Color { colorScheme == .light ? .black.opacity(0.06) : .white.opacity(0.075) }
    var controlHover: Color { colorScheme == .light ? .black.opacity(0.1) : .white.opacity(0.12) }
    var controlStroke: Color { colorScheme == .light ? .black.opacity(0.12) : .white.opacity(0.1) }
    /// Secondary and tertiary text. The system's own are too light on the
    /// Daylight theme's cards: roughly 3:1 contrast.
    var secondaryText: Color { colorScheme == .light ? .black.opacity(0.66) : .white.opacity(0.72) }
    var tertiaryText: Color { colorScheme == .light ? .black.opacity(0.5) : .white.opacity(0.55) }
    /// The grouped card behind a section's rows.
    var card: Color { colorScheme == .light ? .white.opacity(0.75) : .white.opacity(0.04) }
    var cardStroke: Color { colorScheme == .light ? .black.opacity(0.08) : .white.opacity(0.07) }
}

/// A pill. A stroked `Capsule` left small vertical marks at both ends when
/// rendered; a rounded rectangle just short of fully round draws cleanly.
struct PillShape: InsettableShape {
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: inset, dy: inset)
        return RoundedRectangle(cornerRadius: max(0, rect.height / 2 - 0.75), style: .circular).path(in: rect)
    }

    func inset(by amount: CGFloat) -> PillShape { PillShape(inset: inset + amount) }
}

/// Reads the selected theme; controls use it instead of being passed a palette.
private struct ThemeReader<Content: View>: View {
    @AppStorage("Clockin.Theme") private var themeRaw = ClockinThemeChoice.carbon.rawValue
    let content: (ClockinPalette) -> Content

    init(@ViewBuilder content: @escaping (ClockinPalette) -> Content) {
        self.content = content
    }

    var body: some View { content(ClockinThemeChoice.selected(themeRaw).palette) }
}

/// The pointing hand over anything clickable. Pops the cursor if the view goes
/// away while hovered, so the arrow never gets stuck.
private struct PointerOnHover: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled
    @Binding var hovering: Bool
    @State private var cursorPushed = false

    func body(content: Content) -> some View {
        content
            .onHover { inside in
                hovering = inside
                updateCursor(inside && isEnabled)
            }
            .onChange(of: isEnabled) { _, enabled in updateCursor(hovering && enabled) }
            .onDisappear {
                hovering = false
                updateCursor(false)
            }
    }

    private func updateCursor(_ needed: Bool) {
        guard needed != cursorPushed else { return }
        cursorPushed = needed
        if needed { NSCursor.pointingHand.push() } else { NSCursor.pop() }
    }
}

// MARK: Buttons

enum ClockinButtonKind {
    /// The main action on a screen: filled with the accent.
    case primary
    /// Other actions: a raised neutral surface.
    case secondary
    /// Accent-tinted, for actions that belong to a row ("Manage").
    case tinted
    /// Text-only until hovered, for low-emphasis links ("View all").
    case ghost
    /// Destructive actions.
    case destructive
}

enum ClockinControlSize {
    case small, regular, large

    var height: CGFloat {
        switch self {
        case .small: S(26)
        case .regular: S(32)
        case .large: S(42)
        }
    }

    var font: Font {
        switch self {
        case .small: .system(size: S(11), weight: .semibold)
        case .regular: .system(size: S(12.5), weight: .semibold)
        case .large: .system(size: S(14), weight: .bold)
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .small: S(10)
        case .regular: S(14)
        case .large: S(18)
        }
    }

    var radius: CGFloat {
        switch self {
        case .small: S(7)
        case .regular: S(9)
        case .large: S(12)
        }
    }
}

struct ClockinButtonStyle: ButtonStyle {
    var kind: ClockinButtonKind = .secondary
    var size: ClockinControlSize = .regular
    var fullWidth = false

    func makeBody(configuration: Configuration) -> some View {
        ClockinButtonBody(configuration: configuration, kind: kind, size: size, fullWidth: fullWidth)
    }
}

extension ButtonStyle where Self == ClockinButtonStyle {
    static func clockin(_ kind: ClockinButtonKind = .secondary, size: ClockinControlSize = .regular, fullWidth: Bool = false) -> ClockinButtonStyle {
        ClockinButtonStyle(kind: kind, size: size, fullWidth: fullWidth)
    }
}

private struct ClockinButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let kind: ClockinButtonKind
    let size: ClockinControlSize
    let fullWidth: Bool
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovering = false

    var body: some View {
        ThemeReader { theme in
            let shape = RoundedRectangle(cornerRadius: size.radius, style: .continuous)
            configuration.label
                .font(size.font)
                .lineLimit(1)
                .padding(.horizontal, size.horizontalPadding)
                .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: size.height)
                .foregroundStyle(foreground(theme))
                .background(background(theme), in: shape)
                .overlay(shape.strokeBorder(stroke(theme), lineWidth: 1))
                .contentShape(shape)
                .scaleEffect(configuration.isPressed && isEnabled ? 0.97 : 1)
                .opacity(isEnabled ? 1 : 0.45)
                .animation(.snappy(duration: 0.14), value: configuration.isPressed)
                .animation(.easeOut(duration: 0.12), value: hovering)
                .modifier(PointerOnHover(hovering: $hovering))
        }
    }

    private var lit: Bool { hovering && isEnabled }

    private func foreground(_ theme: ClockinPalette) -> Color {
        switch kind {
        case .primary: theme.actionForeground
        case .secondary: .primary
        case .tinted, .ghost: theme.accent
        case .destructive: .red
        }
    }

    private func background(_ theme: ClockinPalette) -> Color {
        switch kind {
        case .primary: theme.accent.opacity(lit ? 0.88 : 1)
        case .secondary: lit ? theme.controlHover : theme.control
        case .tinted: theme.accent.opacity(lit ? 0.24 : 0.15)
        case .ghost: lit ? theme.control : .clear
        case .destructive: Color.red.opacity(lit ? 0.22 : 0.13)
        }
    }

    private func stroke(_ theme: ClockinPalette) -> Color {
        switch kind {
        case .primary: .white.opacity(0.18)
        case .secondary: theme.controlStroke
        case .tinted: theme.accent.opacity(0.3)
        case .ghost: .clear
        case .destructive: Color.red.opacity(0.3)
        }
    }
}

/// A square icon button with a visible surface, for toolbars and row actions.
struct ClockinIconButtonStyle: ButtonStyle {
    var size: CGFloat = 30
    var tint: Color?
    var destructive = false

    func makeBody(configuration: Configuration) -> some View {
        ClockinIconButtonBody(configuration: configuration, size: size, tint: tint, destructive: destructive)
    }
}

extension ButtonStyle where Self == ClockinIconButtonStyle {
    static func clockinIcon(size: CGFloat = 30, tint: Color? = nil, destructive: Bool = false) -> ClockinIconButtonStyle {
        ClockinIconButtonStyle(size: size, tint: tint, destructive: destructive)
    }
}

private struct ClockinIconButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let size: CGFloat
    let tint: Color?
    let destructive: Bool
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovering = false

    var body: some View {
        ThemeReader { theme in
            let shape = RoundedRectangle(cornerRadius: S(size * 0.3), style: .continuous)
            let lit = hovering && isEnabled
            configuration.label
                .font(.system(size: S(size * 0.43), weight: .semibold))
                .frame(width: S(size), height: S(size))
                .foregroundStyle(destructive && lit ? Color.red : (tint ?? (lit ? Color.primary : Color.secondary)))
                .background(destructive && lit ? Color.red.opacity(0.14) : (lit ? theme.controlHover : theme.control), in: shape)
                .overlay(shape.strokeBorder(theme.controlStroke, lineWidth: 1))
                .contentShape(shape)
                .scaleEffect(configuration.isPressed && isEnabled ? 0.92 : 1)
                .opacity(isEnabled ? 1 : 0.4)
                .animation(.snappy(duration: 0.14), value: configuration.isPressed)
                .animation(.easeOut(duration: 0.12), value: hovering)
                .modifier(PointerOnHover(hovering: $hovering))
        }
    }
}

// MARK: Field chrome

/// The shared look of menus, text fields and steppers.
private struct FieldChrome: ViewModifier {
    var focused = false
    var hovering = false

    func body(content: Content) -> some View {
        ThemeReader { theme in
            let shape = RoundedRectangle(cornerRadius: S(9), style: .continuous)
            content
                .padding(.horizontal, S(11))
                .frame(minHeight: S(32))
                .background(hovering ? theme.controlHover : theme.control, in: shape)
                .overlay(shape.strokeBorder(focused ? theme.accent.opacity(0.85) : theme.controlStroke, lineWidth: focused ? 1.5 : 1))
                .animation(.easeOut(duration: 0.12), value: hovering)
                .animation(.easeOut(duration: 0.15), value: focused)
        }
    }
}

/// A drop-down that shows its value in a full-size field with a chevron,
/// opening a menu with a checkmark on the current choice.
struct ClockinSelect<Value: Hashable>: View {
    struct Option: Identifiable {
        let value: Value
        let label: String
        var systemImage: String?
        var disabled = false
        var help: String?
        var id: Value { value }
    }

    @Binding var selection: Value
    let options: [Option]
    var width: CGFloat?
    @State private var hovering = false

    init(selection: Binding<Value>, options: [Option], width: CGFloat? = nil) {
        _selection = selection
        self.options = options
        self.width = width
    }

    var body: some View {
        Menu {
            ForEach(options) { option in
                Button {
                    selection = option.value
                } label: {
                    if option.value == selection {
                        Label(option.label, systemImage: "checkmark")
                    } else if let image = option.systemImage {
                        Label(option.label, systemImage: image)
                    } else {
                        Text(option.label)
                    }
                }
                .disabled(option.disabled)
                .help(option.help ?? option.label)
            }
        } label: {
            HStack(spacing: S(8)) {
                Text(options.first { $0.value == selection }?.label ?? "Choose")
                    .font(ClockinFont.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: S(4))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: S(9.5), weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: fixedWidth, alignment: .leading)
            .frame(maxWidth: fills ? .infinity : nil)
            .modifier(FieldChrome(hovering: hovering))
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize(horizontal: !fills, vertical: true)
        .modifier(PointerOnHover(hovering: $hovering))
    }

    /// `width: .infinity` stretches the field across its row.
    private var fills: Bool { width == .infinity }
    private var fixedWidth: CGFloat? { fills ? nil : width.map { S($0) - S(22) } }
}

extension ClockinSelect where Value == String {
    /// Options whose label is the value itself.
    init(selection: Binding<String>, values: [String], width: CGFloat? = nil) {
        self.init(selection: selection, options: values.map { Option(value: $0, label: $0) }, width: width)
    }
}

/// A segmented control with a sliding indicator, for two to five short choices.
struct ClockinSegmented<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(value: Value, label: String)]
    @Namespace private var indicator
    @FocusState private var focused: Bool

    var body: some View {
        ThemeReader { theme in
            HStack(spacing: S(2)) {
                ForEach(options, id: \.value) { option in
                    SegmentButton(label: option.label, isOn: option.value == selection, theme: theme, indicator: indicator) {
                        withAnimation(.snappy(duration: 0.22)) { selection = option.value }
                    }
                }
            }
            .padding(S(3))
            .background(theme.control, in: RoundedRectangle(cornerRadius: S(10), style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: S(10), style: .continuous)
                .strokeBorder(focused ? theme.accent.opacity(0.9) : theme.controlStroke, lineWidth: focused ? 2 : 1))
            // Arrow keys move through the choices, like a native segmented control.
            .focusable()
            .focused($focused)
            .onMoveCommand { direction in
                switch direction {
                case .left, .up: move(by: -1)
                case .right, .down: move(by: 1)
                default: break
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Choose")
        }
    }

    private func move(by step: Int) {
        guard let index = options.firstIndex(where: { $0.value == selection }) else { return }
        let next = min(max(index + step, 0), options.count - 1)
        guard next != index else { return }
        withAnimation(.snappy(duration: 0.22)) { selection = options[next].value }
    }

    private struct SegmentButton: View {
        let label: String
        let isOn: Bool
        let theme: ClockinPalette
        let indicator: Namespace.ID
        let action: () -> Void
        @State private var hovering = false

        var body: some View {
            Button(action: action) {
                Text(label)
                    .font(.system(size: S(11.5), weight: isOn ? .semibold : .medium))
                    .lineLimit(1)
                    .foregroundStyle(isOn ? theme.actionForeground : (hovering ? Color.primary : Color.secondary))
                    .frame(maxWidth: .infinity, minHeight: S(26))
                    .padding(.horizontal, S(6))
                    .background {
                        if isOn {
                            RoundedRectangle(cornerRadius: S(7.5), style: .continuous)
                                .fill(theme.accent)
                                .shadow(color: .black.opacity(0.18), radius: S(2), y: S(1))
                                .matchedGeometryEffect(id: "segment", in: indicator)
                        } else if hovering {
                            RoundedRectangle(cornerRadius: S(7.5), style: .continuous).fill(theme.controlHover)
                        }
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .modifier(PointerOnHover(hovering: $hovering))
            .accessibilityAddTraits(isOn ? .isSelected : [])
        }
    }
}

/// A text field in field chrome, with an optional unit after the value.
struct ClockinTextField: View {
    let placeholder: String
    @Binding var text: String
    var suffix: String?
    var width: CGFloat?
    var alignment: TextAlignment = .trailing
    var onEditingEnd: (() -> Void)?
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: S(6)) {
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: S(12.5), weight: .semibold).monospacedDigit())
                .multilineTextAlignment(alignment)
                .focused($focused)
            if let suffix {
                Text(suffix).font(.system(size: S(11), weight: .medium)).foregroundStyle(.secondary)
            }
        }
        .frame(width: width.map { S($0) - S(22) })
        .modifier(FieldChrome(focused: focused))
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
        .onChange(of: focused) { _, value in
            if !value { onEditingEnd?() }
        }
    }
}

/// Keeps the native numeric field's locale parsing and editing/commit semantics.
struct ClockinIntegerField: View {
    let title: String
    @Binding var value: Int
    @FocusState private var focused: Bool

    var body: some View {
        TextField("0", value: $value, format: .number)
            .textFieldStyle(.plain)
            .font(.system(size: S(12.5), weight: .semibold).monospacedDigit())
            .multilineTextAlignment(.center)
            .focused($focused)
            .modifier(FieldChrome(focused: focused))
            .accessibilityLabel(title)
    }
}

/// A readable date or time field with the native editor in a popover.
struct ClockinDateField: View {
    let title: String
    @Binding var selection: Date
    var displayedComponents: DatePickerComponents
    var systemImage: String?
    private let bounds: ClosedRange<Date>
    @Environment(\.locale) private var locale
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovering = false
    @State private var presented = false

    init(_ title: String, selection: Binding<Date>,
         in range: ClosedRange<Date>? = nil,
         displayedComponents: DatePickerComponents = .date,
         systemImage: String? = nil) {
        self.title = title
        _selection = selection
        bounds = range ?? Date.distantPast...Date.distantFuture
        self.displayedComponents = displayedComponents
        self.systemImage = systemImage
    }

    init(_ title: String, selection: Binding<Date>, in range: PartialRangeFrom<Date>,
         displayedComponents: DatePickerComponents = .date, systemImage: String? = nil) {
        self.init(title, selection: selection, in: range.lowerBound...Date.distantFuture,
                  displayedComponents: displayedComponents, systemImage: systemImage)
    }

    init(_ title: String, selection: Binding<Date>, in range: PartialRangeThrough<Date>,
         displayedComponents: DatePickerComponents = .date, systemImage: String? = nil) {
        self.init(title, selection: selection, in: Date.distantPast...range.upperBound,
                  displayedComponents: displayedComponents, systemImage: systemImage)
    }

    private var formattedValue: String {
        selection.formatted(Date.FormatStyle(
            date: displayedComponents.contains(.date) ? .abbreviated : .omitted,
            time: displayedComponents.contains(.hourAndMinute) ? .shortened : .omitted
        ).locale(locale))
    }

    var body: some View {
        Button { presented.toggle() } label: {
            HStack(spacing: S(8)) {
                if let systemImage { Image(systemName: systemImage).foregroundStyle(.secondary) }
                Text(formattedValue).font(ClockinFont.body).lineLimit(1)
                Spacer(minLength: S(4))
                Image(systemName: "chevron.down")
                    .font(.system(size: S(9), weight: .semibold)).foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .modifier(FieldChrome(focused: presented, hovering: hovering && isEnabled))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.45)
        .modifier(PointerOnHover(hovering: $hovering))
        .accessibilityLabel(title)
        .accessibilityValue(formattedValue)
        .popover(isPresented: $presented) {
            ThemeReader { theme in
                VStack(alignment: .leading, spacing: S(12)) {
                    Text(title).font(ClockinFont.section)
                    if displayedComponents.contains(.date) {
                        picker.datePickerStyle(.graphical)
                    } else {
                        picker.datePickerStyle(.stepperField).controlSize(.large)
                    }
                    HStack { Spacer(); Button("Done") { presented = false }.buttonStyle(.clockin(.primary)) }
                }
                .padding(S(16))
                .background(theme.background)
                .preferredColorScheme(theme.colorScheme)
            }
        }
    }

    private var picker: some View {
        DatePicker(title, selection: $selection, in: bounds, displayedComponents: displayedComponents)
            .labelsHidden()
            .accessibilityLabel(title)
    }
}

/// Minus and plus buttons around a value.
struct ClockinStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step = 1
    var format: (Int) -> String = { "\($0)" }

    var body: some View {
        HStack(spacing: S(6)) {
            Button { value = max(range.lowerBound, value - step) } label: { Image(systemName: "minus") }
                .buttonStyle(.clockinIcon(size: 28))
                .disabled(value <= range.lowerBound)
                .accessibilityLabel("Decrease")
            Text(format(value))
                .font(.system(size: S(12.5), weight: .semibold).monospacedDigit())
                .frame(minWidth: S(36))
            Button { value = min(range.upperBound, value + step) } label: { Image(systemName: "plus") }
                .buttonStyle(.clockinIcon(size: 28))
                .disabled(value >= range.upperBound)
                .accessibilityLabel("Increase")
        }
        .accessibilityElement(children: .contain)
    }
}

/// A pill that toggles on and off, for picking several items from a set.
struct ClockinChip: View {
    let title: String
    @Binding var isOn: Bool
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovering = false

    var body: some View {
        ThemeReader { theme in
            Button { withAnimation(.snappy(duration: 0.16)) { isOn.toggle() } } label: {
                HStack(spacing: S(5)) {
                    Image(systemName: isOn ? "checkmark" : "plus")
                        .font(.system(size: S(9), weight: .bold))
                    Text(title).font(.system(size: S(11.5), weight: .semibold))
                }
                .padding(.horizontal, S(11))
                .frame(minHeight: S(28))
                // Never squeezed: a narrower capsule than its text cut the ends off.
                .fixedSize()
                .foregroundStyle(isOn ? theme.accent : .secondary)
                .background(isOn ? theme.accent.opacity(hovering ? 0.24 : 0.16) : (hovering ? theme.controlHover : theme.control), in: PillShape())
                .overlay(PillShape().strokeBorder(isOn ? theme.accent.opacity(0.4) : theme.controlStroke, lineWidth: 1))
                .contentShape(PillShape())
                .opacity(isEnabled ? 1 : 0.45)
            }
            .buttonStyle(.plain)
            .modifier(PointerOnHover(hovering: $hovering))
            .accessibilityAddTraits(isOn ? .isSelected : [])
        }
    }
}

/// A switch in the theme's accent. Drawn by Clockin rather than AppKit, so it
/// keeps the theme colour in windows that are not key (the menu bar panel,
/// the pinned timer) and in every theme.
struct ClockinSwitch: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle("", isOn: $isOn).labelsHidden().toggleStyle(ClockinSwitchStyle())
            .accessibilityLabel(title)
    }
}

struct ClockinSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        ClockinSwitchBody(configuration: configuration)
    }
}

private struct ClockinSwitchBody: View {
    let configuration: ToggleStyleConfiguration
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false

    var body: some View {
        ThemeReader { theme in
            let on = configuration.isOn
            Button {
                withAnimation(reduceMotion ? nil : .spring(duration: 0.26, bounce: 0.25)) { configuration.isOn.toggle() }
            } label: {
                HStack(spacing: S(8)) {
                    configuration.label
                    ZStack(alignment: on ? .trailing : .leading) {
                        PillShape()
                            .fill(on ? theme.accent : (hovering ? theme.controlHover : theme.control))
                            .overlay(PillShape().strokeBorder(on ? Color.white.opacity(0.18) : theme.controlStroke, lineWidth: 1))
                        Circle()
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.28), radius: S(1.5), y: S(1))
                            .padding(S(2.5))
                    }
                    .frame(width: S(40), height: S(23))
                }
                .contentShape(Rectangle())
                .opacity(isEnabled ? 1 : 0.45)
            }
            .buttonStyle(.plain)
            .modifier(PointerOnHover(hovering: $hovering))
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isToggle)
            .accessibilityValue(on ? "On" : "Off")
        }
    }
}

// MARK: Layout

/// A titled group of rows on one card, like System Settings.
struct ClockinSection<Content: View>: View {
    let title: String
    var footer: String?
    @ViewBuilder let content: Content

    var body: some View {
        ThemeReader { theme in
            VStack(alignment: .leading, spacing: S(7)) {
                Text(title)
                    .font(ClockinFont.section)
                    .foregroundStyle(.secondary)
                    .padding(.leading, S(4))
                VStack(spacing: S(0)) { content }
                    .background(theme.card, in: RoundedRectangle(cornerRadius: S(13), style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: S(13), style: .continuous).strokeBorder(theme.cardStroke, lineWidth: 1))
                if let footer {
                    Text(footer)
                        .font(ClockinFont.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, S(4))
                }
            }
        }
    }
}

/// One setting: an icon, a title with an optional explanation, and a control.
struct ClockinRow<Trailing: View>: View {
    var icon: String?
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        ThemeReader { theme in
            HStack(spacing: S(11)) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: S(12), weight: .semibold))
                        .foregroundStyle(theme.accent)
                        .frame(width: S(28), height: S(28))
                        .background(theme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: S(8), style: .continuous))
                }
                VStack(alignment: .leading, spacing: S(2)) {
                    Text(title).font(ClockinFont.body).foregroundStyle(.primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(ClockinFont.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .layoutPriority(1)
                Spacer(minLength: S(8))
                trailing
            }
            .padding(.horizontal, S(13))
            .padding(.vertical, S(9))
            .frame(minHeight: S(50))
        }
    }
}

extension ClockinRow where Trailing == EmptyView {
    init(icon: String? = nil, title: String, subtitle: String? = nil) {
        self.init(icon: icon, title: title, subtitle: subtitle) { EmptyView() }
    }
}

/// A hairline between rows of a section, inset past the icon.
struct ClockinRowDivider: View {
    var inset: CGFloat = 52

    var body: some View {
        ThemeReader { theme in
            Rectangle().fill(theme.cardStroke).frame(height: 1).padding(.leading, S(inset))
        }
    }
}

/// A screen title bar shared by the main window's tabs.
struct ClockinScreenHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: S(8)) {
            Text(title).font(ClockinFont.title)
            Spacer()
            trailing
        }
        .padding(.horizontal, S(16))
        .frame(height: S(52))
    }
}

extension ClockinScreenHeader where Trailing == EmptyView {
    init(title: String) {
        self.init(title: title) { EmptyView() }
    }
}

extension View {
    /// Applies the theme's text colours to every `.secondary` and `.tertiary`
    /// in a window's content. Sheets need it too: they start a new host.
    func clockinTextStyles() -> some View {
        modifier(ClockinTextStyles())
    }
}

private struct ClockinTextStyles: ViewModifier {
    @AppStorage("Clockin.Theme") private var themeRaw = ClockinThemeChoice.carbon.rawValue

    func body(content: Content) -> some View {
        let theme = ClockinThemeChoice.selected(themeRaw).palette
        return content.foregroundStyle(Color.primary, theme.secondaryText, theme.tertiaryText)
    }
}

// MARK: Brand

/// The Clockin mark: the mascot's head, as in the menu bar, with the name.
struct ClockinLogo: View {
    var size: CGFloat = 22
    var showsName = true

    var body: some View {
        ThemeReader { theme in
            HStack(spacing: S(size * 0.32)) {
                Image(nsImage: MenuBarIcon.image(.running, pointSize: S(size)))
                    .renderingMode(.template)
                    .foregroundStyle(theme.accent)
                    .accessibilityHidden(true)
                if showsName {
                    Text("Clockin")
                        .font(.system(size: S(size * 0.7), weight: .bold, design: theme.fontDesign))
                        .foregroundStyle(.primary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Clockin")
        }
    }
}

// MARK: Theme picker

/// Every theme as a small preview card, instead of a list of names.
struct ClockinThemePicker: View {
    @Binding var selection: String

    private let columns = [GridItem(.flexible(), spacing: S(9)), GridItem(.flexible(), spacing: S(9))]

    var body: some View {
        LazyVGrid(columns: columns, spacing: S(9)) {
            ForEach(ClockinThemeChoice.allCases) { choice in
                ThemeCard(choice: choice, isOn: choice.rawValue == selection) {
                    withAnimation(.snappy(duration: 0.2)) { selection = choice.rawValue }
                }
            }
        }
    }

    private struct ThemeCard: View {
        let choice: ClockinThemeChoice
        let isOn: Bool
        let action: () -> Void
        @State private var hovering = false

        var body: some View {
            let palette = choice.palette
            let shape = RoundedRectangle(cornerRadius: S(11), style: .continuous)
            Button(action: action) {
                VStack(alignment: .leading, spacing: S(7)) {
                    // A miniature of the timer card in this theme.
                    VStack(alignment: .leading, spacing: S(4)) {
                        HStack(spacing: S(4)) {
                            Circle().fill(palette.accent).frame(width: S(6), height: S(6))
                            Capsule().fill(palette.secondary.opacity(0.7)).frame(width: S(26), height: S(3))
                        }
                        Text("01:07")
                            .font(.system(size: S(15), weight: .bold, design: palette.fontDesign).monospacedDigit())
                            .foregroundStyle(palette.colorScheme == .light ? Color.black : Color.white)
                        Capsule().fill(palette.accent).frame(width: S(44), height: S(5))
                    }
                    .padding(S(9))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(palette.background, in: RoundedRectangle(cornerRadius: S(8), style: .continuous))
                    HStack(spacing: S(4)) {
                        Text(choice.rawValue)
                            .font(.system(size: S(11.5), weight: .semibold, design: palette.fontDesign))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        if isOn {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: S(12), weight: .bold))
                                .foregroundStyle(palette.accent)
                        }
                    }
                    .padding(.horizontal, S(2))
                }
                .padding(S(6))
                .background(hovering ? Color.primary.opacity(0.06) : Color.primary.opacity(0.03), in: shape)
                .overlay(shape.strokeBorder(isOn ? palette.accent : Color.primary.opacity(hovering ? 0.18 : 0.1), lineWidth: isOn ? 2 : 1))
                .contentShape(shape)
                .animation(.easeOut(duration: 0.12), value: hovering)
            }
            .buttonStyle(.plain)
            .modifier(PointerOnHover(hovering: $hovering))
            .accessibilityLabel("\(choice.rawValue) theme")
            .accessibilityAddTraits(isOn ? .isSelected : [])
        }
    }
}
