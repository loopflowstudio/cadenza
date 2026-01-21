import Foundation

struct Pitch {
    let frequency: Double
    let note: String
    let octave: Int
    let cents: Double

    init(_ frequency: Double) {
        self.frequency = frequency

        let noteNames = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]

        let a4 = 440.0
        let a4Octave = 4

        let semitones = 12 * log2(frequency / a4)
        let roundedSemitones = round(semitones)

        self.cents = (semitones - roundedSemitones) * 100

        let noteIndex = (Int(roundedSemitones) + 9) % 12
        let noteIndexPositive = noteIndex >= 0 ? noteIndex : noteIndex + 12
        self.note = noteNames[noteIndexPositive]
        self.octave = a4Octave + Int(roundedSemitones + 9) / 12
    }

    var isInTune: Bool {
        abs(cents) <= 20
    }
}

extension Pitch: Equatable {
    static func == (lhs: Pitch, rhs: Pitch) -> Bool {
        abs(lhs.frequency - rhs.frequency) < 0.1
    }
}
