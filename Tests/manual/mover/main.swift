import Foundation

var checks = 0
@MainActor func check(_ condition: Bool, _ name: String) {
    guard condition else { print("FAILED: \(name)"); exit(1) }
    checks += 1
    print("ok: \(name)")
}

// Keep Trash operations inside the fixture and exercise volumes without Trash.
final class TestFileManager: FileManager, @unchecked Sendable {
    // FileManager is Sendable; this subclass adds only immutable configuration.
    let supportsTrash: Bool
    let failsRename: Bool
    let trashURL: URL

    init(trashURL: URL, supportsTrash: Bool = false, failsRename: Bool = false) {
        self.trashURL = trashURL
        self.supportsTrash = supportsTrash
        self.failsRename = failsRename
        super.init()
    }

    override func trashItem(at url: URL, resultingItemURL outResultingURL: AutoreleasingUnsafeMutablePointer<NSURL?>?) throws {
        guard supportsTrash else { throw CocoaError(.fileWriteUnsupportedScheme) }
        try super.moveItem(at: url, to: trashURL)
        outResultingURL?.pointee = trashURL as NSURL
    }

    override func moveItem(at srcURL: URL, to dstURL: URL) throws {
        if failsRename && srcURL.lastPathComponent.hasPrefix(".clockin-install-") {
            throw CocoaError(.fileWriteNoPermission)
        }
        try super.moveItem(at: srcURL, to: dstURL)
    }
}

func quarantine(_ url: URL) throws {
    let value = Array("0083;00000000;ClockinMoverTests;".utf8)
    let result = value.withUnsafeBytes { bytes in
        url.withUnsafeFileSystemRepresentation { path in
            guard let path else { return Int32(-1) }
            return setxattr(path, "com.apple.quarantine", bytes.baseAddress, bytes.count, 0, XATTR_NOFOLLOW)
        }
    }
    guard result == 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
}

func hasQuarantine(_ url: URL) -> Bool {
    url.withUnsafeFileSystemRepresentation { path in
        guard let path else { return false }
        return getxattr(path, "com.apple.quarantine", nil, 0, 0, XATTR_NOFOLLOW) >= 0
    }
}

do {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent("clockin-mover-\(UUID().uuidString)")
        .resolvingSymlinksInPath()
    try fm.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: root) }
    let applications = root.appendingPathComponent("Applications")
    let userApplications = root.appendingPathComponent("User/Applications")
    let downloads = root.appendingPathComponent("Downloads/Fake.app")
    let mounted = root.appendingPathComponent("Volume")
    let translocated = root.appendingPathComponent("AppTranslocation/random/d/Fake.app")
    let base = ApplicationMover.Environment(
        applicationsDirectories: [applications, userApplications],
        translocatedOriginal: { _ in nil },
        isReadOnlyVolume: { $0.pathComponents.starts(with: mounted.pathComponents) },
        volumeURL: { _ in mounted },
        isDevelopmentBuild: { _ in false }
    )
    func locate(_ path: URL) -> ApplicationLocation { ApplicationMover.locate(path, environment: base) }
    check(locate(applications.appendingPathComponent("Fake.app")).kind == .installed, "installed")
    check(locate(applications.appendingPathComponent("Tools/Fake.app")).kind == .installed, "nested installed")
    check(locate(userApplications.appendingPathComponent("Fake.app")).kind == .installed, "user Applications")
    check(locate(root.appendingPathComponent("ApplicationsX/Fake.app")).kind == .elsewhere, "component prefix")
    check(locate(downloads).kind == .elsewhere, "elsewhere")
    check(locate(downloads).originalURL == downloads && locate(downloads).volumeURL == nil, "ordinary location URLs")
    let readOnly = locate(mounted.appendingPathComponent("Fake.app"))
    check(readOnly.kind == .readOnlyVolume && readOnly.volumeURL == mounted, "read-only volume")
    for (original, expected) in [(downloads, ApplicationLocation.Kind.translocated),
                                 (applications.appendingPathComponent("Fake.app"), .installed),
                                 (mounted.appendingPathComponent("Fake.app"), .readOnlyVolume)] {
        var environment = base
        environment.translocatedOriginal = { _ in original }
        let result = ApplicationMover.locate(translocated, environment: environment)
        check(result.kind == expected && result.originalURL == original && result.bundleURL == translocated,
              "translocation original: \(expected)")
        check(result.volumeURL == (expected == .readOnlyVolume ? mounted : nil), "translocation volume: \(expected)")
    }
    check(locate(root.appendingPathComponent("dist/Fake.app")).kind == .development, "dist development")
    check(locate(root.appendingPathComponent(".build/debug/Fake.app")).kind == .development, ".build development")
    var development = base
    development.isDevelopmentBuild = { _ in true }
    development.translocatedOriginal = { _ in downloads }
    check(ApplicationMover.locate(translocated, environment: development).kind == .development, "development closure has priority")
    for kind in [ApplicationLocation.Kind.installed, .readOnlyVolume, .translocated, .elsewhere, .development] {
        let location = ApplicationLocation(kind: kind, bundleURL: downloads, originalURL: downloads, volumeURL: nil)
        check(location.shouldOfferMove == [.readOnlyVolume, .translocated, .elsewhere].contains(kind), "offer: \(kind)")
    }
    try fm.createDirectory(at: applications, withIntermediateDirectories: true)
    let alias = root.appendingPathComponent("AppsAlias")
    try fm.createSymbolicLink(at: alias, withDestinationURL: applications)
    check(locate(alias.appendingPathComponent("Fake.app")).kind == .installed, "symlink Applications")
    check(locate(applications.appendingPathComponent("Tools/../Fake.app")).kind == .installed, "standardized path")
    check(try ApplicationMover.destinationDirectory(environment: base) == applications, "writable system destination")
    var fallback = base
    fallback.applicationsDirectories = [root.appendingPathComponent("Missing"), userApplications]
    check(try ApplicationMover.destinationDirectory(environment: fallback) == userApplications,
          "create user destination when system unavailable")

    let source = downloads
    let nested = source.appendingPathComponent("Contents/Resources/value.txt")
    try fm.createDirectory(at: nested.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("new app".utf8).write(to: nested)
    check(ApplicationMover.Environment.live.translocatedOriginal(source) == nil, "Security recognizes ordinary fixture")
    check(ApplicationMover.Environment.live.isDevelopmentBuild(source), "Security recognizes unsigned fixture")
    let link = source.appendingPathComponent("Contents/link")
    try fm.createSymbolicLink(atPath: link.path, withDestinationPath: "Resources/value.txt")
    let external = root.appendingPathComponent("external.txt")
    try Data("outside".utf8).write(to: external)
    try quarantine(external)
    try fm.createSymbolicLink(at: source.appendingPathComponent("external-link"), withDestinationURL: external)
    try quarantine(source)
    try quarantine(nested.deletingLastPathComponent())
    try quarantine(nested)
    check(hasQuarantine(nested), "quarantine fixture is set")
    let trash = root.appendingPathComponent("TestTrash.app")
    let noTrash = TestFileManager(trashURL: trash)
    let installed = try ApplicationMover.install(source, into: applications, fileManager: noTrash)
    let installedFile = installed.appendingPathComponent("Contents/Resources/value.txt")
    check(installed.path == applications.appendingPathComponent("Fake.app").path, "fresh install URL")
    check(try String(contentsOf: installedFile, encoding: .utf8) == "new app", "fresh install contents")
    check(!hasQuarantine(installed) && !hasQuarantine(installedFile) && !hasQuarantine(installedFile.deletingLastPathComponent()),
          "recursive quarantine removal")
    check(hasQuarantine(nested) && hasQuarantine(external), "source and external symlink target untouched")
    check(try fm.destinationOfSymbolicLink(atPath: installed.appendingPathComponent("Contents/link").path) == "Resources/value.txt",
          "symlink preserved")
    let oldMarker = installed.appendingPathComponent("old.txt")
    try Data("old".utf8).write(to: oldMarker)
    _ = try ApplicationMover.install(source, into: applications, fileManager: noTrash)
    let replacementContents = try String(contentsOf: installedFile, encoding: .utf8)
    check(!fm.fileExists(atPath: oldMarker.path) && replacementContents == "new app",
          "replace without Trash")
    try Data("old".utf8).write(to: oldMarker)
    _ = try ApplicationMover.install(source, into: applications,
                                     fileManager: TestFileManager(trashURL: trash, supportsTrash: true))
    check(fm.fileExists(atPath: trash.appendingPathComponent("old.txt").path) && !fm.fileExists(atPath: oldMarker.path),
          "replace with simulated Trash")
    do {
        _ = try ApplicationMover.install(installed, into: applications, fileManager: noTrash)
        check(false, "self install must throw")
    } catch { check(fm.fileExists(atPath: installedFile.path), "self install leaves bundle intact") }
    try Data("rollback marker".utf8).write(to: oldMarker)
    do {
        _ = try ApplicationMover.install(source, into: applications,
                                         fileManager: TestFileManager(trashURL: trash, failsRename: true))
        check(false, "failed rename must throw")
    } catch {
        check(try String(contentsOf: oldMarker, encoding: .utf8) == "rollback marker", "failed rename restores existing app")
    }
    try fm.setAttributes([.posixPermissions: 0], ofItemAtPath: nested.path)
    defer { try? fm.setAttributes([.posixPermissions: 0o644], ofItemAtPath: nested.path) }
    do {
        _ = try ApplicationMover.install(source, into: applications, fileManager: noTrash)
        check(false, "unreadable source must fail")
    } catch {
        check(try String(contentsOf: installedFile, encoding: .utf8) == "new app", "failed copy preserves existing app")
        check(try String(contentsOf: oldMarker, encoding: .utf8) == "rollback marker", "failed copy preserves old-only file")
        check(try fm.contentsOfDirectory(atPath: applications.path) == ["Fake.app"], "no temporary copies after failures")
    }
    print("\(checks) mover checks passed")
} catch {
    print("FAILED: \(error.localizedDescription)")
    exit(1)
}
