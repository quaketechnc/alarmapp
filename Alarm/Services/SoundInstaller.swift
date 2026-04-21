import Foundation
import os

private let log = Logger(subsystem: "com.alarm", category: "sound-installer")

/// Copies alarm tone files into Library/Sounds so AlarmKit can reference them via .named().
/// Must be called once at app launch before any alarm is scheduled.
enum SoundInstaller {

    static let soundsDir: URL = {
        FileManager.default
            .urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Sounds", isDirectory: true)
    }()

    // Known system paths where iOS stores alarm/ringtone CAF files.
    private static let systemRoots = [
        "/System/Library/Audio/UISounds/New",
        "/System/Library/Audio/UISounds",
        "/System/Library/Ringtones",
        "/Library/Ringtones",
    ]

    static func installIfNeeded() {
        let fm = FileManager.default
        try? fm.createDirectory(at: soundsDir, withIntermediateDirectories: true)

        for tone in allTones {
            let dest = soundsDir.appendingPathComponent("\(tone.systemSoundName).caf")
            guard !fm.fileExists(atPath: dest.path) else {
                log.debug("✓ already installed: \(tone.systemSoundName)")
                continue
            }
            if let src = findSource(for: tone) {
                do {
                    try fm.copyItem(at: src, to: dest)
                    log.info("✓ installed '\(tone.systemSoundName)' from \(src.path)")
                } catch {
                    log.error("✗ copy failed '\(tone.systemSoundName)': \(error)")
                }
            } else {
                log.warning("⚠ source not found for '\(tone.systemSoundName)' — alarm will use default sound")
            }
        }
    }

    private static func findSource(for tone: AlarmTone) -> URL? {
        let extensions = ["caf", "m4r", "aiff", "mp3"]
        for root in systemRoots {
            for ext in extensions {
                let url = URL(fileURLWithPath: "\(root)/\(tone.systemSoundName).\(ext)")
                if FileManager.default.fileExists(atPath: url.path) { return url }
            }
        }
        // Also check app bundle (user can drop their own files there).
        for ext in extensions {
            if let url = Bundle.main.url(forResource: tone.systemSoundName, withExtension: ext) {
                return url
            }
        }
        return nil
    }
}
