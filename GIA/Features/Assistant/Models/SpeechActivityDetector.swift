import Darwin
@preconcurrency import AVFAudio
import Foundation

struct SpeechFrameFeatures: Equatable, Sendable {
    var speechBandDecibels: Float
    var rumbleBandDecibels: Float
    var hissBandDecibels: Float
    var zeroCrossingRate: Float
    var duration: TimeInterval
}

struct SpeechGateDecision {
    var shouldAppend: Bool
    var isUtteranceActive: Bool
    var silenceDuration: TimeInterval
    var speechBandDecibels: Float
    var preRoll: [AVAudioPCMBuffer]
}

enum SpeechActivityRules {
    static let startHoldDuration: TimeInterval = 0.04
    static let hangoverDuration: TimeInterval = 0.72
    static let prerollDuration: TimeInterval = 0.24
    static let speechOverRumbleDecibels: Float = 3
    static let speechOverHissDecibels: Float = 3
    static let speechAboveFloorDecibels: Float = 2.5
    static let minimumSpeechBandDecibels: Float = -58
    static let minimumZeroCrossingRate: Float = 0.01
    static let recognizerPassThroughDecibels: Float = -54

    static func isSpeechFrame(
        _ features: SpeechFrameFeatures,
        noiseFloor: Float
    ) -> Bool {
        features.speechBandDecibels >= minimumSpeechBandDecibels
            && features.speechBandDecibels
                >= noiseFloor + speechAboveFloorDecibels
            && features.speechBandDecibels
                >= features.rumbleBandDecibels + speechOverRumbleDecibels
            && features.speechBandDecibels
                >= features.hissBandDecibels + speechOverHissDecibels
            && features.zeroCrossingRate >= minimumZeroCrossingRate
    }
}

final class SpeechActivityDetector: @unchecked Sendable {
    private let lock = NSLock()
    private var noiseFloorDecibels: Float = -48
    private var highPassState: Float = 0
    private var previousSample: Float = 0
    private var rumbleState: Float = 0
    private var speechBandState: Float = 0
    private var hissState: Float = 0
    private var previousHissSample: Float = 0
    private var sampleRate: Double = 48_000
    private var consecutiveSpeechDuration: TimeInterval = 0
    private var lastSpeechAt: TimeInterval = 0
    private var utteranceActive = false
    private var silenceDuration: TimeInterval = 0
    private var currentTime: TimeInterval = 0
    private var preRoll: [AVAudioPCMBuffer] = []
    private var preRollDuration: TimeInterval = 0

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        noiseFloorDecibels = -48
        highPassState = 0
        previousSample = 0
        rumbleState = 0
        speechBandState = 0
        hissState = 0
        previousHissSample = 0
        consecutiveSpeechDuration = 0
        lastSpeechAt = 0
        utteranceActive = false
        silenceDuration = 0
        currentTime = 0
        preRoll.removeAll(keepingCapacity: true)
        preRollDuration = 0
    }

    func consume(_ buffer: AVAudioPCMBuffer) -> SpeechGateDecision {
        lock.lock()
        defer { lock.unlock() }

        let features = analyze(buffer)
        currentTime += features.duration
        updateNoiseFloor(features.speechBandDecibels)

        let isSpeech = SpeechActivityRules.isSpeechFrame(
            features,
            noiseFloor: noiseFloorDecibels
        )
        if isSpeech {
            consecutiveSpeechDuration += features.duration
            lastSpeechAt = currentTime
        } else {
            consecutiveSpeechDuration = 0
        }

        let speechConfirmed =
            consecutiveSpeechDuration
                >= SpeechActivityRules.startHoldDuration
        let inHangover =
            currentTime - lastSpeechAt
                <= SpeechActivityRules.hangoverDuration
            && lastSpeechAt > 0
        let wasActive = utteranceActive
        utteranceActive = speechConfirmed || (wasActive && inHangover)

        var flushedPreRoll: [AVAudioPCMBuffer] = []
        if utteranceActive {
            silenceDuration = 0
            if !wasActive {
                flushedPreRoll = preRoll
                preRoll.removeAll(keepingCapacity: true)
                preRollDuration = 0
            }
        } else {
            silenceDuration = lastSpeechAt == 0
                ? currentTime
                : currentTime - lastSpeechAt
                    - SpeechActivityRules.hangoverDuration
            enqueuePreRoll(buffer, duration: features.duration)
        }

        return SpeechGateDecision(
            shouldAppend: utteranceActive,
            isUtteranceActive: utteranceActive,
            silenceDuration: max(silenceDuration, 0),
            speechBandDecibels: features.speechBandDecibels,
            preRoll: flushedPreRoll
        )
    }

    private func updateNoiseFloor(_ speechBandDecibels: Float) {
        let distance = speechBandDecibels - noiseFloorDecibels
        if distance < 0 {
            noiseFloorDecibels += distance * 0.18
        } else if distance < 12 {
            noiseFloorDecibels += distance * 0.01
        }
    }

    private func enqueuePreRoll(
        _ buffer: AVAudioPCMBuffer,
        duration: TimeInterval
    ) {
        guard duration > 0, let copy = Self.copy(buffer) else { return }
        preRoll.append(copy)
        preRollDuration += duration
        while
            preRollDuration > SpeechActivityRules.prerollDuration,
            preRoll.count > 1
        {
            let removed = preRoll.removeFirst()
            preRollDuration -= Double(removed.frameLength)
                / max(removed.format.sampleRate, 1)
        }
    }

    private func analyze(_ buffer: AVAudioPCMBuffer) -> SpeechFrameFeatures {
        let rate = buffer.format.sampleRate
        if rate > 0, abs(rate - sampleRate) > 1 {
            sampleRate = rate
            highPassState = 0
            previousSample = 0
            rumbleState = 0
            speechBandState = 0
            hissState = 0
            previousHissSample = 0
        }

        let frameCount = Int(buffer.frameLength)
        let duration = sampleRate > 0
            ? TimeInterval(frameCount) / sampleRate
            : 0
        guard
            frameCount > 1,
            let channel = buffer.floatChannelData?.pointee
        else {
            return SpeechFrameFeatures(
                speechBandDecibels: -60,
                rumbleBandDecibels: -60,
                hissBandDecibels: -60,
                zeroCrossingRate: 0,
                duration: duration
            )
        }

        let highPassCoefficient = Float(
            exp(-2.0 * Double.pi * 250.0 / max(sampleRate, 1))
        )
        let rumbleCoefficient = Float(
            1 - exp(-2.0 * Double.pi * 140.0 / max(sampleRate, 1))
        )
        let speechLowPassCoefficient = Float(
            1 - exp(-2.0 * Double.pi * 3_500.0 / max(sampleRate, 1))
        )
        let hissCoefficient = Float(
            exp(-2.0 * Double.pi * 4_000.0 / max(sampleRate, 1))
        )

        var speechEnergy: Float = 0
        var rumbleEnergy: Float = 0
        var hissEnergy: Float = 0
        var crossings: Int = 0
        var previousSpeechBand = speechBandState

        for index in 0..<frameCount {
            let sample = channel[index]
            let highPass =
                highPassCoefficient
                * (highPassState + sample - previousSample)
            highPassState = highPass
            previousSample = sample

            rumbleState += rumbleCoefficient * (sample - rumbleState)
            speechBandState +=
                speechLowPassCoefficient * (highPass - speechBandState)
            let hiss =
                hissCoefficient
                * (hissState + sample - previousHissSample)
            hissState = hiss
            previousHissSample = sample

            speechEnergy += speechBandState * speechBandState
            rumbleEnergy += rumbleState * rumbleState
            hissEnergy += hiss * hiss
            if previousSpeechBand.sign != speechBandState.sign {
                crossings += 1
            }
            previousSpeechBand = speechBandState
        }

        let count = Float(frameCount)
        return SpeechFrameFeatures(
            speechBandDecibels: Self.decibels(
                fromMeanSquare: speechEnergy / count
            ),
            rumbleBandDecibels: Self.decibels(
                fromMeanSquare: rumbleEnergy / count
            ),
            hissBandDecibels: Self.decibels(
                fromMeanSquare: hissEnergy / count
            ),
            zeroCrossingRate: Float(crossings) / count,
            duration: duration
        )
    }

    private static func decibels(fromMeanSquare meanSquare: Float) -> Float {
        10 * log10(max(meanSquare, 0.000_000_001))
    }

    private static func copy(
        _ buffer: AVAudioPCMBuffer
    ) -> AVAudioPCMBuffer? {
        guard
            let copy = AVAudioPCMBuffer(
                pcmFormat: buffer.format,
                frameCapacity: buffer.frameLength
            )
        else {
            return nil
        }
        copy.frameLength = buffer.frameLength
        guard
            let source = buffer.floatChannelData,
            let destination = copy.floatChannelData
        else {
            return copy
        }
        let channelCount = Int(buffer.format.channelCount)
        let byteCount = Int(buffer.frameLength) * MemoryLayout<Float>.size
        for channel in 0..<channelCount {
            memcpy(destination[channel], source[channel], byteCount)
        }
        return copy
    }
}
