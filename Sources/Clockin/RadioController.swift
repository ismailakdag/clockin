import AVFoundation
import Foundation

@MainActor
final class RadioController: ObservableObject {
    static let shared = RadioController()
    @Published private(set) var isPlaying = false
    @Published var volume: Double = 0.7 { didSet { player?.volume = Float(volume) } }
    @Published private(set) var errorMessage: String?
    private var player: AVPlayer?
    private var monitor: Task<Void, Never>?

    struct Station: Identifiable, Hashable {
        let id: String
        let name: String
        let language: String
        let description: String
        let url: URL
    }
    let stations: [Station] = [
        Station(id: "rp", name: "Radio Paradise", language: "EN", description: "Eclectic, listener-supported, commercial-free", url: URL(string: "https://stream.radioparadise.com/aac-320")!),
        Station(id: "rp-mellow", name: "Mellow Mix", language: "EN", description: "Relaxed and mellow music", url: URL(string: "https://stream.radioparadise.com/mellow-320")!),
        Station(id: "rp-global", name: "Global Mix", language: "EN", description: "Music from around the world", url: URL(string: "https://stream.radioparadise.com/global-320")!),
        Station(id: "rp-serenity", name: "Serenity", language: "EN", description: "Ambient music for quiet focus", url: URL(string: "https://stream.radioparadise.com/serenity")!),
    ]

    func toggle(station: Station) {
        if isPlaying { stop() } else { play(station: station) }
    }

    /// `isPlaying` calmasi istenen radyo demektir; akis gelmezse kapanir.
    /// Onceden `play()` cagrilir cagrilmaz acik sayiliyordu ve olu bir akis
    /// sessizce "acik" gorunmeye devam ediyordu.
    func play(station: Station) {
        stop()
        errorMessage = nil
        let player = AVPlayer(url: station.url)
        player.volume = Float(volume)
        self.player = player
        player.play()
        isPlaying = true
        monitor = Task { [weak self] in
            var waitingSince = ContinuousClock.now
            while !Task.isCancelled {
                guard let self, let player = self.player else { return }
                if player.currentItem?.status == .failed || player.error != nil {
                    self.fail("\(station.name) is unreachable. Check your connection and try again.")
                    return
                }
                if player.timeControlStatus == .playing {
                    waitingSince = .now
                } else if waitingSince.duration(to: .now) >= .seconds(30) {
                    self.fail("\(station.name) did not respond. Check your connection and try again.")
                    return
                }
                do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
            }
        }
    }

    func stop() {
        monitor?.cancel()
        monitor = nil
        player?.pause()
        player = nil
        isPlaying = false
    }

    private func fail(_ message: String) {
        stop()
        errorMessage = message
    }
}
