import Foundation

enum EarthRenderingConfiguration {
    static let preferredFramesPerSecond = 60
    static let sphereSegmentCount = 128
    static let idleRotationDuration: TimeInterval = 190
    static let transformationDuration: TimeInterval = 0.72
    static let simulatedListeningDuration: TimeInterval = 0.7
    static let simulatedSpeakingDuration: TimeInterval = 5.2
    static let speechAttackDuration: TimeInterval = 0.12
    static let speechReleaseDuration: TimeInterval = 0.68
    static let presentationDuration: TimeInterval = 0.72
    static let worldPresentationDuration: TimeInterval = 0.94
    static let worldZoomDelayFactor: Double = 0.88
    static let worldScale: Float = 3.2
    static let worldVerticalOffset: Float = -3.50
    static let worldFieldOfView: Double = 18
    static let focusedScale: Float = 1.0
    static let focusedVerticalOffset: Float = -0.16
    static let focusedFieldOfView: Double = 42
}
