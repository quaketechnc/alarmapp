import AVFoundation
import MediaPlayer
import os
import Observation
import UIKit

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
        await MainActor.run { Self.setSystemVolume(Float(volume / 100)) }

        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.prepareToPlay()
            p.volume = 1.0  // system volume is the gate; player stays at 1.0
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
        Self.setSystemVolume(Float(volume / 100))
    }

    /// Keep a single MPVolumeView alive in the key window so its slider is
    /// attached (the classic iOS "set system volume" trick requires the
    /// slider to actually be in the view hierarchy; a throw-away view
    /// created on-demand often never lays out in time).
    @MainActor private static let volumeHost: MPVolumeView = {
        let v = MPVolumeView(frame: CGRect(x: -4000, y: -4000, width: 1, height: 1))
        v.showsRouteButton = false
        v.isUserInteractionEnabled = false
        v.alpha = 0.0001
        return v
    }()

    @MainActor
    private static func attachHostIfNeeded() {
        if volumeHost.superview != nil { return }
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
        window?.addSubview(volumeHost)
    }

    /// Recursively find the MPVolumeSlider (subclass of UISlider).
    @MainActor
    private static func findVolumeSlider(in view: UIView) -> UISlider? {
        for sub in view.subviews {
            if let s = sub as? UISlider { return s }
            if let found = findVolumeSlider(in: sub) { return found }
        }
        return nil
    }

    @MainActor
    private static func setSystemVolume(_ value: Float) {
        let clamped = max(0, min(1, value))
        attachHostIfNeeded()

        // MPVolumeSlider may not exist until after a runloop tick.
        func apply(attempts: Int) {
            if let slider = findVolumeSlider(in: volumeHost) {
                slider.setValue(clamped, animated: false)
                // sendActions(.valueChanged) actually pushes the change through
                // to the system audio service.
                slider.sendActions(for: .valueChanged)
                log.info("🔊 system volume → \(clamped) (slider=\(type(of: slider)))")
            } else if attempts > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { apply(attempts: attempts - 1) }
            } else {
                log.warning("🔊 MPVolumeView slider not found")
            }
        }
        DispatchQueue.main.async { apply(attempts: 10) }
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

        // .mixWithOthers: don't try to interrupt any other session — we'd
        // rather mix over whatever else is playing than fail with 560557684
        // (cannotInterruptOthers). Alarms must not be silent.
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            log.info("🎚 setCategory(.playback, .mixWithOthers) OK")
        } catch let err as NSError {
            log.error("🎚 setCategory failed code=\(err.code) desc=\(err.localizedDescription)")
        }

        let backoffs: [TimeInterval] = [0.2, 0.3, 0.5, 0.7, 1.0, 1.5, 2.0]
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
