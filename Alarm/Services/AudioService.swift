import AudioToolbox
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
    @ObservationIgnored private var loopTask: Task<Void, Never>?

    func play(toneID: String, volume: Double = 100, loops: Int = 0) {
        guard let tone = allTones.first(where: { $0.id == toneID }) else {
            log.error("▶ unknown toneID '\(toneID)'")
            return
        }
        stop()

        if let url = tone.previewURL, let p = makePlayer(url: url) {
            p.volume = Float(volume / 100)
            p.numberOfLoops = loops
            p.play()
            player = p
            isPlaying = true
            currentToneID = toneID
            log.info("▶ AVAudioPlayer toneID='\(toneID)' volume=\(Int(volume))%")
        } else {
            // System file inaccessible — fall back to AudioServices loop.
            isPlaying = true
            currentToneID = toneID
            log.info("▶ AudioServices fallback toneID='\(toneID)'")
            let shouldLoop = loops != 0
            loopTask = Task {
                repeat {
                    AudioServicesPlaySystemSound(tone.systemSoundID)
                    try? await Task.sleep(for: .seconds(3))
                } while shouldLoop && !Task.isCancelled
            }
        }
    }

    func setVolume(_ volume: Double) {
        player?.volume = Float(volume / 100)
    }

    func stop() {
        loopTask?.cancel()
        loopTask = nil
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
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            return try AVAudioPlayer(contentsOf: url)
        } catch {
            log.error("▶ AVAudioPlayer init failed: \(error)")
            return nil
        }
    }
}
