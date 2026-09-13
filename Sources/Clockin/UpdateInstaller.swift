import AppKit

/// "Update now" ile guncelleme betigini Terminal acmadan calistirir ve
/// ilerlemesini yayinlar.
///
/// Cikti bir boruya degil gunluk dosyasina yazilir. Kurulum adiminda uygulama
/// kapanir ve betik tek basina devam eder; boruya yazan bir surec okuyucusu
/// kapaninca SIGPIPE ile olurdu. Dosyaya yazmanin boyle bir riski yok ve
/// hata olursa tam gunluk yerinde kalir.
@MainActor
final class UpdateInstaller: ObservableObject {
    static let shared = UpdateInstaller()

    enum Phase: Equatable {
        case idle
        case running
        /// Betik kuruluma gecti; uygulama kendini kapatiyor.
        case installing
        case failed
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var progress = UpdateProgress()
    @Published private(set) var failureMessage: String?
    /// Ayrintilar icin son satirlar.
    @Published private(set) var recentLines: [String] = []

    let logURL = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: "Library/Logs/Clockin/update.log")

    private var scriptPath: String?
    private var exitStatus: Int32?
    private static let keptLines = 300

    var isActive: Bool { phase == .running || phase == .installing }

    func displayedFraction(at date: Date) -> Double {
        phase == .installing ? 1 : progress.fraction(at: date)
    }

    func start(scriptPath: String) {
        guard !isActive else { return }
        self.scriptPath = scriptPath
        progress = UpdateProgress(expected: Self.storedDurations())
        failureMessage = nil
        recentLines = []
        exitStatus = nil
        do {
            try FileManager.default.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
            let output = try FileHandle(forWritingTo: logURL)
            let input = try FileHandle(forReadingFrom: logURL)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = [scriptPath]
            process.environment = Self.environment()
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = output
            process.standardError = output
            process.terminationHandler = { finished in
                let status = finished.terminationStatus
                Task { @MainActor in UpdateInstaller.shared.exitStatus = status }
            }
            try process.run()
            // Surecin kendi kopyasi var; bizimki acik kalirsa bos yere durur.
            try? output.close()
            phase = .running
            Task { await follow(input) }
        } catch {
            fail("Couldn't start the update: \(error.localizedDescription)")
        }
    }

    func retry() {
        guard let scriptPath else { return }
        start(scriptPath: scriptPath)
    }

    func revealLog() {
        NSWorkspace.shared.open(logURL)
    }

    /// Gunluk dosyasini, surec bitene ve dosyanin sonuna gelinene kadar okur.
    private func follow(_ handle: FileHandle) async {
        var pending = Data()
        while true {
            // Once bak, sonra oku: surec bittikten sonra yapilan okuma son
            // yazdiklarini da kapsar.
            let exited = exitStatus != nil
            let chunk = (try? handle.read(upToCount: 64_000)) ?? nil
            if let chunk, !chunk.isEmpty {
                pending.append(chunk)
                consumeLines(from: &pending)
                continue
            }
            if exited { break }
            try? await Task.sleep(for: .milliseconds(150))
        }
        if !pending.isEmpty {
            consume(String(decoding: pending, as: UTF8.self))
        }
        try? handle.close()
        finish(status: exitStatus ?? 1)
    }

    private func consumeLines(from pending: inout Data) {
        while let newline = pending.firstIndex(of: UInt8(ascii: "\n")) {
            consume(String(decoding: pending[pending.startIndex..<newline], as: UTF8.self))
            pending.removeSubrange(pending.startIndex...newline)
        }
    }

    private func consume(_ line: String) {
        let previousStep = progress.step
        progress.consume(line, at: .now)
        if progress.step != previousStep {
            Self.storeDurations(progress.measured)
        }
        if !line.hasPrefix("::clockin-") {
            recentLines.append(line)
            if recentLines.count > Self.keptLines {
                recentLines.removeFirst(recentLines.count - Self.keptLines)
            }
        }
        if progress.step == .install, phase == .running {
            beginInstall()
        }
    }

    /// Betik uygulamanin kapanmasini bekliyor. Duzgun kapanmak, betigin
    /// sonunda zorla kapatmasindan iyi; pencere de "yeniden aciliyor"
    /// yazisini bir an gosterebiliyor.
    private func beginInstall() {
        phase = .installing
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            NSApp.terminate(nil)
        }
    }

    private func finish(status: Int32) {
        guard phase == .running else { return }
        if status == 0 {
            phase = .idle
            return
        }
        let stage = progress.step.map { "\($0.title) failed." } ?? "The update failed."
        fail(progress.errorMessage ?? stage)
    }

    private func fail(_ message: String) {
        failureMessage = message
        phase = .failed
    }

    private static let durationsKey = "Clockin.UpdateStepDurations"

    /// Bir sonraki guncellemenin cubugu bu surelere gore akar.
    private static func storedDurations() -> [UpdateProgress.Step: TimeInterval] {
        let stored = UserDefaults.standard.dictionary(forKey: durationsKey) as? [String: Double] ?? [:]
        return Dictionary(uniqueKeysWithValues: stored.compactMap { key, value in
            UpdateProgress.Step(rawValue: key).map { ($0, value) }
        })
    }

    private static func storeDurations(_ measured: [UpdateProgress.Step: TimeInterval]) {
        guard !measured.isEmpty else { return }
        var stored = UserDefaults.standard.dictionary(forKey: durationsKey) as? [String: Double] ?? [:]
        for (step, duration) in measured {
            stored[step.rawValue] = duration
        }
        UserDefaults.standard.set(stored, forKey: durationsKey)
    }

    private static func environment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        // Finder'dan acilan uygulamalarin PATH'i kisa; swift, git ve lipo
        // /usr/bin'de ama Homebrew araclari da bulunabilsin.
        environment["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin"
        environment["CLOCKIN_UPDATE_FROM_APP"] = "1"
        environment["CLOCKIN_APP_PID"] = String(ProcessInfo.processInfo.processIdentifier)
        // Git bir sey sorarsa cevaplayacak kimse yok; beklemek yerine hata versin.
        environment["GIT_TERMINAL_PROMPT"] = "0"
        return environment
    }
}
