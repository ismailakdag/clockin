import AppKit
import SwiftUI

/// What a session is doing, for the mascot.
enum MascotAsset {
    case idle, working, paused, celebrate
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
    /// A tap hops, then celebrates for a moment (site: hop, then change pose
    /// in the air).
    @State private var reaction = 0
    @State private var celebrating = false

    var body: some View {
        // Esik burada da denetlenir: secildikten sonra oturumlar silinip toplam
        // sure esigin altina duserse kilitli mod acik kalmasin.
        let mode = CompanionMode.resolve(defaultMode, totalHours: (store.totalDuration + store.elapsed()) / 3600)
        return Group {
            // One view for every mood keeps its state, so a mood change pops
            // instead of cutting to a fresh mascot.
            if let mood = celebrating ? .celebrate : mood(for: mode) {
                ClockinMotionMascot(mood: mood, reaction: reaction)
            } else if let fixed = mode.fixedPoseIndex {
                ClockinPoseMascot(index: fixed)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { react() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Focus companion")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { react() }
        .task(id: reaction) {
            guard reaction > 0 else { return }
            // A new tap cancels the previous wait, so the pose never ends early.
            do {
                if !reduceMotion { try await Task.sleep(for: .milliseconds(330)) }
                celebrating = true
                try await Task.sleep(for: .seconds(2.6))
            } catch { return }
            celebrating = false
        }
    }

    /// Stretch, dance and music have no drawn loops yet and keep their poses.
    private func mood(for mode: CompanionMode) -> MascotMood? {
        switch mode {
        case .auto:
            switch state {
            case .working: .working
            case .paused: .coffee
            case .idle: .hello
            case .celebrate: .celebrate
            }
        case .typing: .working
        case .coffee: .coffee
        case .victory: .celebrate
        case .stretch, .dance, .music: nil
        }
    }

    private func react() {
        reaction += 1
    }
}

/// A mood's rest frame as a plain image, for renders that cannot host layers.
struct ClockinMascotStill: View {
    let mood: MascotMood

    var body: some View {
        if let id = MascotFrames.shared.library?[mood].rest, let image = MascotFrames.shared.image(id) {
            Image(decorative: image, scale: 1).resizable().interpolation(.high).scaledToFit()
        }
    }
}

/// Decoded frames, shared by every mascot on screen. A frame change is then a
/// texture swap, not a PNG decode in the middle of an animation.
@MainActor
final class MascotFrames {
    static let shared = MascotFrames()

    let library: MascotLibrary?
    private var images: [String: CGImage] = [:]
    private var loading: [MascotMood: Task<Void, Never>] = [:]

    private init() {
        library = Bundle.module.url(forResource: "mascot-clips", withExtension: "json")
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? MascotLibrary(data: $0) }
    }

    /// Decodes on first use if the mood has not been preloaded yet.
    func image(_ id: String) -> CGImage? {
        if let image = images[id] { return image }
        guard let image = Self.decode(id) else { return nil }
        images[id] = image
        return image
    }

    /// Decodes a mood's frames off the main thread, once.
    func preload(_ mood: MascotMood) async {
        guard let library else { return }
        if let task = loading[mood] { return await task.value }
        let missing = library[mood].frames.filter { images[$0] == nil }
        let task = Task { [weak self] in
            let decoded = await Task.detached(priority: .utility) {
                missing.compactMap { id in Self.decode(id).map { (id, $0) } }
            }.value
            for (id, image) in decoded { self?.images[id] = image }
        }
        loading[mood] = task
        await task.value
    }

    nonisolated private static func decode(_ id: String) -> CGImage? {
        guard let url = Bundle.module.url(forResource: id, withExtension: "png"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
    }
}

/// One mascot playing a mood. `MascotDirector` picks the drawn clips here;
/// hops, sway, the pose-change pop and the hover lean are Core Animation
/// animations in `MascotLayerView`, so the window server plays them at the
/// display's refresh rate and the app only wakes to swap a drawn frame.
@MainActor
struct ClockinMotionMascot: View {
    let mood: MascotMood
    /// Changing this plays a reaction hop.
    var reaction = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var frame: String?
    @State private var hop = MascotLayerView.HopRequest(id: 0, height: 1)
    @State private var hopUntil = Date.distantPast
    @State private var pop = 0
    @State private var lean = 0.0
    @State private var windowVisible = true

    private struct RunKey: Equatable {
        let mood: MascotMood
        let moving: Bool
    }

    private var moving: Bool { !reduceMotion && windowVisible }
    private var clips: MascotMoodClips? { MascotFrames.shared.library?[mood] }

    var body: some View {
        GeometryReader { geometry in
            MascotLayerRepresentable(
                image: (frame ?? clips?.rest).flatMap { MascotFrames.shared.image($0) },
                feet: mood.feet,
                swaying: moving && clips?.standing == true,
                hop: hop,
                pop: pop,
                lean: moving ? lean : 0,
                dark: colorScheme == .dark,
                visibilityChanged: { visible in if windowVisible != visible { windowVisible = visible } }
            )
            .onContinuousHover { phase in
                switch phase {
                case .active(let point): lean = max(-1, min(1, (point.x / max(1, geometry.size.width) - 0.5) * 2))
                case .ended: lean = 0
                }
            }
        }
        .accessibilityHidden(true)
        .task(id: RunKey(mood: mood, moving: moving)) { await run() }
        .onChange(of: mood) { _, _ in if moving { pop += 1 } }
        .onChange(of: reaction) { _, _ in if moving { startHop(height: 1.15) } }
    }

    private func startHop(height: Double) {
        // One hop at a time, like the site.
        guard Date() >= hopUntil else { return }
        hopUntil = Date().addingTimeInterval(MascotMotion.hopDuration(height: height))
        hop = MascotLayerView.HopRequest(id: hop.id + 1, height: height)
    }

    private func run() async {
        guard let clips else { return }
        frame = clips.rest
        guard moving else { return }
        await MascotFrames.shared.preload(mood)
        var director = MascotDirector(clips)
        var random = SystemRandomNumberGenerator()
        while !Task.isCancelled {
            if let base = clips.base {
                await play(base)
            } else {
                do { try await Task.sleep(for: .seconds(director.restDelay(using: &random))) } catch { return }
            }
            if Task.isCancelled || director.skipsEvent(using: &random) { continue }
            switch director.next(using: &random) {
            case .hop(let height):
                startHop(height: height)
                do { try await Task.sleep(for: .seconds(MascotMotion.hopDuration(height: height))) } catch { return }
            case .clip(let name):
                if let steps = clips.clips[name] { await play(steps) }
            case nil:
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
            }
        }
    }

    private func play(_ steps: [MascotStep]) async {
        for step in steps {
            guard !Task.isCancelled else { return }
            frame = step.frame
            guard step.milliseconds > 0 else { continue }
            do { try await Task.sleep(for: .milliseconds(step.milliseconds)) } catch { return }
        }
    }
}

private struct MascotLayerRepresentable: NSViewRepresentable {
    let image: CGImage?
    let feet: Double
    let swaying: Bool
    let hop: MascotLayerView.HopRequest
    let pop: Int
    let lean: Double
    let dark: Bool
    let visibilityChanged: (Bool) -> Void

    func makeNSView(context: Context) -> MascotLayerView {
        let view = MascotLayerView()
        updateNSView(view, context: context)
        return view
    }

    func updateNSView(_ view: MascotLayerView, context: Context) {
        view.visibilityChanged = visibilityChanged
        view.update(image: image, feet: feet, swaying: swaying, hop: hop, pop: pop, lean: lean, dark: dark)
    }
}

/// The mascot's layers, like the site's rig: lean > shadow + sway > pop > body.
/// Every transform pivots on the feet.
final class MascotLayerView: NSView {
    struct HopRequest: Equatable {
        let id: Int
        let height: Double
    }

    var visibilityChanged: ((Bool) -> Void)?

    private let rig = CALayer()
    private let shadowLayer = CAGradientLayer()
    private let sway = CALayer()
    private let popLayer = CALayer()
    private let body = CALayer()
    private var feet = 0.88
    private var swaying = false
    private var lastHop: HopRequest?
    private var lastPop = 0
    private var lean = 0.0
    private var dark: Bool?
    /// The sway is built in points, so it is rebuilt when the size changes.
    private var swaySide: CGFloat = 0
    private var visibleObservation: NSKeyValueObservation?
    private var observers: [NSObjectProtocol] = []

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer = CALayer()
        layer?.masksToBounds = false
        body.contentsGravity = .resizeAspect
        body.minificationFilter = .trilinear
        body.magnificationFilter = .linear
        shadowLayer.type = .radial
        shadowLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        shadowLayer.endPoint = CGPoint(x: 1, y: 1)
        popLayer.addSublayer(body)
        sway.addSublayer(popLayer)
        rig.addSublayer(shadowLayer)
        rig.addSublayer(sway)
        layer?.addSublayer(rig)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isFlipped: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    /// The body's current on-screen transform, for checks.
    var presentedBodyTransform: CATransform3D { (body.presentation() ?? body).transform }
    var presentedSwayTransform: CATransform3D { (sway.presentation() ?? sway).transform }
    var bodyContents: CGImage? { body.contents.map { $0 as! CGImage } }

    func update(image: CGImage?, feet: Double, swaying: Bool, hop: HopRequest, pop: Int, lean: Double, dark: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if (body.contents as! CGImage?) !== image { body.contents = image }
        if self.feet != feet {
            self.feet = feet
            needsLayout = true
        }
        if self.dark != dark {
            self.dark = dark
            let tint = dark ? NSColor.black.withAlphaComponent(0.55) : NSColor(red: 23 / 255, green: 34 / 255, blue: 55 / 255, alpha: 0.24)
            shadowLayer.colors = [tint.cgColor, tint.withAlphaComponent(0).cgColor]
        }
        CATransaction.commit()

        if self.swaying != swaying {
            self.swaying = swaying
            swaying ? startSway() : stopSway()
        }
        if lastHop == nil {
            lastHop = hop
        } else if lastHop != hop {
            lastHop = hop
            playHop(height: hop.height)
        }
        if pop != lastPop {
            lastPop = pop
            playPop()
        }
        if self.lean != lean {
            self.lean = lean
            let spring = CASpringAnimation(keyPath: "transform")
            spring.fromValue = NSValue(caTransform3D: (rig.presentation() ?? rig).transform)
            spring.toValue = NSValue(caTransform3D: leanTransform(lean))
            spring.damping = 18
            spring.stiffness = 170
            spring.duration = spring.settlingDuration
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            rig.transform = leanTransform(lean)
            rig.add(spring, forKey: "lean")
            CATransaction.commit()
        }
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let side = min(bounds.width, bounds.height)
        let square = CGRect(x: (bounds.width - side) / 2, y: (bounds.height - side) / 2, width: side, height: side)
        // Layers use a bottom-left origin: the feet sit at 1 - feet from the bottom.
        let anchor = CGPoint(x: 0.5, y: 1 - feet)
        for layer in [rig, sway, popLayer] {
            layer.anchorPoint = anchor
            layer.bounds = CGRect(origin: .zero, size: square.size)
            layer.position = CGPoint(x: square.midX - square.minX, y: square.height * anchor.y)
        }
        rig.position = CGPoint(x: square.midX, y: square.minY + square.height * anchor.y)
        body.anchorPoint = anchor
        body.bounds = CGRect(origin: .zero, size: square.size)
        body.position = CGPoint(x: square.width / 2, y: square.height * anchor.y)
        shadowLayer.bounds = CGRect(x: 0, y: 0, width: side * 0.38, height: side * 0.04)
        shadowLayer.position = CGPoint(x: square.width / 2, y: square.height * anchor.y)
        CATransaction.commit()
        if swaying, side != swaySide { startSway() }
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        let scale = window?.backingScaleFactor ?? 2
        [rig, shadowLayer, sway, popLayer, body].forEach { $0.contentsScale = scale }
    }

    private func leanTransform(_ lean: Double) -> CATransform3D {
        let side = min(bounds.width, bounds.height)
        return CATransform3DRotate(CATransform3DMakeTranslation(lean * 0.016 * side, 0, 0), -lean * 3 * .pi / 180, 0, 0, 1)
    }

    private func startSway() {
        let side = min(bounds.width, bounds.height)
        swaySide = side
        // Laid out later; `layout()` starts it once the size is known.
        guard side > 0 else { return }
        let animation = CAKeyframeAnimation(keyPath: "transform")
        // Layers are y-up: the site's upward offset is positive here, and a
        // clockwise CSS rotation is negative.
        animation.values = MascotMotion.samples(count: 61) { progress in
            let pose = MascotMotion.sway(time: progress * MascotMotion.swayPeriod)
            return NSValue(caTransform3D: CATransform3DRotate(CATransform3DMakeTranslation(0, -pose.offsetY * side, 0),
                                                              -pose.rotationDegrees * .pi / 180, 0, 0, 1))
        }
        animation.duration = MascotMotion.swayPeriod
        animation.repeatCount = .infinity
        animation.calculationMode = .linear
        animation.beginTime = CACurrentMediaTime()
        sway.add(animation, forKey: "sway")
    }

    private func stopSway() {
        // Ease back to rest from wherever the sway is, instead of snapping.
        let from = (sway.presentation() ?? sway).transform
        sway.removeAnimation(forKey: "sway")
        let settle = CABasicAnimation(keyPath: "transform")
        settle.fromValue = NSValue(caTransform3D: from)
        settle.toValue = NSValue(caTransform3D: CATransform3DIdentity)
        settle.duration = 0.52
        settle.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 1, 0.36, 1)
        sway.add(settle, forKey: "settle")
    }

    private func playHop(height: Double) {
        let side = min(bounds.width, bounds.height)
        let duration = MascotMotion.hopDuration(height: height)
        let count = max(2, Int(duration * 120))
        let poses = MascotMotion.samples(count: count) { MascotMotion.hop(progress: $0, height: height) }
        let bodyAnimation = CAKeyframeAnimation(keyPath: "transform")
        bodyAnimation.values = poses.map { pose in
            NSValue(caTransform3D: CATransform3DScale(CATransform3DMakeTranslation(0, -pose.offsetY * side, 0), pose.scaleX, pose.scaleY, 1))
        }
        bodyAnimation.duration = duration
        body.add(bodyAnimation, forKey: "hop")
        let shadowAnimation = CAKeyframeAnimation(keyPath: "transform")
        shadowAnimation.values = poses.map { NSValue(caTransform3D: CATransform3DMakeScale($0.shadowScaleX, $0.shadowScaleY, 1)) }
        shadowAnimation.duration = duration
        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = poses.map { NSNumber(value: $0.shadowOpacity) }
        fade.duration = duration
        shadowLayer.add(shadowAnimation, forKey: "hop")
        shadowLayer.add(fade, forKey: "hopFade")
    }

    private func playPop() {
        let animation = CAKeyframeAnimation(keyPath: "transform")
        animation.values = MascotMotion.samples(count: 40) { progress in
            let scale = MascotMotion.pop(progress: progress)
            return NSValue(caTransform3D: CATransform3DMakeScale(scale, scale, 1))
        }
        animation.duration = MascotMotion.popDuration
        popLayer.add(animation, forKey: "pop")
    }

    // MARK: Visibility

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        visibleObservation = nil
        viewDidChangeBackingProperties()
        guard let window else { return report(false) }
        // `orderOut` posts no notification, but `isVisible` is observable. The
        // window's own state is used rather than `occlusionState`, which can
        // report a shown window as hidden and would freeze the mascot.
        visibleObservation = window.observe(\.isVisible) { [weak self] _, _ in
            DispatchQueue.main.async { self?.reportCurrent() }
        }
        for name in [NSWindow.didMiniaturizeNotification, NSWindow.didDeminiaturizeNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.reportCurrent() }
            })
        }
        reportCurrent()
    }

    private func reportCurrent() {
        report(window.map { $0.isVisible && !$0.isMiniaturized } ?? false)
    }

    private func report(_ visible: Bool) {
        // Outside the SwiftUI update that moved this view.
        DispatchQueue.main.async { [weak self] in self?.visibilityChanged?(visible) }
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
