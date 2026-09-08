import CoreGraphics
import Foundation

@main
enum QualityPolicyVerificationMain {
    static func main() {
        precondition(GIAQualityPolicy.minimumTouchTarget >= 44)
        precondition(
            GIAQualityPolicy.shouldRunContinuousAnimation(
                isVisible: true,
                reduceMotion: false
            )
        )
        precondition(
            !GIAQualityPolicy.shouldRunContinuousAnimation(
                isVisible: false,
                reduceMotion: false
            )
        )
        precondition(
            !GIAQualityPolicy.shouldRunContinuousAnimation(
                isVisible: true,
                reduceMotion: true
            )
        )
        precondition(
            GIAQualityPolicy.shouldRenderEarth(
                mapIsActive: true,
                reduceMotion: false
            )
        )
        precondition(
            !GIAQualityPolicy.shouldRenderEarth(
                mapIsActive: false,
                reduceMotion: false
            )
        )
        precondition(
            GIAQualityPolicy.shouldRenderEarth(
                mapIsActive: true,
                reduceMotion: true
            )
        )
        precondition(
            GIAQualityPolicy.shouldUseVerticalLayout(
                isAccessibilityTextSize: true,
                availableWidth: 430
            )
        )
        precondition(
            GIAQualityPolicy.shouldUseVerticalLayout(
                isAccessibilityTextSize: false,
                availableWidth: 320
            )
        )
        precondition(
            !GIAQualityPolicy.shouldUseVerticalLayout(
                isAccessibilityTextSize: false,
                availableWidth: 390
            )
        )
        precondition(
            GIAQualityPolicy.preferredEarthFrameRate(
                lowPowerMode: false,
                standardFrameRate: 60
            ) == 60
        )
        precondition(
            GIAQualityPolicy.preferredEarthFrameRate(
                lowPowerMode: true,
                standardFrameRate: 60
            ) == 30
        )

        print("Accessibility and rendering quality policy passed.")
    }
}
