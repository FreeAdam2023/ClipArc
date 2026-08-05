//
//  SensitiveContentDetector.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-08-05.
//
//  Classifies clipboard text that should not be shown in the open (passwords,
//  API keys, card numbers, emails, …) so the panel can mask it until the user
//  explicitly asks to see it. Detection never changes what gets pasted.
//

import Foundation

/// The kind of sensitive content an item holds. `nil` means "safe to show".
enum SensitiveKind: String, Codable, CaseIterable {
    case password
    case secretKey
    case creditCard
    case idNumber
    case email
    case phone

    var icon: String {
        switch self {
        case .password: return "key.fill"
        case .secretKey: return "lock.shield.fill"
        case .creditCard: return "creditcard.fill"
        case .idNumber: return "person.text.rectangle.fill"
        case .email: return "envelope.fill"
        case .phone: return "phone.fill"
        }
    }

    var displayName: String {
        switch self {
        case .password: return L10n.Privacy.kindPassword
        case .secretKey: return L10n.Privacy.kindSecretKey
        case .creditCard: return L10n.Privacy.kindCreditCard
        case .idNumber: return L10n.Privacy.kindIdNumber
        case .email: return L10n.Privacy.kindEmail
        case .phone: return L10n.Privacy.kindPhone
        }
    }
}

// MARK: - Detection

enum SensitiveContentDetector {

    /// Copying from one of these apps means the content is a credential, whatever it looks like.
    static let credentialAppBundleIDs: Set<String> = [
        "com.apple.keychainaccess",
        "com.1password.1password",
        "com.agilebits.onepassword7",
        "com.agilebits.onepassword-osx",
        "com.bitwarden.desktop",
        "org.keepassxc.keepassxc",
        "com.lastpass.LastPass",
        "com.dashlane.Dashlane",
        "in.sinew.Enpass-Desktop",
        "com.mssarafa.strongbox",
        "com.strongbox.mac.Strongbox",
        "app.protonpass.mac",
        "com.nordpass.macos",
        "com.roboform.RoboForm",
        "com.mitrecorporation.KeePass",
    ]

    /// Well-known secret/token shapes. Anchored so a whole copied line must match.
    private static let secretKeyPatterns: [String] = [
        "^sk-[A-Za-z0-9_\\-]{16,}$",                                   // OpenAI-style
        "^sk-(proj|ant|live|test)-[A-Za-z0-9_\\-]{16,}$",              // scoped variants
        "^(sk|pk|rk)_(live|test)_[A-Za-z0-9]{16,}$",                   // Stripe
        "^gh[pousr]_[A-Za-z0-9]{16,}$",                                // GitHub token
        "^github_pat_[A-Za-z0-9_]{20,}$",                              // GitHub fine-grained PAT
        "^glpat-[A-Za-z0-9_\\-]{16,}$",                                // GitLab PAT
        "^xox[baprs]-[A-Za-z0-9\\-]{10,}$",                            // Slack
        "^A(KIA|SIA)[0-9A-Z]{16}$",                                    // AWS access key
        "^AIza[0-9A-Za-z_\\-]{35}$",                                   // Google API key
        "^npm_[A-Za-z0-9]{30,}$",                                      // npm token
        "^eyJ[A-Za-z0-9_\\-]{8,}\\.[A-Za-z0-9_\\-]{8,}\\.[A-Za-z0-9_\\-]+$", // JWT
        "^(?i)bearer\\s+[A-Za-z0-9._\\-]{20,}$",                       // Authorization header value
        "^(?i)(ssh-rsa|ssh-ed25519|ecdsa-sha2-\\S+)\\s+\\S{40,}",      // SSH public/private material
    ]

    private static let emailPattern = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
    private static let chineseIDPattern = "^[0-9]{17}[0-9Xx]$"
    private static let usSSNPattern = "^[0-9]{3}-[0-9]{2}-[0-9]{4}$"
    /// Date-shaped strings look like phone numbers to a digit counter; they are not.
    private static let datePatterns = [
        "^[0-9]{4}[-/.][0-9]{1,2}[-/.][0-9]{1,2}$",
        "^[0-9]{1,2}[-/.][0-9]{1,2}[-/.][0-9]{2,4}$",
    ]

    /// Returns the kind of sensitive content, or `nil` if the item is safe to display openly.
    /// Order matters: the most specific shapes are checked first, so a US SSN is not
    /// mistaken for a phone number.
    static func detect(content: String, type: ClipboardItemType, sourceAppBundleID: String?) -> SensitiveKind? {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Key material can span many lines, so check it before the single-line gate.
        if trimmed.contains("-----BEGIN"), trimmed.contains("PRIVATE KEY") {
            return .secretKey
        }

        if type == .email || matches(trimmed, emailPattern) { return .email }

        // Anything copied out of a password manager is a credential.
        if let bundleID = sourceAppBundleID, credentialAppBundleIDs.contains(bundleID) {
            return .password
        }

        // Everything below is a single-token shape.
        guard !trimmed.contains(where: \.isNewline) else { return nil }

        for pattern in secretKeyPatterns where matches(trimmed, pattern) {
            return .secretKey
        }

        if let digits = cardShapedDigits(trimmed), passesLuhn(digits) {
            return .creditCard
        }

        if matches(trimmed, chineseIDPattern) || matches(trimmed, usSSNPattern) {
            return .idNumber
        }

        // `detectType` reports dates such as "2026-08-05" as phone numbers, so the
        // date check gates the type hint as well as our own shape check.
        if !isDateShaped(trimmed), type == .phone || looksLikePhone(trimmed) { return .phone }

        // Free-form text that has the shape of a password.
        if type == .text || type == .other, looksLikePassword(trimmed) {
            return .password
        }

        return nil
    }

    private static func matches(_ text: String, _ pattern: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }

    // MARK: - Heuristics

    /// A conservative password shape: no spaces, mixed character classes, and either
    /// real punctuation or enough length that it is unlikely to be an ordinary word.
    private static func looksLikePassword(_ text: String) -> Bool {
        let count = text.count
        guard count >= 8, count <= 128 else { return false }
        guard !text.contains("://"), !text.contains("@"),
              !text.contains("/"), !text.contains("\\"),
              !text.hasPrefix("#") else { return false }

        var hasLower = false, hasUpper = false, hasDigit = false, hasSymbol = false
        for character in text {
            if character.isWhitespace { return false }
            if character.isLowercase { hasLower = true }
            else if character.isUppercase { hasUpper = true }
            else if character.isNumber { hasDigit = true }
            else if character.isASCII { hasSymbol = true }
            else { return false }  // CJK and other scripts: ordinary text, not a password
        }

        guard hasDigit else { return false }
        let classCount = [hasLower, hasUpper, hasDigit, hasSymbol].filter { $0 }.count
        guard classCount >= 3 else { return false }

        // `com.example.app2`, `my_var_1`, `some-file-name-42` are identifiers, not secrets.
        let punctuation = text.filter { !$0.isLetter && !$0.isNumber }
        let onlyIdentifierPunctuation = punctuation.allSatisfy { ".-_".contains($0) }
        if onlyIdentifierPunctuation && !(hasUpper && hasLower) { return false }

        return hasSymbol || count >= 12
    }

    /// Phone-shaped: only dialling characters and 7-15 digits.
    /// `ClipboardItemType.detectType` misses formats like "+1 (415) 555-2671",
    /// so the detector checks independently rather than trusting the type alone.
    private static func looksLikePhone(_ text: String) -> Bool {
        guard text.allSatisfy({ $0.isNumber || "+()-. ".contains($0) }) else { return false }
        return (7...15).contains(text.filter(\.isNumber).count)
    }

    private static func isDateShaped(_ text: String) -> Bool {
        datePatterns.contains { matches(text, $0) }
    }

    /// Digits of a card-shaped string (digits, spaces and dashes only), or `nil`.
    private static func cardShapedDigits(_ text: String) -> String? {
        guard text.allSatisfy({ $0.isNumber || $0 == " " || $0 == "-" }) else { return nil }
        let digits = text.filter(\.isNumber)
        guard (13...19).contains(digits.count) else { return nil }
        return digits
    }

    private static func passesLuhn(_ digits: String) -> Bool {
        var sum = 0
        for (offset, character) in digits.reversed().enumerated() {
            guard let value = character.wholeNumberValue else { return false }
            if offset.isMultiple(of: 2) {
                sum += value
            } else {
                let doubled = value * 2
                sum += doubled > 9 ? doubled - 9 : doubled
            }
        }
        return sum % 10 == 0
    }
}

// MARK: - Masking

/// Builds the redacted string shown in place of sensitive content.
/// Purely presentational — the stored content is never modified.
///
/// Every kind keeps a recognisable head and tail: a history holding three
/// passwords has to stay pickable, and a row of identical bullets is useless.
/// Only the middle is removed, and for credentials the middle is a fixed width
/// so the mask does not also disclose how long the secret is.
enum SensitiveMask {
    private static let bullet: Character = "•"

    /// Width of the hidden section for credentials, independent of the real length.
    private static let fixedHiddenWidth = 6

    static func mask(_ content: String, kind: SensitiveKind) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        switch kind {
        case .password:
            return maskPassword(trimmed)
        case .secretKey:
            return maskSecretKey(trimmed)
        case .email:
            return maskEmail(trimmed)
        case .phone:
            return maskKeepingEdges(trimmed, leading: 3, trailing: 4)
        case .creditCard:
            let last4 = String(trimmed.filter(\.isNumber).suffix(4))
            return "•••• •••• •••• \(last4)"
        case .idNumber:
            // Deliberately stingy: two characters each side is enough to tell two
            // entries apart without exposing more of a government ID than needed.
            return maskKeepingEdges(trimmed, leading: 2, trailing: 2)
        }
    }

    /// Shows a couple of characters at each end so the user can tell which password
    /// this is. Short secrets reveal less, because the same two characters would be
    /// a larger share of them.
    private static func maskPassword(_ text: String) -> String {
        let revealed: Int
        switch text.count {
        case ..<8: revealed = 0
        case 8...11: revealed = 1
        default: revealed = 2
        }

        let hidden = String(repeating: bullet, count: fixedHiddenWidth)
        guard revealed > 0 else { return hidden }
        return text.prefix(revealed) + hidden + text.suffix(revealed)
    }

    /// Tokens are identified by their vendor prefix and last few characters -
    /// the same shape GitHub, Stripe and AWS use in their own consoles.
    private static func maskSecretKey(_ text: String) -> String {
        guard text.count > 8 else { return String(repeating: bullet, count: fixedHiddenWidth) }
        return vendorPrefix(of: text)
            + String(repeating: bullet, count: fixedHiddenWidth)
            + text.suffix(4)
    }

    /// `sk-proj-`, `ghp_`, `github_pat_`, … or the first few characters when the
    /// token has no separator (`AKIA…`).
    private static func vendorPrefix(of text: String) -> Substring {
        if let range = text.range(of: "^[A-Za-z]+(?:[-_][A-Za-z]+)*[-_]", options: .regularExpression),
           text[range].count <= 12 {
            return text[range]
        }
        return text.prefix(4)
    }

    private static func maskEmail(_ email: String) -> String {
        guard let atIndex = email.firstIndex(of: "@") else {
            return String(repeating: bullet, count: fixedHiddenWidth)
        }
        let local = String(email[email.startIndex..<atIndex])
        let domain = String(email[atIndex...])  // includes "@"

        guard local.count > 2 else {
            return String(repeating: bullet, count: max(local.count, 1)) + domain
        }
        return local.prefix(2) + String(repeating: bullet, count: min(local.count - 2, 6)) + domain
    }

    /// Keeps the first/last few characters and replaces the middle. Used for values
    /// whose length is inherent to the type (phone numbers, ID numbers), where the
    /// number of bullets is not itself a secret.
    private static func maskKeepingEdges(_ text: String, leading: Int, trailing: Int) -> String {
        let characters = Array(text)
        guard characters.count > leading + trailing + 1 else {
            return String(repeating: bullet, count: max(characters.count, 4))
        }
        let head = String(characters.prefix(leading))
        let tail = String(characters.suffix(trailing))
        let hidden = String(repeating: bullet, count: characters.count - leading - trailing)
        return head + hidden + tail
    }
}
