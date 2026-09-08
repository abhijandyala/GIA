import Foundation

struct GatewayHTTPResponse: Sendable {
    var data: Data
    var response: HTTPURLResponse
}

protocol GatewayTransport: Sendable {
    func send(_ request: URLRequest) async throws
        -> GatewayHTTPResponse
}

struct URLSessionGatewayTransport: GatewayTransport {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func send(_ request: URLRequest) async throws
        -> GatewayHTTPResponse
    {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GatewayClientError.invalidResponse
        }
        return GatewayHTTPResponse(
            data: data,
            response: httpResponse
        )
    }
}

protocol GatewaySleeping: Sendable {
    func sleep(for duration: TimeInterval) async throws
}

struct TaskGatewaySleeper: GatewaySleeping {
    func sleep(for duration: TimeInterval) async throws {
        guard duration > 0 else { return }
        try await Task.sleep(
            nanoseconds: UInt64(duration * 1_000_000_000)
        )
    }
}
