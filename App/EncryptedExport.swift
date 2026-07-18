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
        let format = "tempo-encrypted-export"
        let version = 1
        let salt: String
        let payload: String
    }

    enum ExportError: Error { case weakPassword, encryptionFailed }

    static func encrypt(_ plaintext: Data, password: String) throws -> Data {
        guard password.count >= 8 else { throw ExportError.weakPassword }
        var salt = Data(count: 16)
        let status = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        guard status == errSecSuccess else { throw ExportError.encryptionFailed }

        var material = Data(password.utf8) + salt
        for _ in 0..<50_000 { material = Data(SHA256.hash(data: material)) }
        let key = SymmetricKey(data: material)
        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealed.combined else { throw ExportError.encryptionFailed }
        return try JSONEncoder().encode(Envelope(salt: salt.base64EncodedString(), payload: combined.base64EncodedString()))
    }
}
