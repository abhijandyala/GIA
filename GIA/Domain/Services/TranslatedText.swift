import Foundation

enum TranslationContentKind: String, Codable, Sendable {
    case plainText
    case placeDescription
    case address
    case travelMessage
    case identifier
}

struct TranslatedText: Codable, Hashable, Sendable {
    var originalText: String
    var translatedText: String
    var requestedSourceLanguageCode: String?
    var detectedSourceLanguageCode: String?
    var targetLanguageCode: String
    var contentKind: TranslationContentKind
    var protectedTerms: [String]
    var isMachineTranslated: Bool
    var provenance: DataProvenance
}
