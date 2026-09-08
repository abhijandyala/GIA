import Foundation

private struct TranslationContractAuthorization:
    GatewayAuthorizationProviding
{
    func bearerToken() async throws -> String? {
        "fixture-session"
    }
}

private actor TranslationContractTransport: GatewayTransport {
    private(set) var count = 0
    let response: GatewayHTTPResponse

    init(response: GatewayHTTPResponse) {
        self.response = response
    }

    func send(_ request: URLRequest) async throws
        -> GatewayHTTPResponse
    {
        count += 1
        precondition(request.url?.path == "/v1/translation")
        return response
    }
}

@main
enum TranslationContractVerificationMain {
    static func main() async throws {
        let json = """
        {
          "data": {
            "originalText": "Meet at Museu Nacional on 2027-06-10.",
            "translatedText": "Encuentro en Museu Nacional el 2027-06-10.",
            "requestedSourceLanguageCode": "en",
            "detectedSourceLanguageCode": "en",
            "targetLanguageCode": "es",
            "contentKind": "travelMessage",
            "protectedTerms": [
              "Museu Nacional",
              "2027-06-10"
            ],
            "isMachineTranslated": true,
            "provenance": {
              "provider": "google_translation",
              "origin": "live",
              "retrievedAt": "2026-09-06T08:00:00.000Z",
              "expiresAt": "2026-09-07T08:00:00.000Z",
              "sourceURL": "https://cloud.google.com/translate/docs"
            }
          }
        }
        """
        let response = HTTPURLResponse(
            url: URL(string: "https://gateway.example/v1/translation")!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": "application/json"
            ]
        )!
        let transport = TranslationContractTransport(
            response: GatewayHTTPResponse(
                data: Data(json.utf8),
                response: response
            )
        )
        let cacheDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let client = GIAGatewayClient(
            configuration: GatewayConfiguration(
                baseURL: URL(string: "https://gateway.example")!,
                authorizationProvider:
                    TranslationContractAuthorization()
            ),
            transport: transport,
            cache: GatewayResponseCache(
                directoryURL: cacheDirectory
            )
        )
        let service = GatewayTravelService(client: client)
        let criteria = TranslationCriteria(
            text: "Meet at Museu Nacional on 2027-06-10.",
            sourceLanguageCode: "en",
            targetLanguageCode: "es",
            contentKind: .travelMessage,
            protectedTerms: ["Museu Nacional"]
        )
        let first = try await service.translate(
            matching: criteria
        )
        let second = try await service.translate(
            matching: criteria
        )

        precondition(first == second)
        precondition(first.originalText.contains("Museu Nacional"))
        precondition(first.translatedText.contains("Museu Nacional"))
        precondition(first.translatedText.contains("2027-06-10"))
        precondition(first.isMachineTranslated)
        precondition(first.contentKind == .travelMessage)
        precondition(first.protectedTerms.count == 2)
        precondition(
            first.provenance.provider.rawValue
                == "google_translation"
        )
        precondition(first.provenance.origin == .live)
        let requestCount = await transport.count
        precondition(requestCount == 1)
        precondition(
            !FileManager.default.fileExists(
                atPath: cacheDirectory.path
            )
        )

        print("Translation gateway contract passed.")
    }
}
