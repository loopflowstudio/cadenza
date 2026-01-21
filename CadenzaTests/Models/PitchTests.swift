import XCTest
@testable import Cadenza

final class PitchTests: XCTestCase {
    func testA4FrequencyDetectedCorrectly() {
        let pitch = Pitch(440.0)

        XCTAssertEqual(pitch.note, "A")
        XCTAssertEqual(pitch.octave, 4)
        XCTAssertEqual(pitch.cents, 0, accuracy: 1.0)
    }

    func testC4FrequencyDetectedCorrectly() {
        let pitch = Pitch(261.63)

        XCTAssertEqual(pitch.note, "C")
        XCTAssertEqual(pitch.octave, 4)
        XCTAssertEqual(pitch.cents, 0, accuracy: 5.0)
    }

    func testSharpNoteDetectedCorrectly() {
        let pitch = Pitch(277.18)

        XCTAssertEqual(pitch.note, "C♯")
        XCTAssertEqual(pitch.octave, 4)
    }

    func testFlatNoteShownAsSharp() {
        let pitch = Pitch(277.18)

        XCTAssertEqual(pitch.note, "C♯")
    }

    func testSlightlyFlatNoteHasNegativeCents() {
        let pitch = Pitch(438.0)

        XCTAssertEqual(pitch.note, "A")
        XCTAssertLessThan(pitch.cents, 0)
    }

    func testSlightlySharpNoteHasPositiveCents() {
        let pitch = Pitch(442.0)

        XCTAssertEqual(pitch.note, "A")
        XCTAssertGreaterThan(pitch.cents, 0)
    }

    func testIsInTuneWhenWithin20Cents() {
        let pitch = Pitch(440.0)
        XCTAssertTrue(pitch.isInTune)

        let slightlyFlat = Pitch(438.0)
        XCTAssertTrue(slightlyFlat.isInTune)

        let slightlySharp = Pitch(442.0)
        XCTAssertTrue(slightlySharp.isInTune)
    }

    func testIsNotInTuneWhenBeyond20Cents() {
        let veryFlat = Pitch(430.0)
        XCTAssertFalse(veryFlat.isInTune)

        let verySharp = Pitch(450.0)
        XCTAssertFalse(verySharp.isInTune)
    }

    func testOctaveCalculationCorrect() {
        let c3 = Pitch(130.81)
        XCTAssertEqual(c3.octave, 3)

        let c5 = Pitch(523.25)
        XCTAssertEqual(c5.octave, 5)

        let c6 = Pitch(1046.5)
        XCTAssertEqual(c6.octave, 6)
    }

    func testEqualityBasedOnFrequency() {
        let pitch1 = Pitch(440.0)
        let pitch2 = Pitch(440.05)
        let pitch3 = Pitch(445.0)

        XCTAssertEqual(pitch1, pitch2)
        XCTAssertNotEqual(pitch1, pitch3)
    }
}
