import AVFoundation
import Foundation
import Observation

@MainActor
@Observable
final class CameraManager: NSObject {
    let session = AVCaptureSession()

    var isRecording = false
    var recordedURL: URL?
    var elapsedSeconds = 0
    var errorMessage: String?

    private let movieOutput = AVCaptureMovieFileOutput()
    private var isConfigured = false
    private var timer: Timer?

    func startSession() async {
        guard !session.isRunning else { return }

        let videoGranted = await requestAccess(for: .video)
        let audioGranted = await requestAccess(for: .audio)

        guard videoGranted && audioGranted else {
            errorMessage = "Camera and microphone access are required."
            return
        }

        if !isConfigured {
            configureSession()
        }

        session.startRunning()
    }

    func stopSession() {
        if session.isRunning {
            session.stopRunning()
        }
        stopTimer()
    }

    func startRecording() {
        guard !movieOutput.isRecording else { return }
        recordedURL = nil
        elapsedSeconds = 0
        errorMessage = nil

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")

        movieOutput.startRecording(to: outputURL, recordingDelegate: self)
        isRecording = true
        startTimer()
    }

    func stopRecording() {
        guard movieOutput.isRecording else { return }
        movieOutput.stopRecording()
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .hd1280x720

        do {
            if let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                let videoInput = try AVCaptureDeviceInput(device: videoDevice)
                if session.canAddInput(videoInput) {
                    session.addInput(videoInput)
                }
            }

            if let audioDevice = AVCaptureDevice.default(for: .audio) {
                let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                if session.canAddInput(audioInput) {
                    session.addInput(audioInput)
                }
            }

            if session.canAddOutput(movieOutput) {
                session.addOutput(movieOutput)
                movieOutput.maxRecordedDuration = CMTime(seconds: 180, preferredTimescale: 1)
            }
        } catch {
            errorMessage = "Failed to configure camera."
        }

        session.commitConfiguration()
        isConfigured = true
    }

    private func requestAccess(for mediaType: AVMediaType) async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: mediaType) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.elapsedSeconds += 1
            if self.elapsedSeconds >= 180 {
                self.stopRecording()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if error != nil {
            errorMessage = "Recording failed."
            isRecording = false
            stopTimer()
            return
        }

        recordedURL = outputFileURL
        isRecording = false
        stopTimer()
    }
}
