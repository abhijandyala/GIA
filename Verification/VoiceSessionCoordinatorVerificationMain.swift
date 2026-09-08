import AVFAudio
import Foundation

@main
enum VoiceSessionCoordinatorVerificationMain {
    static func main() {
        let acceptedWakePhrases = [
            "Hey GIA",
            "gia",
            "jia",
            "hey jia",
            "heygia",
            "Hey chia",
            "yo gia",
            "giah",
            "gee uh",
            "hey gee",
            "hey gigi",
            "Can you help, Gia?",
            "G. I. A.",
            "gee eye ay",
            "Okay gee i a please listen",
            "hey gee eye a",
            "Gee I ay, are you there?",
            "hey ya",
            "hey ja",
            "hey yeah",
            "hey yea",
            "agia",
            "aegia"
        ]
        for phrase in acceptedWakePhrases {
            precondition(
                VoiceRecognitionRules.containsWakePhrase(phrase),
                "Wake phrase was not accepted: \(phrase)"
            )
        }

        let strippedRequests: [(String, String)] = [
            (
                "Hey jia, plan a trip to Chicago",
                "plan a trip to Chicago"
            ),
            (
                "Hey GIA, plan a trip to Chicago",
                "plan a trip to Chicago"
            ),
            (
                "G. I. A. fly from Atlanta to Tokyo",
                "fly from Atlanta to Tokyo"
            ),
            (
                "Okay gee eye ay: plan five days in Paris",
                "plan five days in Paris"
            ),
            (
                "Plan a trip to Georgia",
                "Plan a trip to Georgia"
            ),
            (
                "Yes yes yes yes no yes yes yes yes no hey Gigi hey Jia",
                ""
            ),
            (
                "yes yes hey jia plan a trip to Chicago",
                "plan a trip to Chicago"
            ),
            (
                "Can you help, Gia?",
                ""
            )
        ]
        for (input, expected) in strippedRequests {
            precondition(
                VoiceRecognitionRules.strippingWakePhrasePrefix(
                    from: input
                ) == expected,
                "Wake prefix was not stripped safely: \(input)"
            )
        }
        precondition(
            VoiceRecognitionRules.containsWakePhrase("hey gigi")
        )
        precondition(
            VoiceRecognitionRules.spokenRequestAfterWake(
                from: "Yes yes yes no hey Gigi hey Jia"
            ).isEmpty
        )
        precondition(
            VoiceRecognitionRules.spokenRequestAfterWake(
                from: "hey ya"
            ).isEmpty
        )
        precondition(
            VoiceRecognitionRules.spokenRequestAfterWake(
                from: "hey yeah"
            ).isEmpty
        )
        precondition(
            VoiceRecognitionRules.mergingTranscript(
                existing: "plan a trip to Paris next week",
                incoming: "plan a trip to Paris next"
            ) == "plan a trip to Paris next week"
        )
        precondition(
            VoiceRecognitionRules.appendingSpokenRequest(
                existing: "I want to go to",
                incoming: "Paris next week"
            ) == "I want to go to Paris next week"
        )
        precondition(
            VoiceRecognitionRules.appendingSpokenRequest(
                existing: "I want to go to",
                incoming: "yes yes hey jia Paris next week"
            ) == "I want to go to Paris next week"
        )
        precondition(
            VoiceRecognitionRules.looksIncomplete(
                VoiceRecognitionRules.appendingSpokenRequest(
                    existing: "",
                    incoming: "I want to go to"
                )
            )
        )

        let rejectedWakePhrases = [
            "Georgia",
            "giant",
            "Siri",
            "plan a trip",
            "energy",
            "chia seeds",
            "history",
            "yoga",
            "ya",
            "yeah",
            "ok yeah"
        ]
        for phrase in rejectedWakePhrases {
            precondition(
                !VoiceRecognitionRules.containsWakePhrase(phrase),
                "False wake phrase was accepted: \(phrase)"
            )
        }

        for command in [
            "stop",
            "Stop GIA",
            "GIA, stop",
            "goodbye",
            "bye GIA",
            "see you later",
            "that's all"
        ] {
            precondition(
                VoiceRecognitionRules.isStopCommand(command),
                "Stop command was not recognized: \(command)"
            )
        }
        for request in [
            "stop at one museum",
            "find a bus stop",
            "cancel the hotel only",
            "do not stop planning"
        ] {
            precondition(
                !VoiceRecognitionRules.isStopCommand(request),
                "Travel request was mistaken for stop: \(request)"
            )
        }

        precondition(
            !VoiceRecognitionRules.shouldVisualizeMicrophoneLevel(
                hasTranscript: false,
                transcriptInactivity: 0
            )
        )
        precondition(
            VoiceRecognitionRules.shouldVisualizeMicrophoneLevel(
                hasTranscript: true,
                transcriptInactivity: 0.4
            )
        )
        precondition(
            !VoiceRecognitionRules.shouldVisualizeMicrophoneLevel(
                hasTranscript: true,
                transcriptInactivity: 1.61
            )
        )

        precondition(
            VoiceRecognitionRules.requestCompletionDecision(
                hasDetectedSpeech: false,
                hasTranscript: false,
                elapsed: 2,
                silenceDuration: 2
            ) == .continueListening
        )
        precondition(
            VoiceRecognitionRules.requestCompletionDecision(
                hasDetectedSpeech: true,
                hasTranscript: true,
                elapsed: 0.3,
                silenceDuration: 2
            ) == .continueListening
        )
        precondition(
            VoiceRecognitionRules.requestCompletionDecision(
                hasDetectedSpeech: false,
                hasTranscript: false,
                elapsed: 8,
                silenceDuration: 8
            ) == .continueListening
        )
        precondition(
            VoiceRecognitionRules.requestCompletionDecision(
                hasDetectedSpeech: false,
                hasTranscript: false,
                elapsed: 12,
                silenceDuration: 12
            ) == .noSpeech
        )
        precondition(
            VoiceRecognitionRules.requestCompletionDecision(
                hasDetectedSpeech: true,
                hasTranscript: true,
                elapsed: 2,
                silenceDuration: 1.04
            ) == .continueListening
        )
        precondition(
            VoiceRecognitionRules.requestCompletionDecision(
                hasDetectedSpeech: true,
                hasTranscript: true,
                elapsed: 2,
                silenceDuration: 1.5,
                transcript: "Plan a trip to Tokyo next week"
            ) == .complete
        )
        precondition(
            VoiceRecognitionRules.requestCompletionDecision(
                hasDetectedSpeech: true,
                hasTranscript: true,
                elapsed: 2,
                silenceDuration: 1.5,
                transcript: "Plan a trip to Tokyo next week",
                transcriptStableFor: 0.08
            ) == .continueListening
        )
        precondition(
            VoiceRecognitionRules.requestCompletionDecision(
                hasDetectedSpeech: true,
                hasTranscript: true,
                elapsed: 2,
                silenceDuration: 1.5,
                transcript: "I want to go to"
            ) == .continueListening
        )
        precondition(
            VoiceRecognitionRules.requestCompletionDecision(
                hasDetectedSpeech: true,
                hasTranscript: true,
                elapsed: 3,
                silenceDuration: 2.7,
                transcript: "I want to go to"
            ) == .complete
        )
        precondition(
            VoiceRecognitionRules.requestCompletionDecision(
                hasDetectedSpeech: true,
                hasTranscript: true,
                elapsed: 2,
                silenceDuration: 2,
                transcript: "Plan a trip to Tokyo next week",
                isSpeaking: true
            ) == .continueListening
        )
        precondition(
            VoiceRecognitionRules.requestCompletionDecision(
                hasDetectedSpeech: false,
                hasTranscript: false,
                elapsed: 30,
                silenceDuration: 30
            ) == .noSpeech
        )
        precondition(
            VoiceRecognitionRules.requestCompletionDecision(
                hasDetectedSpeech: true,
                hasTranscript: true,
                elapsed: 30,
                silenceDuration: 0
            ) == .complete
        )
        precondition(
            VoiceRecognitionRules.looksIncomplete("I want to go to")
        )
        precondition(
            VoiceRecognitionRules.looksIncomplete("Paris,")
        )
        precondition(
            !VoiceRecognitionRules.looksIncomplete(
                "Plan a trip to Tokyo next week"
            )
        )
        precondition(
            !VoiceRecognitionRules.looksIncomplete("Paris")
        )
        precondition(
            SpeechEndpointRules.completeness(of: "I want to go to")
                == .hanging
        )
        precondition(
            SpeechEndpointRules.completeness(of: "Plan five days in")
                == .hanging
        )
        precondition(
            SpeechEndpointRules.completeness(of: "and then")
                == .hanging
        )
        precondition(
            SpeechEndpointRules.completeness(of: "Paris,")
                == .open
        )
        precondition(
            SpeechEndpointRules.completeness(
                of: "Plan a trip to Tokyo next week"
            ) == .finished
        )
        precondition(
            SpeechEndpointRules.completeness(of: "that's it")
                == .finished
        )
        precondition(
            SpeechEndpointRules.completeness(of: "I want to go to.")
                == .hanging
        )
        precondition(
            SpeechEndpointRules.completeness(of: "I think so")
                == .finished
        )
        precondition(
            VoiceRecognitionRules.requestCompletionDecision(
                hasDetectedSpeech: true,
                hasTranscript: true,
                elapsed: 2,
                silenceDuration: 0.85,
                transcript: "Paris,"
            ) == .continueListening
        )
        precondition(
            VoiceRecognitionRules.requestCompletionDecision(
                hasDetectedSpeech: true,
                hasTranscript: true,
                elapsed: 2,
                silenceDuration: 1.3,
                transcript: "Paris,"
            ) == .continueListening
        )
        precondition(
            VoiceRecognitionRules.requestCompletionDecision(
                hasDetectedSpeech: true,
                hasTranscript: true,
                elapsed: 2,
                silenceDuration: 1.9,
                transcript: "Paris,"
            ) == .complete
        )
        precondition(
            SpeechEndpointRules.looksCutOff("I want to go to...")
        )
        precondition(
            !SpeechEndpointRules.looksCutOff("I want to go to")
        )
        precondition(
            SpeechEndpointRules.requiredSilence(
                for: "I want to go to"
            ) == VoiceSessionTiming.hangingUtteranceSilence
        )
        precondition(
            SpeechEndpointRules.requiredSilence(
                for: "Plan a trip to Tokyo next week"
            ) == VoiceSessionTiming.finishedUtteranceSilence
        )
        precondition(
            VoiceRecognitionRules.mergingTranscript(
                existing: "plan a trip to Paris",
                incoming: "for two people"
            ) == "plan a trip to Paris for two people"
        )
        precondition(
            VoiceRecognitionRules.mergingTranscript(
                existing: "plan a trip to Paris",
                incoming: "trip to Paris"
            ) == "plan a trip to Paris"
        )
        precondition(
            VoiceRecognitionRules.spokenContent(
                from: "Plan a trip to Tokyo."
            ) == "plan a trip to tokyo"
        )
        precondition(
            !VoiceRecognitionRules.hasNewSpokenContent(
                previous: "Plan a trip to Tokyo",
                incoming: "Plan a trip to Tokyo."
            )
        )
        precondition(
            VoiceRecognitionRules.hasNewSpokenContent(
                previous: "Plan a trip to Tokyo",
                incoming: "Plan a trip to Tokyo next week"
            )
        )

        precondition(
            VoiceRecognitionRules.isAssistantChatter("no greeting")
        )
        precondition(
            VoiceRecognitionRules.isAssistantChatter("Can you hear me?")
        )
        precondition(
            !VoiceRecognitionRules.hasTravelIntent("no greeting")
        )
        precondition(
            VoiceRecognitionRules.hasTravelIntent(
                "Plan a trip to Tokyo next week"
            )
        )
        precondition(
            VoiceRecognitionRules.hasTravelIntent("Paris")
        )
        precondition(
            VoiceRecognitionRules.hasTravelIntent("Paris next week")
        )
        precondition(
            VoiceRecognitionRules.looksLikeBarePlace("Paris")
        )
        precondition(
            !VoiceRecognitionRules.looksLikeBarePlace("no greeting")
        )
        precondition(
            VoiceRecognitionRules.isPlaybackEcho(
                "what's up what trip are we planning",
                spokenText: "What's up? What trip are we planning?"
            )
        )
        precondition(
            !VoiceRecognitionRules.isPlaybackEcho(
                "plan a trip to Paris",
                spokenText: "What's up? What trip are we planning?"
            )
        )

        precondition(
            SpeechActivityRules.isSpeechFrame(
                SpeechFrameFeatures(
                    speechBandDecibels: -28,
                    rumbleBandDecibels: -40,
                    hissBandDecibels: -38,
                    zeroCrossingRate: 0.08,
                    duration: 0.02
                ),
                noiseFloor: -48
            )
        )
        precondition(
            !SpeechActivityRules.isSpeechFrame(
                SpeechFrameFeatures(
                    speechBandDecibels: -30,
                    rumbleBandDecibels: -18,
                    hissBandDecibels: -40,
                    zeroCrossingRate: 0.04,
                    duration: 0.02
                ),
                noiseFloor: -48
            )
        )
        precondition(
            !SpeechActivityRules.isSpeechFrame(
                SpeechFrameFeatures(
                    speechBandDecibels: -28,
                    rumbleBandDecibels: -40,
                    hissBandDecibels: -20,
                    zeroCrossingRate: 0.4,
                    duration: 0.02
                ),
                noiseFloor: -48
            )
        )

        let detector = SpeechActivityDetector()
        for _ in 0..<6 {
            let decision = detector.consume(
                Self.toneBuffer(frequency: 80, seconds: 0.04)
            )
            precondition(!decision.shouldAppend)
            precondition(!decision.isUtteranceActive)
        }

        detector.reset()
        var heardSpeech = false
        for _ in 0..<8 {
            let decision = detector.consume(Self.voiceLikeBuffer())
            if decision.shouldAppend {
                heardSpeech = true
            }
        }
        precondition(heardSpeech)

        detector.reset()
        var heardNoise = false
        for _ in 0..<8 {
            if detector.consume(Self.noiseBuffer()).shouldAppend {
                heardNoise = true
            }
        }
        precondition(!heardNoise)

        print("Voice phrase and endpoint decisions passed.")
    }

    private static func toneBuffer(
        frequency: Double,
        seconds: Double
    ) -> AVAudioPCMBuffer {
        signalBuffer(seconds: seconds) { index, sampleRate in
            Float(
                0.28 * sin(
                    2 * Double.pi * frequency
                        * Double(index) / sampleRate
                )
            )
        }
    }

    private static func voiceLikeBuffer() -> AVAudioPCMBuffer {
        signalBuffer(seconds: 0.04) { index, sampleRate in
            let time = Double(index) / sampleRate
            return Float(
                0.08 * sin(2 * Double.pi * 180 * time)
                    + 0.22 * sin(2 * Double.pi * 900 * time)
                    + 0.12 * sin(2 * Double.pi * 2_100 * time)
            )
        }
    }

    private static func noiseBuffer() -> AVAudioPCMBuffer {
        signalBuffer(seconds: 0.04) { _, _ in
            Float.random(in: -0.25...0.25)
        }
    }

    private static func signalBuffer(
        seconds: Double,
        sampleRate: Double = 48_000,
        sample: (Int, Double) -> Float
    ) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 1
        )!
        let frames = AVAudioFrameCount(sampleRate * seconds)
        let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: frames
        )!
        buffer.frameLength = frames
        let channel = buffer.floatChannelData![0]
        for index in 0..<Int(frames) {
            channel[index] = sample(index, sampleRate)
        }
        return buffer
    }
}
