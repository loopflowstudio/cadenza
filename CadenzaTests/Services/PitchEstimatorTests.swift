import XCTest
@testable import Cadenza

final class PitchEstimatorTests: XCTestCase {
    var estimator: PitchEstimator!

    override func setUp() {
        super.setUp()
        estimator = PitchEstimator(threshold: 0.1)
    }

    func testDetectsPitchFromSineWave() {
        let frequency = 440.0
        let sampleRate = 44100.0
        let duration = 0.1
        let samples = generateSineWave(frequency: frequency, sampleRate: sampleRate, duration: duration)

        let result = estimator.detectPitch(samples: samples, sampleRate: sampleRate)

        XCTAssertEqual(result.frequency, frequency, accuracy: 10.0, "Should detect A4 (440Hz)")
        XCTAssertGreaterThan(result.confidence, 0.8, "Should have high confidence")
    }

    func testReturnsZeroForEmptySamples() {
        let result = estimator.detectPitch(samples: [], sampleRate: 44100)

        XCTAssertEqual(result.frequency, 0.0)
        XCTAssertEqual(result.confidence, 0.0)
    }

    func testReturnsZeroForTooFewSamples() {
        let result = estimator.detectPitch(samples: [0.1, 0.2], sampleRate: 44100)

        XCTAssertEqual(result.frequency, 0.0)
        XCTAssertEqual(result.confidence, 0.0)
    }

    func testRejectsFrequenciesTooLow() {
        let samples = generateSineWave(frequency: 30, sampleRate: 44100, duration: 0.1)

        let result = estimator.detectPitch(samples: samples, sampleRate: 44100)

        XCTAssertEqual(result.frequency, 0.0)
    }

    func testRejectsFrequenciesTooHigh() {
        let samples = generateSineWave(frequency: 2500, sampleRate: 44100, duration: 0.1)

        let result = estimator.detectPitch(samples: samples, sampleRate: 44100)

        XCTAssertEqual(result.frequency, 0.0)
    }

    private func generateSineWave(frequency: Double, sampleRate: Double, duration: Double) -> [Float] {
        let numSamples = Int(sampleRate * duration)
        return (0..<numSamples).map { i in
            Float(sin(2.0 * .pi * frequency * Double(i) / sampleRate))
        }
    }
}
