import XCTest
@testable import Cadenza

@MainActor
final class MetronomeServiceTests: XCTestCase {

    func testInitialStateIsNotPlaying() {
        let metronome = MetronomeService()
        XCTAssertFalse(metronome.isPlaying)
        XCTAssertEqual(metronome.bpm, 120)
        XCTAssertEqual(metronome.currentBeat, 0)
    }

    func testStartUpdatesPlayingState() {
        let metronome = MetronomeService()
        metronome.start()

        XCTAssertTrue(metronome.isPlaying)
        XCTAssertEqual(metronome.currentBeat, 1, "Should be on first beat after starting")
    }

    func testStopUpdatesPlayingState() {
        let metronome = MetronomeService()
        metronome.start()
        XCTAssertTrue(metronome.isPlaying)

        metronome.stop()

        XCTAssertFalse(metronome.isPlaying)
        XCTAssertEqual(metronome.currentBeat, 0)
    }

    func testSetBPMClampsToBounds() {
        let metronome = MetronomeService()
        metronome.setBPM(10)
        XCTAssertEqual(metronome.bpm, 20)

        metronome.setBPM(400)
        XCTAssertEqual(metronome.bpm, 300)
    }

    func testSetBPMRestartsIfPlaying() {
        let metronome = MetronomeService()
        metronome.start()
        XCTAssertTrue(metronome.isPlaying)

        metronome.setBPM(140)

        XCTAssertTrue(metronome.isPlaying)
        XCTAssertEqual(metronome.bpm, 140)
    }
}
