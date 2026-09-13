import AppKit
import SwiftUI

/// Guncelleme ilerlemesini gosteren kucuk pencere.
///
/// Kapatmak guncellemeyi durdurmaz; Ayarlar'daki satirdan geri acilabilir.
@MainActor
final class UpdateWindowController {
    static let shared = UpdateWindowController()
    private var window: NSWindow?

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: UpdateWindowView())
            // Ayrintilar acilip kapaninca pencere icerige gore boyutlansin.
            hosting.sizingOptions = [.preferredContentSize]
            let window = NSWindow(
                contentRect: .zero,
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "Clockin Update"
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isReleasedWhenClosed = false
            window.isMovableByWindowBackground = false
            window.contentViewController = hosting
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }

    func close() {
        window?.orderOut(nil)
    }
}

struct UpdateWindowView: View {
    @ObservedObject private var installer = UpdateInstaller.shared
    @AppStorage("Clockin.Theme") private var themeRaw = ClockinThemeChoice.carbon.rawValue
    @AppStorage(UIScale.key) private var uiScale = UIScale.defaultPercent
    @State private var showDetails = false

    private var theme: ClockinPalette { ClockinThemeChoice.selected(themeRaw).palette }
    private var failed: Bool { installer.phase == .failed }

    var body: some View {
        VStack(alignment: .leading, spacing: S(16)) {
            HStack(alignment: .center, spacing: S(14)) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: S(56), height: S(56))
                VStack(alignment: .leading, spacing: S(4)) {
                    Text(title)
                        .font(.system(size: S(15), weight: .bold, design: theme.fontDesign))
                    Text(subtitle)
                        .font(.system(size: S(11)))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !failed {
                // Ilerleme zamana gore tahmin edildigi icin cubuk, yeni cikti
                // gelmese de akmali.
                TimelineView(.periodic(from: .now, by: 0.1)) { context in
                    let fraction = installer.displayedFraction(at: context.date)
                    VStack(alignment: .leading, spacing: S(7)) {
                        progressBar(fraction)
                        HStack {
                            Text(stepCaption)
                            Spacer()
                            Text("\(Int((fraction * 100).rounded()))%")
                                .monospacedDigit()
                        }
                        .font(.system(size: S(10), weight: .medium))
                        .foregroundStyle(.secondary)
                    }
                }
            }

            if showDetails || failed {
                details
            }

            buttons
        }
        .padding(.horizontal, S(22))
        // Baslik seridinin yuksekligi guvenli alan olarak zaten birakiliyor.
        .padding(.top, S(6))
        .padding(.bottom, S(18))
        .frame(width: S(430), alignment: .leading)
        .background(theme.background.ignoresSafeArea())
        .environment(\.colorScheme, theme.colorScheme)
        .animation(.easeInOut(duration: 0.2), value: showDetails)
        .animation(.easeInOut(duration: 0.2), value: installer.phase)
    }

    private var title: String {
        switch installer.phase {
        case .idle, .running: "Updating Clockin"
        case .installing: "Installing Clockin"
        case .failed: "Update failed"
        }
    }

    private var subtitle: String {
        switch installer.phase {
        case .idle, .running:
            "You can keep using Clockin. It closes and reopens by itself at the end."
        case .installing:
            "Clockin will close and reopen in a moment."
        case .failed:
            installer.failureMessage ?? "Something went wrong."
        }
    }

    private var stepCaption: String {
        guard let step = installer.progress.step, let number = installer.progress.stepNumber else {
            return "Starting…"
        }
        return "Step \(number) of \(UpdateProgress.Step.allCases.count) · \(step.title)"
    }

    private func progressBar(_ fraction: Double) -> some View {
        Capsule()
            .fill(theme.surface)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(theme.accent)
                        .frame(width: max(S(8), proxy.size.width * fraction))
                        // Adim erken bitince olusan sicrama yumusasin.
                        .animation(.easeOut(duration: 0.3), value: fraction)
                }
            }
            .overlay(Capsule().stroke(theme.surfaceStroke, lineWidth: 1))
            .frame(height: S(8))
    }

    private var details: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(installer.recentLines.suffix(200).joined(separator: "\n"))
                        .font(.system(size: S(9), design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Color.clear.frame(height: 1).id("end")
                }
                .padding(S(10))
            }
            .frame(height: S(150))
            .background(theme.surface, in: RoundedRectangle(cornerRadius: S(9)))
            .onAppear { proxy.scrollTo("end", anchor: .bottom) }
            .onChange(of: installer.recentLines.count) { proxy.scrollTo("end", anchor: .bottom) }
        }
    }

    @ViewBuilder
    private var buttons: some View {
        HStack(spacing: S(10)) {
            switch installer.phase {
            case .failed:
                Button("Show Log") { installer.revealLog() }
                    .buttonStyle(.hitTarget)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Close") { UpdateWindowController.shared.close() }
                Button("Try Again") { installer.retry() }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.accent)
                    .foregroundStyle(theme.actionForeground)
            case .installing:
                Spacer()
            case .idle, .running:
                Button(showDetails ? "Hide Details" : "Show Details") { showDetails.toggle() }
                    .buttonStyle(.hitTarget)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Continue in Background") { UpdateWindowController.shared.close() }
            }
        }
        .font(.system(size: S(11), weight: .semibold))
        .frame(minHeight: S(24))
    }
}
