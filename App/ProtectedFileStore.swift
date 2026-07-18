import Foundation

enum ProtectedFileStore {
    private static let directoryName = "TempoProtectedStore"

    static func data(for key: String) -> Data? {
        guard let url = try? fileURL(for: key) else { return nil }
        return try? Data(contentsOf: url)
    }

    @discardableResult
    static func store(_ data: Data, for key: String) -> Bool {
        do {
            let url = try fileURL(for: key)
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    static func removeAll() -> Bool {
        do {
            let directory = try directoryURL(create: false)
            if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
            return true
        } catch {
            return false
        }
    }

    private static func fileURL(for key: String) throws -> URL {
        let safeName = key.replacingOccurrences(of: ".", with: "-") + ".json"
        return try directoryURL(create: true).appendingPathComponent(safeName, isDirectory: false)
    }

    private static func directoryURL(create: Bool) throws -> URL {
        let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: create)
        let directory = root.appendingPathComponent(directoryName, isDirectory: true)
        if create && !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.complete])
        }
        return directory
    }
}
