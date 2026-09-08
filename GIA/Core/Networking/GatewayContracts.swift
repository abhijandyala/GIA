import Foundation

enum GatewayEndpoint: String, CaseIterable, Sendable {
    case assistantResponse
    case interpretReply
    case location
    case plan
    case flights
    case flightReturn
    case hotels
    case places
    case events
    case route
    case weather
    case speech
    case translation

    var path: String {
        switch self {
        case .assistantResponse:
            "/v1/respond"
        case .interpretReply:
            "/v1/interpret-reply"
        case .location:
            "/v1/resolve/location"
        case .plan:
            "/v1/plan"
        case .flights:
            "/v1/search/flights"
        case .flightReturn:
            "/v1/search/flights/return"
        case .hotels:
            "/v1/search/hotels"
        case .places:
            "/v1/search/places"
        case .events:
            "/v1/search/events"
        case .route:
            "/v1/route"
        case .weather:
            "/v1/weather"
        case .speech:
            "/v1/speech"
        case .translation:
            "/v1/translation"
        }
    }

    var cachePolicy: GatewayCachePolicy {
        switch self {
        case .location:
            .memoryAndDisk(timeToLive: 86_400)
        case .flights:
            .memoryAndDisk(timeToLive: 180)
        case .hotels:
            .memoryAndDisk(timeToLive: 300)
        case .places:
            .memoryAndDisk(timeToLive: 21_600)
        case .events:
            .memoryAndDisk(timeToLive: 1_800)
        case .route:
            .memoryAndDisk(timeToLive: 900)
        case .weather:
            .memoryAndDisk(timeToLive: 900)
        case .translation:
            .memory(timeToLive: 86_400)
        case .assistantResponse, .interpretReply, .plan, .flightReturn, .speech:
            .none
        }
    }

    var requestTimeoutOverride: TimeInterval? {
        switch self {
        case .flights, .flightReturn, .hotels, .events:
            20
        case .plan:
            40
        case .assistantResponse:
            12
        case .interpretReply:
            4
        default:
            nil
        }
    }
}

enum GatewayCachePolicy: Sendable {
    case none
    case memory(timeToLive: TimeInterval)
    case memoryAndDisk(timeToLive: TimeInterval)

    var timeToLive: TimeInterval? {
        switch self {
        case .none:
            nil
        case .memory(let timeToLive),
             .memoryAndDisk(let timeToLive):
            timeToLive
        }
    }

    var allowsDisk: Bool {
        if case .memoryAndDisk = self {
            return true
        }
        return false
    }
}

struct GatewayRetryPolicy: Sendable {
    var maximumAttempts: Int
    var baseDelay: TimeInterval
    var maximumDelay: TimeInterval

    static let standard = GatewayRetryPolicy(
        maximumAttempts: 3,
        baseDelay: 0.35,
        maximumDelay: 2
    )

    func delay(afterAttempt attempt: Int) -> TimeInterval {
        min(
            baseDelay * pow(2, Double(max(attempt - 1, 0))),
            maximumDelay
        )
    }
}

struct GatewayConfiguration: Sendable {
    var baseURL: URL
    var requestTimeout: TimeInterval
    var retryPolicy: GatewayRetryPolicy
    var authorizationProvider: any GatewayAuthorizationProviding

    init(
        baseURL: URL,
        requestTimeout: TimeInterval = 15,
        retryPolicy: GatewayRetryPolicy = .standard,
        authorizationProvider: any GatewayAuthorizationProviding
    ) {
        self.baseURL = baseURL
        self.requestTimeout = requestTimeout
        self.retryPolicy = retryPolicy
        self.authorizationProvider = authorizationProvider
    }
}

protocol GatewayAuthorizationProviding: Sendable {
    func bearerToken() async throws -> String?
}

struct AnonymousGatewayAuthorizationProvider:
    GatewayAuthorizationProviding
{
    func bearerToken() async throws -> String? {
        nil
    }
}

actor EphemeralGatewayAuthorizationProvider:
    GatewayAuthorizationProviding
{
    private var token: String?

    init(token: String? = nil) {
        self.token = token
    }

    func update(token: String?) {
        self.token = token
    }

    func bearerToken() async throws -> String? {
        token
    }
}

#if DEBUG
struct DebugEnvironmentGatewayAuthorizationProvider:
    GatewayAuthorizationProviding
{
    func bearerToken() async throws -> String? {
        ProcessInfo.processInfo.environment[
            "GIA_GATEWAY_ACCESS_TOKEN"
        ] ?? "gia-local-development"
    }
}
#endif

struct GatewayDataEnvelope<Value: Decodable>: Decodable {
    var data: Value
}

struct GatewayErrorEnvelope: Decodable {
    var error: GatewayErrorPayload
}

struct GatewayErrorPayload: Decodable, Equatable {
    var code: String
    var message: String
}

enum GatewayClientError: Error, Equatable, Sendable {
    case invalidBaseURL
    case invalidResponse
    case encodingFailed
    case decodingFailed
    case unauthorized
    case forbidden
    case rateLimited(retryAfter: TimeInterval?)
    case providerUnavailable(code: String, message: String)
    case serverFailure
    case transportFailure
    case timedOut
    case cancelled
}
