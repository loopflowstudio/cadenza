import SwiftUI
import AVFoundation

struct PracticeTimerOverlay: View {
    let recommendedTime: Int?
    @State private var elapsedTime: Int = 0
    @State private var timer: Timer?
    @State private var isRunning = false

    private var displayTime: Int {
        if let recommended = recommendedTime {
            return max(0, recommended - elapsedTime)
        } else {
            return elapsedTime
        }
    }

    private var timeString: String {
        let minutes = displayTime / 60
        let seconds = displayTime % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var progress: Double {
        guard let recommended = recommendedTime, recommended > 0 else { return 0 }
        return min(1.0, Double(elapsedTime) / Double(recommended))
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "timer")
                    .font(.title3)
                    .foregroundColor(isRunning ? .green : .gray)

                Text("Timer")
                    .font(.caption)
                    .fontWeight(.medium)

                Spacer()

                if let recommended = recommendedTime {
                    Text("Target: \(recommended / 60):\(String(format: "%02d", recommended % 60))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            VStack(spacing: 8) {
                Text(timeString)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(displayTime == 0 && recommendedTime != nil ? .red : .primary)

                if recommendedTime != nil {
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .tint(progress >= 1.0 ? .red : .green)
                }

                HStack(spacing: 20) {
                    Button {
                        if isRunning {
                            pauseTimer()
                        } else {
                            startTimer()
                        }
                    } label: {
                        Image(systemName: isRunning ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .frame(width: 50, height: 50)
                            .background(Circle().fill(Color.accentColor))
                            .foregroundColor(.white)
                    }

                    Button {
                        resetTimer()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.title3)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(Color.gray.opacity(0.2)))
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground).opacity(0.95))
        .cornerRadius(12)
        .shadow(radius: 2)
        .onDisappear {
            timer?.invalidate()
        }
    }

    // MARK: - Timer Control

    private func startTimer() {
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                elapsedTime += 1

                if let recommended = recommendedTime, elapsedTime == recommended {
                    AudioServicesPlaySystemSound(SystemSoundID(1105))
                }
            }
        }
    }

    private func pauseTimer() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    private func resetTimer() {
        pauseTimer()
        elapsedTime = 0
    }
}

#Preview {
    VStack(spacing: 20) {
        PracticeTimerOverlay(recommendedTime: 180)
        PracticeTimerOverlay(recommendedTime: nil)
    }
    .padding()
}
