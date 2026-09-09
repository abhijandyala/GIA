import Foundation

enum HostWakePhrase {
    static let contextualStrings = [
        "GIA",
        "Hey GIA",
        "Hi GIA",
        "Okay GIA",
        "OK GIA",
        "Yo GIA",
        "Hello GIA",
        "G I A",
        "Gee eye ay",
        "Gee ay",
        "Jia",
        "Hey Jia"
    ]

    static func containsWakePhrase(_ transcript: String) -> Bool {
        let words = words(in: transcript)
        guard !words.isEmpty else { return false }

        if words.contains(where: isCollapsedWakePhrase) {
            return true
        }

        if words.count >= 2 {
            for index in 1..<words.count {
                let previous = words[index - 1]
                let current = words[index]
                if prefixes.contains(previous), isWakeName(current) {
                    return true
                }
                if
                    previous == "gee",
                    geeFollowers.contains(current)
                {
                    return true
                }
                if
                    current == "gee",
                    index + 1 < words.count,
                    geeFollowers.contains(words[index + 1])
                {
                    return true
                }
                if
                    prefixes.contains(previous),
                    misheardNames.contains(current)
                {
                    return true
                }
            }
        }

        guard words.count >= 3 else { return false }
        for index in 0...(words.count - 3) {
            if spelledLetters.contains(
                Array(words[index...(index + 2)])
            ) {
                return true
            }
        }
        return false
    }

    private static let prefixes: Set<String> = [
        "hey",
        "hi",
        "okay",
        "ok",
        "yo",
        "hello"
    ]

    private static let names: Set<String> = [
        "gia",
        "giah",
        "jia",
        "jeea",
        "geea",
        "geeuh",
        "jaia",
        "gya",
        "chia",
        "gigi",
        "giya"
    ]

    private static let geeFollowers: Set<String> = [
        "ay",
        "ah",
        "uh",
        "a",
        "eye",
        "i"
    ]

    private static let misheardNames: Set<String> = [
        "yeah",
        "yea",
        "yah"
    ]

    private static let spelledLetters: Set<[String]> = [
        ["g", "i", "a"],
        ["gee", "eye", "ay"],
        ["gee", "i", "a"],
        ["gee", "eye", "a"]
    ]

    private static func words(in transcript: String) -> [String] {
        transcript
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "en_US")
            )
            .lowercased()
            .split(whereSeparator: { !$0.isLetter })
            .map(String.init)
    }

    private static func isWakeName(_ word: String) -> Bool {
        names.contains(word)
    }

    private static func isCollapsedWakePhrase(_ word: String) -> Bool {
        for prefix in prefixes where word.hasPrefix(prefix) {
            let remainder = String(word.dropFirst(prefix.count))
            if isWakeName(remainder) {
                return true
            }
        }
        return false
    }
}
