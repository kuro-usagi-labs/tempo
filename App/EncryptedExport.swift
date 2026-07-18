import CryptoKit
import Foundation
import Security
import SwiftUI
import UniformTypeIdentifiers

struct TempoExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }
    var data: Data

    init(data: Data = Data()) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

enum EncryptedExport {
    private struct Envelope: Codable {
        let format: String
        let version: Int
        let salt: String
        let payload: String

        init(salt: String, payload: String) {
            format = "tempo-encrypted-export"
            version = 1
            self.salt = salt
            self.payload = payload
        }
    }

    enum ExportError: Error { case weakPassword, invalidFormat, encryptionFailed, decryptionFailed }

    static func encrypt(_ plaintext: Data, password: String) throws -> Data {
        guard password.count >= 8 else { throw ExportError.weakPassword }
        var salt = Data(count: 16)
        let status = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        guard status == errSecSuccess else { throw ExportError.encryptionFailed }

        let key = derivedKey(password: password, salt: salt)
        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealed.combined else { throw ExportError.encryptionFailed }
        return try JSONEncoder().encode(Envelope(salt: salt.base64EncodedString(), payload: combined.base64EncodedString()))
    }

    static func decrypt(_ exportedData: Data, password: String) throws -> Data {
        guard password.count >= 8 else { throw ExportError.weakPassword }
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: exportedData),
              envelope.format == "tempo-encrypted-export", envelope.version == 1,
              let salt = Data(base64Encoded: envelope.salt),
              let payload = Data(base64Encoded: envelope.payload),
              let sealed = try? AES.GCM.SealedBox(combined: payload)
        else { throw ExportError.invalidFormat }
        do {
            return try AES.GCM.open(sealed, using: derivedKey(password: password, salt: salt))
        } catch {
            throw ExportError.decryptionFailed
        }
    }

    private static func derivedKey(password: String, salt: Data) -> SymmetricKey {
        var material = Data(password.utf8) + salt
        for _ in 0..<50_000 { material = Data(SHA256.hash(data: material)) }
        return SymmetricKey(data: material)
    }
}
