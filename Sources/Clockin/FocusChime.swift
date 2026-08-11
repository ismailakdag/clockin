import AppKit
import Foundation

@MainActor
final class FocusChimeController: NSObject {
    static let shared = FocusChimeController()
    static let availableSounds = ["Glass", "Ping", "Pop", "Tink", "Funk", "Submarine", "Sosumi"]
    private weak var store: ClockStore?
    private var timer: Timer?
    private var activeSound: NSSound?
    private var trackedStart: Date?
    private var lastBucket = 0

    func start(store: ClockStore) {
        self.store = store
        resetBaseline()
        timer?.invalidate()
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        RunLoop.main.add(timer!, forMode: .common)
    }

    func settingChanged() {
        resetBaseline()
    }

    func remaining(store: ClockStore, at date: Date = .now) -> TimeInterval? {
        guard UserDefaults.standard.bool(forKey: "Clockin.ChimeEnabled"),
              let running = store.running, !running.isPaused else { return nil }
        let elapsed = max(0, Int(store.elapsed(at: date)))
        let interval = intervalSeconds
        let remainder = interval - (elapsed % interval)
        return TimeInterval(remainder == 0 ? interval : remainder)
    }

    func playPreview() {
        let name = UserDefaults.standard.string(forKey: "Clockin.ChimeSound") ?? "Glass"
        let storedVolume = UserDefaults.standard.object(forKey: "Clockin.ChimeVolume") as? Double
        let volume = Float(min(1, max(0.1, storedVolume ?? 0.75)))
        activeSound?.stop()
        if let sound = NSSound(named: NSSound.Name(name)) {
            sound.volume = volume
            activeSound = sound
            sound.play()
        } else {
            NSSound.beep()
        }
    }

    private func resetBaseline() {
        trackedStart = store?.running?.start
        lastBucket = Int(store?.elapsed() ?? 0) / intervalSeconds
    }

    @objc private func tick() {
        guard UserDefaults.standard.bool(forKey: "Clockin.ChimeEnabled"),
              let store, let running = store.running else { return }
        if trackedStart != running.start {
            resetBaseline()
            return
        }
        guard !running.isPaused else { return }
        let bucket = Int(store.elapsed()) / intervalSeconds
        if bucket > lastBucket, bucket > 0 {
            lastBucket = bucket
            playPreview()
        }
    }

    private var intervalSeconds: Int {
        let stored = UserDefaults.standard.integer(forKey: "Clockin.ChimeIntervalMinutes")
        return max(1, stored == 0 ? 10 : stored) * 60
    }
}
