import AVFoundation
import Observation

@Observable
@MainActor
class MetronomeService {
    var bpm: Int = 120
    var isPlaying = false
    var currentBeat: Int = 0

    private var timer: Timer?
    private var audioPlayer: AVAudioPlayer?

    func start() {
        guard !isPlaying else { return }

        isPlaying = true
        currentBeat = 0

        let interval = 60.0 / Double(bpm)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }

        tick()
    }

    func stop() {
        isPlaying = false
        timer?.invalidate()
        timer = nil
        currentBeat = 0
    }

    func setBPM(_ newBPM: Int) {
        let wasPlaying = isPlaying
        if wasPlaying {
            stop()
        }
        bpm = max(20, min(300, newBPM))
        if wasPlaying {
            start()
        }
    }

    // MARK: - Private

    private func tick() {
        currentBeat = (currentBeat % 4) + 1
        AudioServicesPlaySystemSound(SystemSoundID(1104))
    }
}
