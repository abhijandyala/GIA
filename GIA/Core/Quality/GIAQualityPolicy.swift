import CoreGraphics

enum GIAQualityPolicy {
    static let minimumTouchTarget: CGFloat = 44

    static func shouldRunContinuousAnimation(
        isVisible: Bool,
        reduceMotion: Bool
    ) -> Bool {
        isVisible && !reduceMotion
    }

    static func shouldRenderEarth(
        mapIsActive: Bool,
        reduceMotion _: Bool
    ) -> Bool {
        mapIsActive
    }

    static func shouldUseVerticalLayout(
        isAccessibilityTextSize: Bool,
        availableWidth: CGFloat
    ) -> Bool {
        isAccessibilityTextSize || availableWidth < 340
    }

    static func preferredEarthFrameRate(
        lowPowerMode: Bool,
        standardFrameRate: Int
    ) -> Int {
        lowPowerMode
            ? 30
            : standardFrameRate
    }
}
