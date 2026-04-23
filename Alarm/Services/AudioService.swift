import AVFoundation
import os
import Observation

private let log = Logger(subsystem: "com.alarm", category: "audio")

@Observable
final class AudioService {
    static let shared = AudioService()

    private(set) var isPlaying = false
    private(set) var currentToneID: String?

    @ObservationIgnored private var player: AVAudioPlayer?

    /// Plays the tone from the app bundle. `loops = -1` loops forever — use
    /// this for ringing. `loops = 0` plays once (preview).
    func play(toneID: String, volume: Double = 100, loops: Int = 0) {
        Task { await playAsync(toneID: toneID, volume: volume, loops: loops) }
    }

    func playAsync(toneID: String, volume: Double = 100, loops: Int = 0) async {
        let pid = ProcessInfo.processInfo.processIdentifier
        log.info("▶ play CALL pid=\(pid) toneID='\(toneID)' vol=\(Int(volume)) loops=\(loops)")

        let tone = allTones.first { $0.id == toneID }
            ?? allTones.first { $0.id == defaultAlarmToneID }
            ?? allTones.first
        guard let tone else { log.error("▶ no tones in bundle"); return }
        guard let url = tone.bundleURL else {
            log.error("▶ tone '\(tone.id)' has no bundle URL (fileName=\(tone.fileName))")
            return
        }
        log.info("▶ resolved tone='\(tone.id)' url=\(url.lastPathComponent)")

        stop()
        await activateSessionAsync()

        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.prepareToPlay()
            p.volume = Float(volume / 100)
            p.numberOfLoops = loops
            let ok = p.play()
            log.info("▶ AVAudioPlayer.play() returned \(ok) duration=\(p.duration) isPlaying=\(p.isPlaying)")
            player = p
            isPlaying = true
            currentToneID = tone.id
            log.info("▶ play DONE '\(tone.id)' file='\(tone.fileName)'")
        } catch {
            log.error("▶ AVAudioPlayer init failed: \(error)")
        }
    }

    func setVolume(_ volume: Double) {
        player?.volume = Float(volume / 100)
    }

    func stop() {
        if isPlaying {
            log.info("⏹ stop (toneID='\(self.currentToneID ?? "none")')")
        }
        player?.stop()
        player = nil
        isPlaying = false
        currentToneID = nil
    }

    private func activateSessionAsync() async {
        let session = AVAudioSession.sharedInstance()
        log.info("🎚 session BEFORE category=\(session.category.rawValue) isOtherAudioPlaying=\(session.isOtherAudioPlaying) outputVolume=\(session.outputVolume)")
        try? session.setCategory(.playback, mode: .default, options: [])
        let backoffs: [TimeInterval] = [0.3, 0.5, 0.7, 1.0, 1.0, 1.5, 2.0]
        for (i, wait) in backoffs.enumerated() {
            do {
                try session.setActive(true, options: [.notifyOthersOnDeactivation])
                log.info("🎚 setActive OK on attempt \(i + 1). isOtherAudioPlaying=\(session.isOtherAudioPlaying)")
                return
            } catch let err as NSError {
                log.warning("🎚 setActive failed (attempt \(i + 1)) code=\(err.code) isOtherAudioPlaying=\(session.isOtherAudioPlaying) — sleeping \(wait)s")
                try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            }
        }
        log.error("🎚 setActive gave up after retries")
    }

}
