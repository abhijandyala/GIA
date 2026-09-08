import CryptoKit
import Foundation

actor GatewayResponseCache {
    private struct Entry: Codable {
        var data: Data
        var expiresAt: Date
        var storedAt: Date?
    }

    private var memory: [String: Entry] = [:]
    private let maximumMemoryEntryCount = 64
    private let directoryURL: URL
    private let fileManager: FileManager

    init(
        directoryURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager

        if let directoryURL {
            self.directoryURL = directoryURL
        } else {
            let root = fileManager.urls(
                for: .cachesDirectory,
                in: .userDomainMask
            ).first ?? fileManager.temporaryDirectory
            self.directoryURL = root
                .appendingPathComponent("GIA", isDirectory: true)
                .appendingPathComponent(
                    "GatewayResponses",
                    isDirectory: true
                )
        }
    }

    static func key(
        endpoint: GatewayEndpoint,
        requestData: Data
    ) -> String {
        var material = Data(endpoint.rawValue.utf8)
        material.append(0)
        material.append(requestData)
        let digest = SHA256.hash(data: material)
        return digest.map {
            String(format: "%02x", $0)
        }.joined()
    }

    func response(
        for key: String,
        policy: GatewayCachePolicy,
        now: Date = Date()
    ) -> Data? {
        guard policy.timeToLive != nil else { return nil }

        if let entry = memory[key] {
            guard entry.expiresAt > now else {
                memory[key] = nil
                removeDiskEntry(for: key)
                return nil
            }
            return entry.data
        }

        guard policy.allowsDisk else { return nil }
        guard
            let data = try? Data(contentsOf: fileURL(for: key)),
            let entry = try? JSONDecoder().decode(
                Entry.self,
                from: data
            )
        else {
            return nil
        }

        guard entry.expiresAt > now else {
            removeDiskEntry(for: key)
            return nil
        }

        memory[key] = entry
        return entry.data
    }

    func store(
        _ data: Data,
        for key: String,
        policy: GatewayCachePolicy,
        now: Date = Date()
    ) {
        guard let timeToLive = policy.timeToLive else { return }

        let entry = Entry(
            data: data,
            expiresAt: now.addingTimeInterval(timeToLive),
            storedAt: now
        )
        evictMemoryEntriesIfNeeded(at: now)
        memory[key] = entry

        guard policy.allowsDisk else { return }

        do {
            try fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
            let encoded = try JSONEncoder().encode(entry)
            let url = fileURL(for: key)
            try encoded.write(to: url, options: [.atomic])

            #if os(iOS)
            try fileManager.setAttributes(
                [
                    .protectionKey:
                        FileProtectionType.completeUntilFirstUserAuthentication
                ],
                ofItemAtPath: url.path
            )
            #endif
        } catch {
            return
        }
    }

    func clear() {
        memory.removeAll()
        try? fileManager.removeItem(at: directoryURL)
    }

    private func fileURL(for key: String) -> URL {
        directoryURL.appendingPathComponent(
            "\(key).json",
            isDirectory: false
        )
    }

    private func removeDiskEntry(for key: String) {
        try? fileManager.removeItem(at: fileURL(for: key))
    }

    private func evictMemoryEntriesIfNeeded(at now: Date) {
        memory = memory.filter { $0.value.expiresAt > now }
        while memory.count >= maximumMemoryEntryCount {
            guard
                let oldestKey = memory.min(
                    by: {
                        ($0.value.storedAt ?? .distantPast)
                            < ($1.value.storedAt ?? .distantPast)
                    }
                )?.key
            else {
                break
            }
            memory[oldestKey] = nil
        }
    }
}
