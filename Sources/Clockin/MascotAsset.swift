import AppKit
import SwiftUI

enum MascotAsset: String {
    case idle, working, paused, celebrate

    /// Tek karakterli gorsel. `idle`/`paused` dosyalari eskiden dort maskotluk
    /// birer sayfaydi ve kartta yarim robotlar gorunuyordu; artik `pose2` ve
    /// `coffee1`'in kopyalari. Progress ekrani hala o adlarla okuyor.
    var imageName: String {
        switch self {
        case .idle: "pose2"
        case .paused: "coffee1"
        case .working: "working"
        case .celebrate: "celebrate"
        }
    }

    var message: String {
        switch self {
        case .idle: "Ready when you are"
        case .working: "You are doing great, keep going!"
        case .paused: "Taking a reset break"
        case .celebrate: "Every focused hour makes your companion stronger."
        }
    }
}

@MainActor
struct ClockinMascotImage: View {
    let asset: String
    private static var images: [String: NSImage] = [:]

    private static func image(named asset: String) -> NSImage? {
        if let cached = images[asset] { return cached }
        guard let url = Bundle.module.url(forResource: asset, withExtension: "png"),
              let image = NSImage(contentsOf: url) else { return nil }
        images[asset] = image
        return image
    }

    var body: some View {
        Group {
            if let image = Self.image(named: asset) {
                Image(nsImage: image).resizable().interpolation(.none).scaledToFit()
            } else {
                Image(systemName: "sparkles").resizable().scaledToFit()
                    .padding(S(18)).foregroundStyle(.cyan)
            }
        }
        .accessibilityHidden(true)
    }
}

@MainActor
struct ClockinMascotStage: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("Clockin.MascotDefault") private var defaultMode = "Auto"
    @EnvironmentObject private var store: ClockStore
    private var state: MascotAsset {
        guard let running = store.running else { return .idle }
        return running.isPaused ? .paused : .working
    }
    @State private var pose: Int?
    @State private var poseToken = UUID()

    var body: some View {
        // Esik burada da denetlenir: secildikten sonra oturumlar silinip toplam
        // sure esigin altina duserse kilitli mod acik kalmasin.
        let mode = CompanionMode.resolve(defaultMode, totalHours: (store.totalDuration + store.elapsed()) / 3600)
        return ZStack {
            if let pose {
                ClockinPoseMascot(index: pose)
            } else if mode == .typing {
                ClockinFrameMascot(prefix: "frame", interval: 0.18)
            } else if mode == .coffee {
                ClockinFrameMascot(prefix: "coffee", interval: 0.28)
            } else if let fixed = mode.fixedPoseIndex {
                ClockinPoseMascot(index: fixed)
            } else {
                switch state {
                case .working: ClockinFrameMascot(prefix: "frame", interval: 0.18)
                case .paused: ClockinFrameMascot(prefix: "coffee", interval: 0.28)
                case .idle, .celebrate: ClockinMascotImage(asset: state.imageName)
                }
            }
            if !reduceMotion && pose != nil {
                ClockinMascotEffects()
                    .id(poseToken)
                    .allowsHitTesting(false)
            }
        }
        .phaseAnimator(breathing ? [false, true] : [false]) { content, lifted in
            content
                .offset(y: breathing && lifted ? -1.5 : 0)
                .scaleEffect(breathing && lifted ? 1.018 : 1, anchor: .bottom)
        } animation: { _ in
            breathing ? .easeInOut(duration: 2.4) : nil
        }
        .phaseAnimator([false, true, false], trigger: state) { content, settling in
            content
                .scaleEffect(!reduceMotion && settling ? 0.96 : 1)
                .offset(y: !reduceMotion && settling ? 2 : 0)
        } animation: { settling in
            reduceMotion ? nil : (settling ? .easeOut(duration: 0.1) : .spring(duration: 0.4, bounce: 0.2))
        }
        .phaseAnimator([false, true, false], trigger: poseToken) { content, reacting in
            content
                .scaleEffect(!reduceMotion && reacting ? 1.12 : 1)
                .rotationEffect(.degrees(!reduceMotion && reacting ? -7 : 0))
                .offset(y: !reduceMotion && reacting ? -4 : 0)
        } animation: { reacting in
            reduceMotion ? nil : .spring(duration: reacting ? 0.2 : 0.45, bounce: 0.3)
        }
        .transaction { if reduceMotion { $0.animation = nil; $0.disablesAnimations = true } }
        .contentShape(Rectangle())
        .onTapGesture { showPose() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Focus companion")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { showPose() }
        .task(id: poseToken) {
            guard pose != nil else { return }
            // Yeni dokunus eski beklemeyi iptal eder; poz erken kapanmaz.
            do { try await Task.sleep(for: .seconds(2.2)) }
            catch { return }
            pose = nil
        }
    }

    private var breathing: Bool { state == .working && !reduceMotion }

    private func showPose() {
        pose = (1...4).filter { $0 != pose }.randomElement()
        poseToken = UUID()
    }
}

private struct ClockinPoseMascot: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let index: Int

    // `scenePhase` burada kullanilmaz: pencere AppKit'in NSHostingView'i ile
    // aciliyor, bir SwiftUI sahnesine ait degil ve deger hep `.background`
    // geliyor. Ona bakmak maskotu tamamen donduruyordu.
    private var isAnimating: Bool { !reduceMotion }

    var body: some View {
        ClockinMascotImage(asset: "pose\(index)")
            .phaseAnimator(isAnimating ? [false, true] : [false]) { content, phase in
                let moving = isAnimating && phase
                content
                    .scaleEffect(moving ? (index == 3 ? 1.05 : 0.98) : 1)
                    .offset(x: moving && index == 3 ? 3 : 0, y: moving ? -2 : 0)
                    .rotationEffect(.degrees(moving && index == 2 ? 4 : (moving && index == 4 ? -3 : 0)))
            } animation: { _ in
                isAnimating ? .easeInOut(duration: index == 3 ? 0.4 : 0.9) : nil
            }
    }
}

@MainActor
private struct ClockinFrameMascot: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let prefix: String
    let interval: Double
    @State private var frame = 1

    // `scenePhase`'e bakilmaz; nedeni `ClockinPoseMascot`'ta.
    private var isAnimating: Bool { !reduceMotion }

    var body: some View {
        ClockinMascotImage(asset: "\(prefix)\(frame)")
            .task(id: isAnimating) {
                guard isAnimating else { return }
                // Gorev gorunumle yasar; sayacin yenilenmesi kareleri sifirlamaz.
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(interval)) }
                    catch { return }
                    frame = frame % 4 + 1
                }
            }
    }
}

private struct ClockinMascotEffects: View {
    // Oran degisince efekt boyutlari yeniden hesaplansin.
    @AppStorage(UIScale.key) private var uiScaleObserver = UIScale.defaultPercent
    @State private var start = Date()
    @State private var seed = Int.random(in: 0...4)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
            let elapsed = max(0, context.date.timeIntervalSince(start))
            let phase = min(elapsed.truncatingRemainder(dividingBy: 8) / 1.6, 1)
            let eased = 1 - pow(1 - phase, 3)
            let effect = (seed + Int(elapsed / 8)) % 5
            Group {
                switch effect {
                case 0:
                    Text("$  $  $").font(.system(size: S(10), weight: .black, design: .rounded))
                        .foregroundStyle(.green).offset(x: S(13), y: S(-24 + 51 * eased)).opacity(1 - eased)
                case 1:
                    Text("✦  ✧  ✦").font(.system(size: S(12), weight: .bold))
                        .foregroundStyle(.orange).scaleEffect(0.7 + 0.55 * eased).opacity(1 - 0.8 * eased)
                case 2:
                    Text("♪  ♫  ♪").font(.system(size: S(12), weight: .bold))
                        .foregroundStyle(.cyan).offset(x: S(-8 + 26 * eased), y: S(8 - 28 * eased)).opacity(1 - eased)
                case 3:
                    Text("✹  ✹").font(.system(size: S(11), weight: .bold))
                        .foregroundStyle(.yellow).rotationEffect(.degrees(-15 + 50 * eased)).opacity(1 - 0.8 * eased)
                default:
                    Text("+XP").font(.system(size: S(10), weight: .black, design: .monospaced))
                        .foregroundStyle(.green).offset(y: S(2 - 27 * eased)).opacity(1 - eased)
                }
            }
        }
        .accessibilityHidden(true)
    }
}
