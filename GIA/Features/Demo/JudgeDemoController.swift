import Foundation
import Observation

enum JudgeDemoState: String, Sendable {
    case inactive
    case active
}

enum JudgeDemoActivationReason: String, Sendable {
    case manual

    var label: String {
        switch self {
        case .manual:
            "Judge demo started manually"
        }
    }
}

@MainActor
@Observable
final class JudgeDemoController {
    private(set) var state: JudgeDemoState = .inactive
    private(set) var activationReason: JudgeDemoActivationReason?
    private(set) var activationSequence = 0
    private(set) var resetSequence = 0

    var isActive: Bool {
        state == .active
    }

    var statusLabel: String {
        activationReason?.label ?? "Offline demo inactive"
    }

    func activate(reason: JudgeDemoActivationReason) {
        state = .active
        activationReason = reason
        activationSequence &+= 1
    }

    func reset() {
        state = .inactive
        activationReason = nil
        resetSequence &+= 1
    }
}
