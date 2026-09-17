//
//  WebAccessControl.swift
//  Keepshire
//

import Foundation

enum WebDownloadTarget: Equatable {
    case file(UUID)
    case folder(UUID)
    /// Several picks zipped together, because browsers refuse a burst of separate downloads.
    case selection(files: [UUID], folders: [UUID])
}

enum WebAuthDecision: Equatable {
    case allow
    case unauthorized
    case exportSessionRequired
}

/// Session credentials for the LAN server: a token that every request must carry, a
/// time-boxed export session that downloads require, and one-shot download tickets.
///
/// Callbacks arrive on the listener's queue, so all state is guarded by a lock.
final class WebAccessControl {
    struct Ticket: Equatable {
        let target: WebDownloadTarget
        let client: String
        let expiresAt: Date
    }

    static let ticketLifetime: TimeInterval = 60
    static let exportSessionLifetime: TimeInterval = 10 * 60

    static let maxPairingAttempts = 5

    private let lock = NSLock()
    private var token: String?
    private var pairing: String?
    private var pairingAttempts = 0
    private var exportSessionExpiry: Date?
    private var tickets: [String: Ticket] = [:]

    // MARK: - Session token

    /// Issues a fresh token and pairing code, invalidating every link and ticket handed out earlier.
    @discardableResult
    func rotateToken() -> String {
        let newToken = Self.randomToken()
        lock.lock()
        token = newToken
        pairing = Self.randomPairingCode()
        pairingAttempts = 0
        tickets.removeAll()
        exportSessionExpiry = nil
        lock.unlock()
        return newToken
    }

    var pairingCode: String? {
        lock.lock()
        defer { lock.unlock() }
        return pairing
    }

    /// Exchanges the short code shown in the app for the session token. Attempts are capped
    /// so the code cannot be guessed by a device on the same Wi-Fi.
    func redeemPairingCode(_ code: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        guard let pairing, let token, pairingAttempts < Self.maxPairingAttempts else { return nil }
        pairingAttempts += 1
        guard Self.constantTimeEquals(code.trimmingCharacters(in: .whitespaces), pairing) else { return nil }
        pairingAttempts = 0
        return token
    }

    var isPairingLocked: Bool {
        lock.lock()
        defer { lock.unlock() }
        return pairingAttempts >= Self.maxPairingAttempts
    }

    var currentToken: String? {
        lock.lock()
        defer { lock.unlock() }
        return token
    }

    func invalidate() {
        lock.lock()
        token = nil
        pairing = nil
        pairingAttempts = 0
        exportSessionExpiry = nil
        tickets.removeAll()
        lock.unlock()
    }

    // MARK: - Export session

    /// Opens the window in which downloads are allowed. Callers gate this behind biometrics.
    func beginExportSession(now: Date = Date(), duration: TimeInterval = exportSessionLifetime) -> Date {
        let expiry = now.addingTimeInterval(duration)
        lock.lock()
        exportSessionExpiry = expiry
        lock.unlock()
        return expiry
    }

    func endExportSession() {
        lock.lock()
        exportSessionExpiry = nil
        tickets.removeAll()
        lock.unlock()
    }

    func exportSessionExpiry(now: Date = Date()) -> Date? {
        lock.lock()
        defer { lock.unlock() }
        guard let expiry = exportSessionExpiry, expiry > now else { return nil }
        return expiry
    }

    func isExportSessionActive(now: Date = Date()) -> Bool {
        exportSessionExpiry(now: now) != nil
    }

    // MARK: - Request authorization

    func authorize(_ request: WebHTTPRequest, route: WebRequestRoute, now: Date = Date()) -> WebAuthDecision {
        if route == .pair { return .allow }
        guard let presented = Self.presentedToken(in: request, allowQuery: request.method == "GET") else {
            return .unauthorized
        }
        lock.lock()
        let expected = token
        let exportActive = exportSessionExpiry.map { $0 > now } ?? false
        lock.unlock()

        guard let expected, Self.constantTimeEquals(presented, expected) else {
            return .unauthorized
        }
        if route == .issueDownloadTicket && !exportActive {
            return .exportSessionRequired
        }
        return .allow
    }

    /// Reads the token from the custom header, the session cookie, or the query string of
    /// the link the app hands out. Writes only accept the header, which a cross-site page
    /// cannot set without a preflight the server refuses.
    static func presentedToken(in request: WebHTTPRequest, allowQuery: Bool) -> String? {
        if let header = request.headers["x-vault-token"], !header.isEmpty {
            return header
        }
        guard request.method == "GET" else { return nil }
        if let cookie = request.headers["cookie"], let value = sessionCookieValue(in: cookie) {
            return value
        }
        if allowQuery, let value = queryToken(in: request.path) {
            return value
        }
        return nil
    }

    static func sessionCookieValue(in header: String) -> String? {
        for pair in header.split(separator: ";") {
            let parts = pair.split(separator: "=", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            guard parts.count == 2, parts[0] == sessionCookieName, !parts[1].isEmpty else { continue }
            return parts[1]
        }
        return nil
    }

    static func queryToken(in path: String) -> String? {
        guard let components = URLComponents(string: "http://localhost\(path)"),
              let value = components.queryItems?.first(where: { $0.name == "token" })?.value,
              !value.isEmpty else {
            return nil
        }
        return value
    }

    static let sessionCookieName = "fv_session"

    static func sessionCookieHeader(token: String) -> String {
        "\(sessionCookieName)=\(token); Path=/; SameSite=Strict; HttpOnly; Secure"
    }

    // MARK: - Download tickets

    /// One-shot, short-lived, client-bound link for a single file or folder.
    func issueTicket(for target: WebDownloadTarget, client: String, now: Date = Date()) -> String? {
        let ticket = Self.randomToken()
        lock.lock()
        defer { lock.unlock() }
        guard token != nil, let expiry = exportSessionExpiry, expiry > now else { return nil }
        tickets = tickets.filter { $0.value.expiresAt > now }
        tickets[ticket] = Ticket(
            target: target,
            client: client,
            expiresAt: min(now.addingTimeInterval(Self.ticketLifetime), expiry)
        )
        return ticket
    }

    /// Redeems a ticket, consuming it so a copied link cannot be replayed.
    /// A guess from the wrong device does not burn the ticket.
    func redeemTicket(_ ticket: String, client: String, now: Date = Date()) -> WebDownloadTarget? {
        lock.lock()
        defer { lock.unlock() }
        guard let stored = tickets[ticket] else { return nil }
        if stored.expiresAt <= now {
            tickets.removeValue(forKey: ticket)
            return nil
        }
        guard let expiry = exportSessionExpiry, expiry > now else {
            tickets.removeValue(forKey: ticket)
            return nil
        }
        guard stored.client == client else { return nil }
        tickets.removeValue(forKey: ticket)
        return stored.target
    }

    // MARK: - Helpers

    private static func randomPairingCode() -> String {
        var value: UInt32 = 0
        withUnsafeMutableBytes(of: &value) { buffer in
            _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, buffer.baseAddress!)
        }
        return String(format: "%06u", value % 1_000_000)
    }

    private static func randomToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 24)
        if SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) != errSecSuccess {
            bytes = (0..<bytes.count).map { _ in UInt8.random(in: UInt8.min...UInt8.max) }
        }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    private static func constantTimeEquals(_ lhs: String, _ rhs: String) -> Bool {
        let left = Array(lhs.utf8)
        let right = Array(rhs.utf8)
        guard left.count == right.count else { return false }
        var difference: UInt8 = 0
        for index in left.indices {
            difference |= left[index] ^ right[index]
        }
        return difference == 0
    }
}
