import Foundation
import Network
import Observation

enum GIAConnectivityState: String, Sendable {
    case unknown
    case online
    case offline
}

@MainActor
@Observable
final class GIAConnectivityMonitor {
    private(set) var state: GIAConnectivityState = .unknown

    @ObservationIgnored
    private let monitor: NWPathMonitor?
    @ObservationIgnored
    private let queue = DispatchQueue(
        label: "com.gia.connectivity",
        qos: .utility
    )

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.environment[
            "GIA_DEBUG_OFFLINE"
        ] == "1" {
            state = .offline
            monitor = nil
            return
        }
        #endif

        let monitor = NWPathMonitor()
        self.monitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            let updatedState: GIAConnectivityState =
                path.status == .satisfied ? .online : .offline
            Task { @MainActor [weak self] in
                self?.state = updatedState
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor?.cancel()
    }
}
