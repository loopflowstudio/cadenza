import AVFoundation
import Observation

@Observable
@MainActor
class PitchService {
    var currentPitch: Double = 0.0
    var isDetecting = false
    var confidence: Float = 0.0

    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private let pitchEstimator = PitchEstimator(threshold: 0.1)

    private let sampleRate: Double = 44100
    private let bufferSize: Int = 4096

    // MARK: - Detection Control

    func startDetecting() {
        guard audioEngine == nil else {
            startEngine()
            return
        }

        requestMicrophonePermission { [weak self] granted in
            guard granted else { return }
            Task { @MainActor in
                self?.setupAudioEngine()
                self?.startEngine()
            }
        }
    }

    func stopDetecting() {
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()

        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }

        isDetecting = false
        currentPitch = 0.0
        confidence = 0.0
    }

    // MARK: - Private Setup

    private func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                Task { @MainActor in
                    completion(granted)
                }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                Task { @MainActor in
                    completion(granted)
                }
            }
        }
    }

    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        inputNode = audioEngine?.inputNode

        guard let inputNode = inputNode else {
            print("Failed to initialize audio engine")
            return
        }

        let inputFormat = inputNode.inputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(bufferSize), format: inputFormat) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }
    }

    private func startEngine() {
        guard let engine = audioEngine else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setPreferredSampleRate(44100)
            try session.setActive(true)

            try engine.start()
            isDetecting = true
        } catch {
            print("Failed to start audio engine: \(error)")
            isDetecting = false
        }
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        let samples = convertBufferToFloatArray(buffer)
        guard !samples.isEmpty else { return }

        let result = pitchEstimator.detectPitch(samples: samples, sampleRate: sampleRate)

        Task { @MainActor in
            self.currentPitch = result.frequency
            self.confidence = result.confidence
        }
    }

    private func convertBufferToFloatArray(_ buffer: AVAudioPCMBuffer) -> [Float] {
        guard let floatChannelData = buffer.floatChannelData else { return [] }

        let channelData = floatChannelData.pointee
        let frameLength = Int(buffer.frameLength)

        guard frameLength > 0 else { return [] }

        let samples = Array(UnsafeBufferPointer(start: channelData, count: frameLength))

        let maxAmplitude = samples.max() ?? 0
        let minAmplitude = samples.min() ?? 0
        if abs(maxAmplitude) < 0.0001 && abs(minAmplitude) < 0.0001 {
            return []
        }

        return samples
    }
}
