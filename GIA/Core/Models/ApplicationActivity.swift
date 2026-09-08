enum ApplicationActivity: Equatable {
    case active
    case inactive
    case background

    var permitsLiveRendering: Bool {
        self == .active
    }
}
