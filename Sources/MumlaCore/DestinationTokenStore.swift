import CryptoKit
import Foundation
import Security

public protocol DestinationTokenStoring: Sendable {
    func save(_ token: String, for url: URL) throws
    func read(for url: URL) throws -> String?
    func delete(for url: URL) throws
}

public enum DestinationTokenError: Error, Equatable, Sendable {
    case invalidValue, unavailable(OSStatus)
}

public final class DestinationTokenStore: DestinationTokenStoring, @unchecked Sendable {
    private let service: String
    public init(service: String = "app.mumla.transcript-destination") { self.service = service }

    public static func accepts(_ token: String) -> Bool {
        !token.isEmpty && token.utf8.count <= 16_384
            && !token.unicodeScalars.contains { CharacterSet.whitespacesAndNewlines.contains($0) || CharacterSet.controlCharacters.contains($0) }
    }

    private func query(_ url: URL) -> [String: Any] {
        let account = SHA256.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
        return [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                kSecAttrAccount as String: account, kSecAttrSynchronizable as String: false]
    }

    public func save(_ token: String, for url: URL) throws {
        guard TranscriptDestination.accepts(url), Self.accepts(token) else { throw DestinationTokenError.invalidValue }
        let base = query(url)
        var attributes: [String: Any] = [kSecValueData as String: Data(token.utf8)]
        #if os(iOS) || os(watchOS)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        #endif
        let update = SecItemUpdate(base as CFDictionary, attributes as CFDictionary)
        if update == errSecSuccess { return }
        guard update == errSecItemNotFound else { throw DestinationTokenError.unavailable(update) }
        let status = SecItemAdd(base.merging(attributes) { _, new in new } as CFDictionary, nil)
        guard status == errSecSuccess else { throw DestinationTokenError.unavailable(status) }
    }

    public func read(for url: URL) throws -> String? {
        var values = query(url); values[kSecReturnData as String] = true; values[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(values as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw DestinationTokenError.unavailable(status) }
        guard let data = item as? Data, let token = String(data: data, encoding: .utf8), Self.accepts(token) else {
            throw DestinationTokenError.invalidValue
        }
        return token
    }

    public func delete(for url: URL) throws {
        let status = SecItemDelete(query(url) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw DestinationTokenError.unavailable(status) }
    }
}
