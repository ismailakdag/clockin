import AVFoundation
import Foundation

@MainActor
final class RadioController: ObservableObject {
    static let shared = RadioController()
    @Published private(set) var isPlaying = false
    @Published var volume: Double = 0.7 { didSet { player?.volume = Float(volume) } }
    @Published private(set) var errorMessage: String?
    private var player: AVPlayer?

    struct Station: Identifiable, Hashable {
        let id: String
        let name: String
        let language: String
        let description: String
        let url: URL
    }
    let stations: [Station] = [
        Station(id: "rp", name: "Radio Paradise", language: "EN", description: "Eclectic, listener-supported, commercial-free", url: URL(string: "https://stream.radioparadise.com/aac-320")!),
    ]

    func toggle(station: Station) {
        if isPlaying { stop() } else { play(station: station) }
    }

    func play(station: Station) {
        errorMessage = nil
        player?.pause()
        player = AVPlayer(url: station.url)
        player?.volume = Float(volume)
        player?.play()
        isPlaying = true
    }

    func play(url: URL) {
        errorMessage = nil
        player?.pause()
        player = AVPlayer(url: url)
        player?.volume = Float(volume)
        player?.play()
        isPlaying = true
    }

    func stop() {
        player?.pause()
        player = nil
        isPlaying = false
    }
}
