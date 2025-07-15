//
//  RecoveryManager.swift
//  File Vault
//
//  Created on 15/07/25.
//

import Foundation
import Security
import CryptoKit

enum RecoveryError: Error {
    case noRecoveryMethodSet
    case invalidRecoveryData
    case recoveryValidationFailed
    case keychainError
    case insufficientRecoveryMethods
}

enum RecoveryMethod: String, CaseIterable, Codable {
    case securityQuestions = "security_questions"
    case recoveryPhrase = "recovery_phrase"
    case masterKey = "master_key"
    
    var displayName: String {
        switch self {
        case .securityQuestions: return "Security Questions"
        case .recoveryPhrase: return "Recovery Phrase"
        case .masterKey: return "Master Recovery Key"
        }
    }
    
    var description: String {
        switch self {
        case .securityQuestions: return "Answer security questions to recover access"
        case .recoveryPhrase: return "Use a 12-word recovery phrase"
        case .masterKey: return "Use your master recovery key"
        }
    }
}

struct SecurityQuestion: Codable {
    let id: String
    let question: String
    let answer: String // This will be hashed before storage
    
    init(id: String, question: String, answer: String) {
        self.id = id
        self.question = question
        self.answer = answer
    }
}

struct RecoveryConfiguration: Codable {
    let enabledMethods: Set<RecoveryMethod>
    let securityQuestions: [SecurityQuestion]?
    let recoveryPhraseHash: String?
    let masterKeyHash: String?
    let createdAt: Date
    
    init(enabledMethods: Set<RecoveryMethod>, 
         securityQuestions: [SecurityQuestion]? = nil,
         recoveryPhraseHash: String? = nil,
         masterKeyHash: String? = nil) {
        self.enabledMethods = enabledMethods
        self.securityQuestions = securityQuestions
        self.recoveryPhraseHash = recoveryPhraseHash
        self.masterKeyHash = masterKeyHash
        self.createdAt = Date()
    }
}

class RecoveryManager {
    static let shared = RecoveryManager()
    
    private let service = "com.filevault.recovery"
    private let recoveryConfigKey = "recovery_config"
    
    // Predefined security questions
    static let predefinedQuestions = [
        "What was the name of your first pet?",
        "What is your mother's maiden name?",
        "What was the name of your first school?",
        "What is the name of the city where you were born?",
        "What was your childhood nickname?",
        "What is the name of your favorite childhood friend?",
        "What was the make of your first car?",
        "What is your favorite book?",
        "What was the name of the street you grew up on?",
        "What is your favorite movie?",
        "What was your favorite food as a child?",
        "What is the name of your favorite teacher?"
    ]
    
    // Recovery phrase word list (BIP39 subset for simplicity)
    private let recoveryWords = [
        "abandon", "ability", "able", "about", "above", "absent", "absorb", "abstract", "absurd", "abuse",
        "access", "accident", "account", "accuse", "achieve", "acid", "acoustic", "acquire", "across", "act",
        "action", "actor", "actress", "actual", "adapt", "add", "addict", "address", "adjust", "admit",
        "adult", "advance", "advice", "aerobic", "affair", "afford", "afraid", "again", "against", "age",
        "agent", "agree", "ahead", "aim", "air", "airport", "aisle", "alarm", "album", "alcohol",
        "alert", "alien", "all", "alley", "allow", "almost", "alone", "alpha", "already", "also",
        "alter", "always", "amateur", "amazing", "among", "amount", "amused", "analyst", "anchor", "ancient",
        "anger", "angle", "angry", "animal", "ankle", "announce", "annual", "another", "answer", "antenna",
        "antique", "anxiety", "any", "apart", "apology", "appear", "apple", "approve", "april", "arcade",
        "arch", "arctic", "area", "arena", "argue", "arm", "armed", "armor", "army", "around",
        "arrange", "arrest", "arrive", "arrow", "art", "article", "artist", "artwork", "ask", "aspect",
        "assault", "asset", "assist", "assume", "asthma", "athlete", "atom", "attack", "attend", "attitude",
        "attract", "auction", "audit", "august", "aunt", "author", "auto", "autumn", "average", "avocado"
    ]
    
    private init() {}
    
    // MARK: - Recovery Configuration
    
    func getRecoveryConfiguration() -> RecoveryConfiguration? {
        do {
            let data = try getKeychainData(for: recoveryConfigKey)
            return try JSONDecoder().decode(RecoveryConfiguration.self, from: data)
        } catch {
            print("DEBUG: No recovery configuration found or failed to decode: \(error)")
            return nil
        }
    }
    
    func saveRecoveryConfiguration(_ config: RecoveryConfiguration) throws {
        let data = try JSONEncoder().encode(config)
        try saveToKeychain(data: data, key: recoveryConfigKey)
    }
    
    func hasRecoveryMethodsEnabled() -> Bool {
        guard let config = getRecoveryConfiguration() else { return false }
        return !config.enabledMethods.isEmpty
    }
    
    func getEnabledRecoveryMethods() -> Set<RecoveryMethod> {
        return getRecoveryConfiguration()?.enabledMethods ?? []
    }
    
    // MARK: - Security Questions
    
    func setupSecurityQuestions(_ questions: [SecurityQuestion]) throws {
        // Hash the answers before storing
        let hashedQuestions = questions.map { question in
            let hashedAnswer = hashString(question.answer.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))
            return SecurityQuestion(id: question.id, question: question.question, answer: hashedAnswer)
        }
        
        let config = getRecoveryConfiguration() ?? RecoveryConfiguration(enabledMethods: [])
        var newEnabledMethods = config.enabledMethods
        newEnabledMethods.insert(.securityQuestions)
        
        let updatedConfig = RecoveryConfiguration(
            enabledMethods: newEnabledMethods,
            securityQuestions: hashedQuestions,
            recoveryPhraseHash: config.recoveryPhraseHash,
            masterKeyHash: config.masterKeyHash
        )
        
        try saveRecoveryConfiguration(updatedConfig)
    }
    
    func validateSecurityQuestions(_ answers: [String: String]) -> Bool {
        guard let config = getRecoveryConfiguration(),
              let questions = config.securityQuestions else {
            return false
        }
        
        guard answers.count == questions.count else { return false }
        
        for question in questions {
            guard let userAnswer = answers[question.id] else { return false }
            let hashedUserAnswer = hashString(userAnswer.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))
            if hashedUserAnswer != question.answer {
                return false
            }
        }
        
        return true
    }
    
    // MARK: - Recovery Phrase
    
    func generateRecoveryPhrase() -> [String] {
        // Generate 12 random words from our word list
        var phrase: [String] = []
        for _ in 0..<12 {
            let randomIndex = Int.random(in: 0..<recoveryWords.count)
            phrase.append(recoveryWords[randomIndex])
        }
        return phrase
    }
    
    func setupRecoveryPhrase(_ phrase: [String]) throws {
        guard phrase.count == 12 else {
            throw RecoveryError.invalidRecoveryData
        }
        
        let phraseString = phrase.joined(separator: " ").lowercased()
        let hashedPhrase = hashString(phraseString)
        
        let config = getRecoveryConfiguration() ?? RecoveryConfiguration(enabledMethods: [])
        var newEnabledMethods = config.enabledMethods
        newEnabledMethods.insert(.recoveryPhrase)
        
        let updatedConfig = RecoveryConfiguration(
            enabledMethods: newEnabledMethods,
            securityQuestions: config.securityQuestions,
            recoveryPhraseHash: hashedPhrase,
            masterKeyHash: config.masterKeyHash
        )
        
        try saveRecoveryConfiguration(updatedConfig)
    }
    
    func validateRecoveryPhrase(_ phrase: [String]) -> Bool {
        guard let config = getRecoveryConfiguration(),
              let storedHash = config.recoveryPhraseHash else {
            return false
        }
        
        let phraseString = phrase.joined(separator: " ").lowercased()
        let hashedPhrase = hashString(phraseString)
        
        return hashedPhrase == storedHash
    }
    
    // MARK: - Master Recovery Key
    
    func generateMasterRecoveryKey() -> String {
        // Generate a secure 32-character alphanumeric key
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        var key = ""
        for _ in 0..<32 {
            let randomIndex = Int.random(in: 0..<characters.count)
            let character = characters[characters.index(characters.startIndex, offsetBy: randomIndex)]
            key.append(character)
        }
        
        // Format as groups of 4 for readability
        var formattedKey = ""
        for (index, character) in key.enumerated() {
            if index > 0 && index % 4 == 0 {
                formattedKey.append("-")
            }
            formattedKey.append(character)
        }
        
        return formattedKey
    }
    
    func setupMasterRecoveryKey(_ key: String) throws {
        let cleanKey = key.replacingOccurrences(of: "-", with: "").uppercased()
        guard cleanKey.count == 32 && cleanKey.allSatisfy({ $0.isLetter || $0.isNumber }) else {
            throw RecoveryError.invalidRecoveryData
        }
        
        let hashedKey = hashString(cleanKey)
        
        let config = getRecoveryConfiguration() ?? RecoveryConfiguration(enabledMethods: [])
        var newEnabledMethods = config.enabledMethods
        newEnabledMethods.insert(.masterKey)
        
        let updatedConfig = RecoveryConfiguration(
            enabledMethods: newEnabledMethods,
            securityQuestions: config.securityQuestions,
            recoveryPhraseHash: config.recoveryPhraseHash,
            masterKeyHash: hashedKey
        )
        
        try saveRecoveryConfiguration(updatedConfig)
    }
    
    func validateMasterRecoveryKey(_ key: String) -> Bool {
        guard let config = getRecoveryConfiguration(),
              let storedHash = config.masterKeyHash else {
            return false
        }
        
        let cleanKey = key.replacingOccurrences(of: "-", with: "").uppercased()
        let hashedKey = hashString(cleanKey)
        
        return hashedKey == storedHash
    }
    
    // MARK: - Recovery Process
    
    func attemptRecovery(method: RecoveryMethod, data: Any) -> Bool {
        guard let config = getRecoveryConfiguration(),
              config.enabledMethods.contains(method) else {
            return false
        }
        
        switch method {
        case .securityQuestions:
            guard let answers = data as? [String: String] else { return false }
            return validateSecurityQuestions(answers)
            
        case .recoveryPhrase:
            guard let phrase = data as? [String] else { return false }
            return validateRecoveryPhrase(phrase)
            
        case .masterKey:
            guard let key = data as? String else { return false }
            return validateMasterRecoveryKey(key)
        }
    }
    
    func resetPassword(to newPassword: String, using recoveryMethod: RecoveryMethod, with recoveryData: Any) throws {
        // First validate the recovery method
        guard attemptRecovery(method: recoveryMethod, data: recoveryData) else {
            throw RecoveryError.recoveryValidationFailed
        }
        
        // Save the new password
        try KeychainManager.shared.savePassword(newPassword)
        
        // Log security event
        SecurityManager.shared.logSecurityEvent("Password reset using \(recoveryMethod.displayName)")
        
        print("DEBUG: Password successfully reset using \(recoveryMethod.displayName)")
    }
    
    // MARK: - Cleanup
    
    func clearAllRecoveryData() {
        do {
            try deleteKeychainData(for: recoveryConfigKey)
            print("DEBUG: Recovery data cleared")
        } catch {
            print("DEBUG: Error clearing recovery data: \(error)")
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func hashString(_ string: String) -> String {
        let data = Data(string.utf8)
        let hashed = SHA256.hash(data: data)
        return hashed.map { String(format: "%02hhx", $0) }.joined()
    }
    
    private func saveToKeychain(data: Data, key: String) throws {
        // Delete existing entry first
        try? deleteKeychainData(for: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw RecoveryError.keychainError
        }
    }
    
    private func getKeychainData(for key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            throw RecoveryError.keychainError
        }
        
        guard let data = result as? Data else {
            throw RecoveryError.invalidRecoveryData
        }
        
        return data
    }
    
    private func deleteKeychainData(for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw RecoveryError.keychainError
        }
    }
} 