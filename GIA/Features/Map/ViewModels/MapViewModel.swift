import Observation

@MainActor
@Observable
final class MapViewModel {
    private(set) var locationContext: LocationContext = .space
    private(set) var isEarthActive = true

    func setEarthActive(_ isActive: Bool) {
        isEarthActive = isActive
    }
}
