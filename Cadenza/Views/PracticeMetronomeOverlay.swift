import SwiftUI

struct PracticeMetronomeOverlay: View {
    @State private var metronome = MetronomeService()

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "metronome")
                    .font(.title3)
                    .foregroundColor(metronome.isPlaying ? .green : .gray)

                Text("Metronome")
                    .font(.caption)
                    .fontWeight(.medium)

                Spacer()

                Text("\(metronome.bpm) BPM")
                    .font(.caption)
                    .fontWeight(.semibold)
            }

            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    ForEach(1...4, id: \.self) { beat in
                        Circle()
                            .fill(metronome.currentBeat == beat ? Color.accentColor : Color.gray.opacity(0.3))
                            .frame(width: 20, height: 20)
                            .animation(.easeInOut(duration: 0.1), value: metronome.currentBeat)
                    }
                }

                HStack(spacing: 16) {
                    Button {
                        metronome.setBPM(metronome.bpm - 5)
                    } label: {
                        Image(systemName: "minus")
                            .font(.title3)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.gray.opacity(0.2)))
                    }

                    Slider(value: Binding(
                        get: { Double(metronome.bpm) },
                        set: { metronome.setBPM(Int($0)) }
                    ), in: 20...300, step: 1)
                    .frame(width: 120)

                    Button {
                        metronome.setBPM(metronome.bpm + 5)
                    } label: {
                        Image(systemName: "plus")
                            .font(.title3)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.gray.opacity(0.2)))
                    }
                }

                Button {
                    if metronome.isPlaying {
                        metronome.stop()
                    } else {
                        metronome.start()
                    }
                } label: {
                    Image(systemName: metronome.isPlaying ? "stop.fill" : "play.fill")
                        .font(.title2)
                        .frame(width: 50, height: 50)
                        .background(Circle().fill(Color.accentColor))
                        .foregroundColor(.white)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground).opacity(0.95))
        .cornerRadius(12)
        .shadow(radius: 2)
        .onDisappear {
            metronome.stop()
        }
    }
}

#Preview {
    PracticeMetronomeOverlay()
        .padding()
}
