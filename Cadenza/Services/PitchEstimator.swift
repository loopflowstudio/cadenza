import Foundation

class PitchEstimator {
    private let threshold: Float

    init(threshold: Float = 0.1) {
        self.threshold = threshold
    }

    func detectPitch(samples: [Float], sampleRate: Double) -> (frequency: Double, confidence: Float) {
        guard samples.count > 2 else { return (0.0, 0.0) }

        let diff = differenceFunction(input: samples)
        let cmnd = cumulativeMeanNormalizedDifference(diff: diff)

        guard let tau = firstPeriodBelowThreshold(cmnd: cmnd) else {
            return (0.0, 0.0)
        }

        let period = interpolatePitchPeriod(cmnd: cmnd, tau: tau)
        let frequency = Float(sampleRate) / period

        let confidence = max(0.0, 1.0 - cmnd[tau])

        guard frequency > 50 && frequency < 2000 else {
            return (0.0, 0.0)
        }

        return (Double(frequency), confidence)
    }

    // MARK: - YIN Algorithm Steps

    private func differenceFunction(input: [Float]) -> [Float] {
        let n = input.count
        let halfN = n / 2
        var diff = Array(repeating: Float(0), count: halfN)

        for tau in 0..<halfN {
            var sum: Float = 0
            for j in 0..<halfN {
                if j + tau < n {
                    let delta = input[j] - input[j + tau]
                    sum += delta * delta
                }
            }
            diff[tau] = sum
        }

        return diff
    }

    private func cumulativeMeanNormalizedDifference(diff: [Float]) -> [Float] {
        var cmnd = Array(repeating: Float(0), count: diff.count)
        cmnd[0] = 1

        var runningSum: Float = 0

        for tau in 1..<diff.count {
            runningSum += diff[tau]
            if runningSum == 0 {
                cmnd[tau] = 1
            } else {
                cmnd[tau] = diff[tau] / (runningSum / Float(tau))
            }
        }

        return cmnd
    }

    private func firstPeriodBelowThreshold(cmnd: [Float]) -> Int? {
        for tau in 2..<cmnd.count {
            if cmnd[tau] < threshold {
                var localMinTau = tau
                for t in tau..<min(tau + 10, cmnd.count) {
                    if cmnd[t] < cmnd[localMinTau] {
                        localMinTau = t
                    }
                }
                return localMinTau
            }
        }
        return nil
    }

    private func interpolatePitchPeriod(cmnd: [Float], tau: Int) -> Float {
        guard tau > 0 && tau < cmnd.count - 1 else {
            return Float(tau)
        }

        let s0 = cmnd[tau - 1]
        let s1 = cmnd[tau]
        let s2 = cmnd[tau + 1]

        let a = (s0 - 2 * s1 + s2) / 2
        let b = (s2 - s0) / 2

        if abs(a) < 1e-10 {
            return Float(tau)
        }

        let offset = -b / (2 * a)
        return Float(tau) + offset
    }
}
