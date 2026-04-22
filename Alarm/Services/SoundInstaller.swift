import Foundation
import os

private let log = Logger(subsystem: "com.alarm", category: "sound-installer")

/// Copies bundled alarm tones into `Library/Sounds/` so AlarmKit can reference
/// them via `.named(_:)`. Must run once at app launch before any alarm is
/// scheduled. Idempotent — skips files already installed.
enum SoundInstaller {

    static let soundsDir: URL = {
        FileManager.default
            .urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Sounds", isDirectory: true)
    }()

    static func installIfNeeded() {
        let fm = FileManager.default
        try? fm.createDirectory(at: soundsDir, withIntermediateDirectories: true)

        var installed = 0, skipped = 0, failed = 0
        for tone in allTones {
            let dest = soundsDir.appendingPathComponent(tone.fileName)
            if fm.fileExists(atPath: dest.path) { skipped += 1; continue }
            guard let src = tone.bundleURL else {
                log.warning("⚠ missing bundle resource for '\(tone.fileName)'")
                failed += 1
                continue
            }
            do {
                try fm.copyItem(at: src, to: dest)
                installed += 1
            } catch {
                log.error("✗ install '\(tone.fileName)' failed: \(error)")
                failed += 1
            }
        }
        log.info("🎵 sound install: \(installed) new, \(skipped) existing, \(failed) failed (total \(allTones.count))")
    }
}
