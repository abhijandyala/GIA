import Foundation

private struct FixtureRequest: Codable, Hashable, Sendable {
    var query: String
}

private struct FixtureResponse: Codable, Equatable, Sendable {
    var value: String
}

private struct StaticAuthorizationProvider:
    GatewayAuthorizationProviding
{
    var token: String?

    func bearerToken() async throws -> String? {
        token
    }
}

private actor FixtureTransport: GatewayTransport {
    private var responses: [GatewayHTTPResponse]
    private var requests: [URLRequest] = []

    init(responses: [GatewayHTTPResponse]) {
        self.responses = responses
    }

    func send(_ request: URLRequest) async throws
        -> GatewayHTTPResponse
    {
        requests.append(request)
        guard !responses.isEmpty else {
            throw URLError(.cannotConnectToHost)
        }
        return responses.removeFirst()
    }

    func requestCount() -> Int {
        requests.count
    }

    func firstRequest() -> URLRequest? {
        requests.first
    }
}

private actor FixtureSleeper: GatewaySleeping {
    private var durations: [TimeInterval] = []

    func sleep(for duration: TimeInterval) async throws {
        durations.append(duration)
    }

    func recordedDurations() -> [TimeInterval] {
        durations
    }
}

private struct CancellingSleeper: GatewaySleeping {
    func sleep(for duration: TimeInterval) async throws {
        throw CancellationError()
    }
}

@main
enum GatewayNetworkingVerificationMain {
    static func main() async throws {
        let baseURL = URL(string: "https://gateway.example")!
        let success = makeResponse(
            status: 200,
            body: #"{"data":{"value":"Lisbon"}}"#
        )
        let transport = FixtureTransport(responses: [success])
        let sleeper = FixtureSleeper()
        let cacheDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let cache = GatewayResponseCache(
            directoryURL: cacheDirectory
        )
        let client = GIAGatewayClient(
            configuration: GatewayConfiguration(
                baseURL: baseURL,
                authorizationProvider:
                    StaticAuthorizationProvider(token: "session-token")
            ),
            transport: transport,
            cache: cache,
            sleeper: sleeper
        )
        let request = FixtureRequest(query: "Lisbon")
        let first: FixtureResponse = try await client.send(
            request,
            to: .places
        )
        let second: FixtureResponse = try await client.send(
            request,
            to: .places
        )

        precondition(first == FixtureResponse(value: "Lisbon"))
        precondition(second == first)
        let cachedRequestCount = await transport.requestCount()
        precondition(cachedRequestCount == 1)

        let sentRequest = await transport.firstRequest()
        precondition(
            sentRequest?.url?.path == "/v1/search/places"
        )
        precondition(
            sentRequest?.value(
                forHTTPHeaderField: "Authorization"
            ) == "Bearer session-token"
        )
        precondition(
            sentRequest?.value(
                forHTTPHeaderField: "X-Request-ID"
            )?.isEmpty == false
        )

        let retryTransport = FixtureTransport(
            responses: [
                makeResponse(
                    status: 429,
                    body:
                        #"{"error":{"code":"rate_limit_exceeded","message":"Wait"}}"#,
                    headers: ["Retry-After": "1"]
                ),
                success
            ]
        )
        let retrySleeper = FixtureSleeper()
        let retryClient = GIAGatewayClient(
            configuration: GatewayConfiguration(
                baseURL: baseURL,
                authorizationProvider:
                    StaticAuthorizationProvider(token: "session-token")
            ),
            transport: retryTransport,
            cache: GatewayResponseCache(
                directoryURL:
                    cacheDirectory.appendingPathComponent("retry")
            ),
            sleeper: retrySleeper
        )
        let retried: FixtureResponse = try await retryClient.send(
            FixtureRequest(query: "Porto"),
            to: .places
        )

        precondition(retried.value == "Lisbon")
        let retryRequestCount = await retryTransport.requestCount()
        let retryDurations =
            await retrySleeper.recordedDurations()
        precondition(retryRequestCount == 2)
        precondition(retryDurations == [1])

        let providerErrorClient = GIAGatewayClient(
            configuration: GatewayConfiguration(
                baseURL: baseURL,
                retryPolicy: GatewayRetryPolicy(
                    maximumAttempts: 1,
                    baseDelay: 0,
                    maximumDelay: 0
                ),
                authorizationProvider:
                    StaticAuthorizationProvider(token: "session-token")
            ),
            transport: FixtureTransport(
                responses: [
                    makeResponse(
                        status: 503,
                        body:
                            #"{"error":{"code":"provider_unavailable","message":"Try again later"}}"#
                    )
                ]
            ),
            cache: GatewayResponseCache(
                directoryURL:
                    cacheDirectory.appendingPathComponent("error")
            )
        )
        do {
            let _: FixtureResponse = try await providerErrorClient.send(
                FixtureRequest(query: "Error"),
                to: .places
            )
            fatalError("Provider failure was accepted.")
        } catch let error as GatewayClientError {
            precondition(
                error
                    == .providerUnavailable(
                        code: "provider_unavailable",
                        message: "Try again later"
                    )
            )
        }

        let cancellationClient = GIAGatewayClient(
            configuration: GatewayConfiguration(
                baseURL: baseURL,
                authorizationProvider:
                    StaticAuthorizationProvider(token: "session-token")
            ),
            transport: FixtureTransport(
                responses: [
                    makeResponse(
                        status: 429,
                        body:
                            #"{"error":{"code":"rate_limit_exceeded","message":"Wait"}}"#
                    )
                ]
            ),
            cache: GatewayResponseCache(
                directoryURL:
                    cacheDirectory.appendingPathComponent("cancel")
            ),
            sleeper: CancellingSleeper()
        )
        do {
            let _: FixtureResponse = try await cancellationClient.send(
                FixtureRequest(query: "Cancel"),
                to: .places
            )
            fatalError("Cancelled retry was accepted.")
        } catch let error as GatewayClientError {
            precondition(error == .cancelled)
        }

        let audio = Data([0x49, 0x44, 0x33])
        let audioClient = GIAGatewayClient(
            configuration: GatewayConfiguration(
                baseURL: baseURL,
                authorizationProvider:
                    StaticAuthorizationProvider(token: "session-token")
            ),
            transport: FixtureTransport(
                responses: [
                    makeResponse(
                        status: 200,
                        data: audio,
                        headers: ["Content-Type": "audio/mpeg"]
                    )
                ]
            ),
            cache: GatewayResponseCache(
                directoryURL:
                    cacheDirectory.appendingPathComponent("audio")
            )
        )
        let generated = try await audioClient.sendForData(
            FixtureRequest(query: "Hello"),
            to: .speech,
            acceptedContentType: "audio/mpeg"
        )
        precondition(generated.audioData == audio)
        precondition(generated.contentType == "audio/mpeg")

        let directCache = GatewayResponseCache(
            directoryURL:
                cacheDirectory.appendingPathComponent("disk")
        )
        let cacheData = Data("cached".utf8)
        let cacheKey = GatewayResponseCache.key(
            endpoint: .hotels,
            requestData: Data("private query".utf8)
        )
        precondition(!cacheKey.contains("private"))
        await directCache.store(
            cacheData,
            for: cacheKey,
            policy: .memoryAndDisk(timeToLive: 60)
        )
        let reloadedCache = GatewayResponseCache(
            directoryURL:
                cacheDirectory.appendingPathComponent("disk")
        )
        let reloadedData = await reloadedCache.response(
            for: cacheKey,
            policy: .memoryAndDisk(timeToLive: 60)
        )
        precondition(reloadedData == cacheData)
        let expiredData = await reloadedCache.response(
            for: cacheKey,
            policy: .memoryAndDisk(timeToLive: 60),
            now: Date().addingTimeInterval(61)
        )
        precondition(expiredData == nil)

        await cache.clear()
        await directCache.clear()
        try? FileManager.default.removeItem(at: cacheDirectory)

        print("Gateway networking behavior passed.")
    }

    private static func makeResponse(
        status: Int,
        body: String,
        headers: [String: String] = [:]
    ) -> GatewayHTTPResponse {
        makeResponse(
            status: status,
            data: Data(body.utf8),
            headers: headers
        )
    }

    private static func makeResponse(
        status: Int,
        data: Data,
        headers: [String: String] = [:]
    ) -> GatewayHTTPResponse {
        let response = HTTPURLResponse(
            url: URL(string: "https://gateway.example")!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!
        return GatewayHTTPResponse(data: data, response: response)
    }
}
