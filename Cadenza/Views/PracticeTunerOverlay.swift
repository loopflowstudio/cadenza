import SwiftUI

struct PracticeTunerOverlay: View {
    @State private var pitchService = PitchService()
    @State private var detectedPitch: Pitch?
    @State private var updateTimer: Timer?

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "tuningfork")
                    .font(.title3)
                    .foregroundColor(pitchService.isDetecting ? .green : .orange)

                Text("Tuner")
                    .font(.caption)
                    .fontWeight(.medium)

                Spacer()

                if pitchService.isDetecting {
                    Text(detectedPitch?.note ?? "—")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(detectedPitch?.isInTune == true ? .green : .primary)
                } else {
                    Text("No signal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            VStack(spacing: 8) {
                TuningIndicator(
                    deviation: detectedPitch?.cents ?? 0,
                    isInTune: detectedPitch?.isInTune ?? false,
                    hasSignal: detectedPitch != nil
                )
                .frame(height: 30)

                if let pitch = detectedPitch {
                    HStack {
                        Text("\(pitch.frequency, specifier: "%.1f") Hz")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Spacer()

                        Text("\(pitch.cents > 0 ? "+" : "")\(Int(pitch.cents)) cents")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else if !pitchService.isDetecting {
                    Text("Initializing microphone...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground).opacity(0.95))
        .cornerRadius(12)
        .shadow(radius: 2)
        .onAppear {
            startTuner()
        }
        .onDisappear {
            stopTuner()
        }
    }

    // MARK: - Tuner Control

    private func startTuner() {
        pitchService.startDetecting()

        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                if pitchService.currentPitch > 0 {
                    detectedPitch = Pitch(pitchService.currentPitch)
                } else {
                    detectedPitch = nil
                }
            }
        }
    }

    private func stopTuner() {
        updateTimer?.invalidate()
        updateTimer = nil
        pitchService.stopDetecting()
    }
}

// MARK: - Tuning Indicator

struct TuningIndicator: View {
    let deviation: Double
    let isInTune: Bool
    let hasSignal: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.2))

                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.red.opacity(0.3))
                        .frame(width: geometry.size.width * 0.4)

                    Rectangle()
                        .fill(Color.green.opacity(0.3))
                        .frame(width: geometry.size.width * 0.2)

                    Rectangle()
                        .fill(Color.red.opacity(0.3))
                        .frame(width: geometry.size.width * 0.4)
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))

                Rectangle()
                    .fill(Color.black)
                    .frame(width: 2)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)

                if hasSignal && abs(deviation) <= 50 {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isInTune ? Color.green : Color.orange)
                        .frame(width: 4, height: geometry.size.height - 4)
                        .position(
                            x: geometry.size.width / 2 + CGFloat(deviation / 50) * (geometry.size.width / 2 - 10),
                            y: geometry.size.height / 2
                        )
                        .animation(.easeInOut(duration: 0.1), value: deviation)
                }

                HStack {
                    Text("♭")
                        .font(.caption2)
                        .foregroundColor(.red)

                    Spacer()

                    Text("♯")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 4)
            }
        }
    }
}

#Preview {
    PracticeTunerOverlay()
        .padding()
}
