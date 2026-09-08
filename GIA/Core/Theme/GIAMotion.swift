import SwiftUI

enum GIAMotion {
    static let quickDuration: TimeInterval = 0.2
    static let standardDuration: TimeInterval = 0.35

    static var quick: Animation {
        .easeOut(duration: quickDuration)
    }

    static var standard: Animation {
        .smooth(duration: standardDuration)
    }
}
