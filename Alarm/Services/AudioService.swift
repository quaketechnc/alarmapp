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
        let tone = allTones.first { $0.id == toneID }
            ?? allTones.first { $0.id == defaultAlarmToneID }
            ?? allTones.first
        guard let tone else {
            log.error("▶ no tones in bundle — nothing to play")
            return
        }
        guard let url = tone.bundleURL else {
            log.error("▶ tone '\(tone.id)' has no bundle URL (fileName=\(tone.fileName))")
            return
        }
        stop()
        guard let p = makePlayer(url: url) else { return }
        p.volume = Float(volume / 100)
        p.numberOfLoops = loops
        p.play()
        player = p
        isPlaying = true
        currentToneID = tone.id
        log.info("▶ play '\(tone.id)' file='\(tone.fileName)' vol=\(Int(volume))% loops=\(loops)")
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

    private func makePlayer(url: URL) -> AVAudioPlayer? {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            let p = try AVAudioPlayer(contentsOf: url)
            p.prepareToPlay()
            return p
        } catch {
            log.error("▶ AVAudioPlayer init failed for \(url.lastPathComponent): \(error)")
            return nil
        }
    }
}
