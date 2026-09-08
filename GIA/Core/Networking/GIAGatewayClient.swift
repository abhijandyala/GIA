import Foundation

actor GIAGatewayClient {
    private let configuration: GatewayConfiguration
    private let transport: any GatewayTransport
    private let cache: GatewayResponseCache
    private let sleeper: any GatewaySleeping
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        configuration: GatewayConfiguration,
        transport: any GatewayTransport = URLSessionGatewayTransport(),
        cache: GatewayResponseCache = GatewayResponseCache(),
        sleeper: any GatewaySleeping = TaskGatewaySleeper()
    ) {
        self.configuration = configuration
        self.transport = transport
        self.cache = cache
        self.sleeper = sleeper

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            let fractionalFormatter = ISO8601DateFormatter()
            fractionalFormatter.formatOptions = [
                .withInternetDateTime,
                .withFractionalSeconds
            ]
            if let date = fractionalFormatter.date(from: value) {
                return date
            }

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected an ISO 8601 date."
            )
        }
        self.decoder = decoder
    }

    func send<Request, Response>(
        _ body: Request,
        to endpoint: GatewayEndpoint,
        responseType: Response.Type = Response.self
    ) async throws -> Response
    where
        Request: Encodable & Sendable,
        Response: Decodable & Sendable
    {
        let requestData: Data
        do {
            requestData = try encoder.encode(body)
        } catch {
            throw GatewayClientError.encodingFailed
        }

        let cacheKey = GatewayResponseCache.key(
            endpoint: endpoint,
            requestData: requestData
        )
        if
            let cachedData = await cache.response(
                for: cacheKey,
                policy: endpoint.cachePolicy
            )
        {
            return try decode(
                responseType,
                from: cachedData
            )
        }

        let response = try await perform(
            requestData: requestData,
            endpoint: endpoint,
            acceptedContentType: "application/json"
        )
        let value = try decode(responseType, from: response.data)

        await cache.store(
            response.data,
            for: cacheKey,
            policy: endpoint.cachePolicy
        )
        return value
    }

    func sendForData<Request>(
        _ body: Request,
        to endpoint: GatewayEndpoint,
        acceptedContentType: String
    ) async throws -> GeneratedSpeech
    where Request: Encodable & Sendable {
        let requestData: Data
        do {
            requestData = try encoder.encode(body)
        } catch {
            throw GatewayClientError.encodingFailed
        }

        let response = try await perform(
            requestData: requestData,
            endpoint: endpoint,
            acceptedContentType: acceptedContentType
        )
        return GeneratedSpeech(
            audioData: response.data,
            contentType:
                response.response.value(
                    forHTTPHeaderField: "Content-Type"
                ) ?? "application/octet-stream"
        )
    }

    private func decode<Response>(
        _ type: Response.Type,
        from data: Data
    ) throws -> Response
    where Response: Decodable {
        do {
            return try decoder.decode(
                GatewayDataEnvelope<Response>.self,
                from: data
            ).data
        } catch {
            throw GatewayClientError.decodingFailed
        }
    }

    private func perform(
        requestData: Data,
        endpoint: GatewayEndpoint,
        acceptedContentType: String
    ) async throws -> GatewayHTTPResponse {
        let request = try await makeRequest(
            data: requestData,
            endpoint: endpoint,
            acceptedContentType: acceptedContentType
        )
        let policy = configuration.retryPolicy
        var attempt = 1

        while true {
            try Task.checkCancellation()

            do {
                let response = try await transport.send(request)
                if (200..<300).contains(response.response.statusCode) {
                    return response
                }

                let mappedError = mapHTTPError(response)
                if
                    attempt < policy.maximumAttempts,
                    shouldRetry(statusCode: response.response.statusCode)
                {
                    let retryAfter =
                        retryAfterDuration(from: response.response)
                    try await sleeper.sleep(
                        for:
                            retryAfter
                            ?? policy.delay(afterAttempt: attempt)
                    )
                    attempt += 1
                    continue
                }

                throw mappedError
            } catch is CancellationError {
                throw GatewayClientError.cancelled
            } catch let error as GatewayClientError {
                throw error
            } catch let error as URLError {
                if
                    attempt < policy.maximumAttempts,
                    shouldRetry(urlError: error)
                {
                    try await sleeper.sleep(
                        for: policy.delay(afterAttempt: attempt)
                    )
                    attempt += 1
                    continue
                }

                if error.code == .timedOut {
                    throw GatewayClientError.timedOut
                }
                if error.code == .cancelled {
                    throw GatewayClientError.cancelled
                }
                throw GatewayClientError.transportFailure
            } catch {
                throw GatewayClientError.transportFailure
            }
        }
    }

    private func makeRequest(
        data: Data,
        endpoint: GatewayEndpoint,
        acceptedContentType: String
    ) async throws -> URLRequest {
        guard isAllowed(baseURL: configuration.baseURL) else {
            throw GatewayClientError.invalidBaseURL
        }

        let path = endpoint.path.dropFirst()
        let url = configuration.baseURL
            .appendingPathComponent(String(path))
        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval:
                endpoint.requestTimeoutOverride
                ?? configuration.requestTimeout
        )
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )
        request.setValue(
            acceptedContentType,
            forHTTPHeaderField: "Accept"
        )
        request.setValue(
            UUID().uuidString,
            forHTTPHeaderField: "X-Request-ID"
        )

        let token: String?
        do {
            token = try await configuration
                .authorizationProvider
                .bearerToken()
        } catch is CancellationError {
            throw GatewayClientError.cancelled
        } catch {
            throw GatewayClientError.unauthorized
        }

        if let token, !token.isEmpty {
            request.setValue(
                "Bearer \(token)",
                forHTTPHeaderField: "Authorization"
            )
        }

        return request
    }

    private func isAllowed(baseURL: URL) -> Bool {
        guard let scheme = baseURL.scheme?.lowercased() else {
            return false
        }
        if scheme == "https" {
            return true
        }
        guard scheme == "http" else { return false }
        return baseURL.host == "127.0.0.1"
            || baseURL.host == "localhost"
    }

    private func mapHTTPError(
        _ response: GatewayHTTPResponse
    ) -> GatewayClientError {
        let statusCode = response.response.statusCode
        let payload = try? decoder.decode(
            GatewayErrorEnvelope.self,
            from: response.data
        ).error

        switch statusCode {
        case 401:
            return .unauthorized
        case 403:
            return .forbidden
        case 429:
            return .rateLimited(
                retryAfter:
                    retryAfterDuration(from: response.response)
            )
        case 500...599:
            if let payload {
                return .providerUnavailable(
                    code: payload.code,
                    message: payload.message
                )
            }
            return .serverFailure
        default:
            if let payload {
                return .providerUnavailable(
                    code: payload.code,
                    message: payload.message
                )
            }
            return .invalidResponse
        }
    }

    private func shouldRetry(statusCode: Int) -> Bool {
        statusCode == 429
            || statusCode == 502
            || statusCode == 503
            || statusCode == 504
    }

    private func shouldRetry(urlError: URLError) -> Bool {
        switch urlError.code {
        case
            .timedOut,
            .networkConnectionLost,
            .notConnectedToInternet,
            .cannotConnectToHost,
            .dnsLookupFailed:
            true
        default:
            false
        }
    }

    private func retryAfterDuration(
        from response: HTTPURLResponse
    ) -> TimeInterval? {
        guard
            let value = response.value(
                forHTTPHeaderField: "Retry-After"
            ),
            let seconds = TimeInterval(value),
            seconds >= 0
        else {
            return nil
        }
        return min(seconds, configuration.retryPolicy.maximumDelay)
    }
}
