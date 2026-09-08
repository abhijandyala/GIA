enum LocationContext: Equatable {
    case space

    var primaryLabel: String {
        switch self {
        case .space:
            "SPACE"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .space:
            "Space"
        }
    }
}
