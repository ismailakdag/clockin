import AppKit
import SwiftUI
import Combine

struct ClockinMascotImage: View {
    @AppStorage(UIScale.key) private var uiScaleObserver = 1.0
    let asset: String
    var body: some View {
        Group {
            if let url = Bundle.module.url(forResource: asset, withExtension: "png"), let image = NSImage(contentsOf: url) {
                Image(nsImage: image).resizable().interpolation(.none).scaledToFit()
            } else {
                Image(systemName: "sparkles").resizable().scaledToFit().padding(S(18)).foregroundStyle(.cyan)
            }
        }
    }
}

struct ClockinTypingMascot: View {
    var body: some View { ClockinFrameMascot(prefix: "frame", interval: 0.18) }
}

struct ClockinCoffeeMascot: View {
    var body: some View { ClockinFrameMascot(prefix: "coffee", interval: 0.28) }
}

struct ClockinMascotEffects: View {
    @State private var effect = Int.random(in: 0...4)
    @State private var animate = false
    private let timer = Timer.publish(every: 8, on: .main, in: .common).autoconnect()
    var body: some View {
        ZStack {
            switch effect {
            case 0: Text("$  $  $").font(.system(size: S(10), weight: .black, design: .rounded)).foregroundStyle(.green).offset(x: 13, y: animate ? 27 : -24).opacity(animate ? 0 : 1)
            case 1: Text("✦  ✧  ✦").font(.system(size: S(12), weight: .bold)).foregroundStyle(.orange).scaleEffect(animate ? 1.25 : 0.7).opacity(animate ? 0.2 : 1)
            case 2: Text("♪  ♫  ♪").font(.system(size: S(12), weight: .bold)).foregroundStyle(.cyan).offset(x: animate ? 18 : -8, y: animate ? -20 : 8).opacity(animate ? 0 : 1)
            case 3: Text("✹  ✹").font(.system(size: S(11), weight: .bold)).foregroundStyle(.yellow).rotationEffect(.degrees(animate ? 35 : -15)).opacity(animate ? 0.2 : 1)
            default: Text("+XP").font(.system(size: S(10), weight: .black, design: .monospaced)).foregroundStyle(.green).offset(y: animate ? -25 : 2).opacity(animate ? 0 : 1)
            }
        }
        .animation(.easeOut(duration: 1.6), value: animate)
        .onAppear { animate = true }
        .onReceive(timer) { _ in
            effect = Int.random(in: 0...4)
            animate = false
            withAnimation(.easeOut(duration: 1.6)) { animate = true }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            effect = Int.random(in: 0...4)
            animate = false
            withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) { animate = true }
        }
    }
}

struct ClockinMascotStage: View {
    @EnvironmentObject private var store: ClockStore
    @AppStorage("Clockin.MascotDefault") private var defaultMode = "Auto"
    @State private var pose: Int?
    @State private var poseToken = UUID()
    var body: some View {
        ZStack {
            if let pose { ClockinPoseMascot(index: pose) }
            else if defaultMode == "Typing" { ClockinTypingMascot() }
            else if defaultMode == "Coffee" { ClockinCoffeeMascot() }
            else if let fixed = ["Victory", "Stretch", "Dance", "Music"].firstIndex(of: defaultMode) { ClockinPoseMascot(index: fixed + 1) }
            else if store.running?.isPaused == false { ClockinTypingMascot() }
            else if store.running?.isPaused == true { ClockinCoffeeMascot() }
            else { ClockinMascotImage(asset: "idle") }
            ClockinMascotEffects()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            let token = UUID(); poseToken = token; pose = Int.random(in: 1...4)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { if poseToken == token { pose = nil } }
        }
    }
}

private struct ClockinPoseMascot: View {
    let index: Int
    @State private var moving = false
    var body: some View {
        Group {
            if let url = Bundle.module.url(forResource: "pose\(index)", withExtension: "png"), let image = NSImage(contentsOf: url) {
                Image(nsImage: image).resizable().interpolation(.none).scaledToFit()
            } else { Image(systemName: "sparkles") }
        }
        .scaleEffect(moving ? (index == 3 ? 1.05 : 0.98) : 1)
        .offset(x: moving && index == 3 ? 5 : 0, y: moving ? -2 : 2)
        .rotationEffect(.degrees(moving && index == 2 ? 5 : (moving && index == 4 ? -4 : 0)))
        .animation(.easeInOut(duration: index == 3 ? 0.28 : 0.7).repeatForever(autoreverses: true), value: moving)
        .onAppear { moving = true }
    }
}

private struct ClockinFrameMascot: View {
    let prefix: String
    let interval: Double
    @State private var frame = 1
    private var timer: Publishers.Autoconnect<Timer.TimerPublisher> { Timer.publish(every: interval, on: .main, in: .common).autoconnect() }
    var body: some View {
        Group {
            if let url = Bundle.module.url(forResource: "\(prefix)\(frame)", withExtension: "png"), let image = NSImage(contentsOf: url) {
                Image(nsImage: image).resizable().interpolation(.none).scaledToFit()
            } else { Image(systemName: "keyboard") }
        }
        .onReceive(timer) { _ in frame = frame % 4 + 1 }
    }
}
