import Foundation

/// Yeni surum var mi diye GitHub'a sorar.
///
/// Proje yayinlanmis bir surum (release) uretmiyor; herkes kaynaktan
/// derliyor. Dolayisiyla "indirilecek paket" yok. Bunun yerine derleme
/// sirasinda paketin icine hangi commit'ten uretildigi yazilir ve burada
/// deponun son haliyle karsilastirilir.
@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    enum State: Equatable {
        /// Paket bir commit bilgisi tasimiyor (elle yapilmis derleme).
        case unknown
        case checking
        case upToDate
        case behind(Int)
        case failed(String)
    }

    @Published private(set) var state: State = .unknown
    @Published private(set) var lastChecked: Date?

    private static let repository = "ismailakdag/clockin"
    /// Iki otomatik denetim arasindaki en kisa sure.
    private static let automaticInterval: TimeInterval = 6 * 3600

    /// build-app.sh tarafindan Info.plist'e yazilir.
    let builtCommit: String? = {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "ClockinBuildCommit") as? String,
              !value.isEmpty, value != "unknown" else { return nil }
        return value
    }()

    /// Guncelleme betiginin yolu; yine derleme sirasinda yazilir.
    let updateScriptPath: String? = {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "ClockinUpdateScript") as? String,
              !value.isEmpty, FileManager.default.fileExists(atPath: value) else { return nil }
        return value
    }()

    /// Karsilastirma icin kullanilan nokta: derlemenin origin/main ile ortak
    /// atasi. Yerel commitler tasiyan bir derlemede HEAD depoda bulunmaz.
    let upstreamBase: String? = {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "ClockinUpstreamBase") as? String,
              !value.isEmpty, value != "unknown" else { return nil }
        return value
    }()

    var shortCommit: String? { builtCommit.map { String($0.prefix(7)) } }

    func checkIfDue() async {
        if let last = lastChecked, Date().timeIntervalSince(last) < Self.automaticInterval { return }
        await check()
    }

    func check() async {
        guard let base = upstreamBase ?? builtCommit else {
            state = .unknown
            return
        }
        state = .checking
        let url = URL(string: "https://api.github.com/repos/\(Self.repository)/compare/\(base)...main")!
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                state = .failed("No response")
                return
            }
            // Derleme, deponun gecmisinde olmayan bir commit'ten yapilmis
            // olabilir (yerel deneme dali gibi).
            guard http.statusCode != 404 else {
                state = .unknown
                return
            }
            guard http.statusCode == 200 else {
                state = .failed("GitHub returned \(http.statusCode)")
                return
            }
            let parsed = try JSONDecoder().decode(Comparison.self, from: data)
            lastChecked = Date()
            state = parsed.ahead_by > 0 ? .behind(parsed.ahead_by) : .upToDate
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Guncelleme betigini calistirir. Betik uygulamayi kapatip yeniden
    /// kurdugu icin burada beklemek anlamsiz.
    func runUpdateScript() -> Bool {
        guard let updateScriptPath else { return false }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [updateScriptPath]
        do {
            try process.run()
            return true
        } catch {
            state = .failed(error.localizedDescription)
            return false
        }
    }

    private struct Comparison: Decodable {
        let ahead_by: Int
    }
}
