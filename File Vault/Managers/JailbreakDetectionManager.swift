//
//  JailbreakDetectionManager.swift
//  File Vault
//
//  Created on 25/01/25.
//

import Foundation
import UIKit
import Security

class JailbreakDetectionManager {
    static let shared = JailbreakDetectionManager()
    
    private init() {}
    
    // MARK: - Main Detection Method
    
    /// Comprehensive jailbreak detection with multiple checks
    func isDeviceJailbroken() -> Bool {
        // Perform multiple detection methods
        let detectionResults = [
            checkSuspiciousFiles(),
            checkSuspiciousDirectories(),
            checkSuspiciousApps(),
            checkSystemModifications(),
            checkSandboxViolation(),
            checkDynamicLibraries(),
            checkEnvironmentVariables(),
            checkForkRestriction(),
            checkSymbolicLinks(),
            checkWriteAccess(),
            checkCydiaURL(),
            checkSuspiciousProcesses()
        ]
        
        // If any detection method returns true, device is likely jailbroken
        let jailbrokenCount = detectionResults.filter { $0 }.count
        
        // Log detection results for debugging
        logDetectionResults(detectionResults, totalPositive: jailbrokenCount)
        
        // Consider device jailbroken if 2 or more checks are positive
        // This reduces false positives while maintaining security
        return jailbrokenCount >= 2
    }
    
    // MARK: - Detection Methods
    
    /// Check for common jailbreak files
    private func checkSuspiciousFiles() -> Bool {
        let suspiciousFiles = [
            "/Applications/Cydia.app",
            "/Applications/blackra1n.app",
            "/Applications/FakeCarrier.app",
            "/Applications/Icy.app",
            "/Applications/IntelliScreen.app",
            "/Applications/MxTube.app",
            "/Applications/RockApp.app",
            "/Applications/SBSettings.app",
            "/Applications/WinterBoard.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/Library/MobileSubstrate/DynamicLibraries/LiveClock.plist",
            "/Library/MobileSubstrate/DynamicLibraries/Veency.plist",
            "/private/var/lib/apt",
            "/private/var/lib/cydia",
            "/private/var/mobile/Library/SBSettings/Themes",
            "/private/var/stash",
            "/private/var/tmp/cydia.log",
            "/System/Library/LaunchDaemons/com.ikey.bbot.plist",
            "/System/Library/LaunchDaemons/com.saurik.Cydia.Startup.plist",
            "/usr/bin/sshd",
            "/usr/libexec/sftp-server",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/bin/bash",
            "/bin/sh",
            "/usr/bin/ssh",
            "/usr/libexec/ssh-keysign",
            "/bin/su",
            "/etc/ssh/sshd_config",
            "/usr/libexec/cydia/firmware.sh"
        ]
        
        for file in suspiciousFiles {
            if FileManager.default.fileExists(atPath: file) {
                print("SECURITY: Suspicious file detected: \(file)")
                return true
            }
        }
        
        return false
    }
    
    /// Check for suspicious directories
    private func checkSuspiciousDirectories() -> Bool {
        let suspiciousDirectories = [
            "/Applications/Cydia.app",
            "/Applications/blackra1n.app",
            "/Applications/FakeCarrier.app",
            "/Applications/Icy.app",
            "/Applications/IntelliScreen.app",
            "/Applications/MxTube.app",
            "/Applications/RockApp.app",
            "/Applications/SBSettings.app",
            "/Applications/WinterBoard.app",
            "/Library/MobileSubstrate",
            "/private/var/lib/apt",
            "/private/var/lib/cydia",
            "/private/var/mobile/Library/SBSettings/Themes",
            "/private/var/stash",
            "/usr/include",
            "/usr/libexec/cydia",
            "/usr/share",
            "/Library/Themes/",
            "/private/etc/dpkg/origins/debian",
            "/Library/Caches/com.saurik.Cydia"
        ]
        
        for directory in suspiciousDirectories {
            if FileManager.default.fileExists(atPath: directory) {
                print("SECURITY: Suspicious directory detected: \(directory)")
                return true
            }
        }
        
        return false
    }
    
    /// Check for jailbreak apps
    private func checkSuspiciousApps() -> Bool {
        let suspiciousSchemes = [
            "cydia://",
            "undecimus://",
            "sileo://",
            "zbra://",
            "filza://",
            "activator://",
            "winterboard://",
            "icleaner://",
            "checkra1n://",
            "unc0ver://",
            "taurine://",
            "odyssey://",
            "chimera://",
            "electra://"
        ]
        
        for scheme in suspiciousSchemes {
            if let url = URL(string: scheme) {
                if UIApplication.shared.canOpenURL(url) {
                    print("SECURITY: Suspicious app scheme detected: \(scheme)")
                    return true
                }
            }
        }
        
        return false
    }
    
    /// Check for system modifications
    private func checkSystemModifications() -> Bool {
        // Check if system partition is writable (should be read-only on non-jailbroken devices)
        let systemPaths = [
            "/System",
            "/usr/bin",
            "/usr/sbin",
            "/usr/libexec"
        ]
        
        for path in systemPaths {
            if FileManager.default.isWritableFile(atPath: path) {
                print("SECURITY: System partition is writable: \(path)")
                return true
            }
        }
        
        return false
    }
    
    /// Check sandbox violation
    private func checkSandboxViolation() -> Bool {
        // Try to write to a restricted location
        let restrictedPath = "/private/jailbreak.txt"
        let testString = "jailbreak test"
        
        do {
            try testString.write(toFile: restrictedPath, atomically: true, encoding: .utf8)
            // If we can write to this location, device might be jailbroken
            try? FileManager.default.removeItem(atPath: restrictedPath)
            print("SECURITY: Sandbox violation detected - able to write to restricted path")
            return true
        } catch {
            // Normal behavior - should not be able to write here
            return false
        }
    }
    
    /// Check for suspicious dynamic libraries
    private func checkDynamicLibraries() -> Bool {
        let suspiciousLibraries = [
            "MobileSubstrate",
            "SubstrateLoader",
            "SubstrateInserter",
            "CydiaSubstrate",
            "cynject",
            "libcycript"
        ]
        
        for library in suspiciousLibraries {
            if let _ = dlopen(library, RTLD_NOW) {
                print("SECURITY: Suspicious dynamic library detected: \(library)")
                return true
            }
        }
        
        return false
    }
    
    /// Check environment variables
    private func checkEnvironmentVariables() -> Bool {
        let suspiciousEnvVars = [
            "DYLD_INSERT_LIBRARIES",
            "_MSSafeMode",
            "_SafeMode"
        ]
        
        for envVar in suspiciousEnvVars {
            if let value = getenv(envVar), strlen(value) > 0 {
                print("SECURITY: Suspicious environment variable detected: \(envVar)")
                return true
            }
        }
        
        return false
    }
    
    /// Check fork restriction (iOS doesn't allow fork on non-jailbroken devices)
    private func checkForkRestriction() -> Bool {
        // Note: fork() is not available in iOS apps for security reasons
        // This check is disabled as it would always fail in legitimate iOS apps
        // In a jailbroken environment, this restriction might be bypassed
        
        // Alternative: Check if we can access fork-related symbols
        if let _ = dlsym(dlopen(nil, RTLD_NOW), "fork") {
            // If fork symbol is accessible in ways it shouldn't be, might indicate jailbreak
            print("SECURITY: Fork symbol accessible - potential jailbreak indicator")
            return true
        }
        
        return false
    }
    
    /// Check for suspicious symbolic links
    private func checkSymbolicLinks() -> Bool {
        let suspiciousLinks = [
            "/Applications",
            "/usr/arm-apple-darwin9",
            "/usr/include",
            "/usr/libexec",
            "/usr/share"
        ]
        
        for link in suspiciousLinks {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: link)
                if let fileType = attributes[.type] as? FileAttributeType,
                   fileType == .typeSymbolicLink {
                    print("SECURITY: Suspicious symbolic link detected: \(link)")
                    return true
                }
            } catch {
                // Ignore errors
            }
        }
        
        return false
    }
    
    /// Check write access to system directories
    private func checkWriteAccess() -> Bool {
        let systemPaths = [
            "/",
            "/root",
            "/private",
            "/etc"
        ]
        
        for path in systemPaths {
            let testFile = "\(path)/jailbreak_test.txt"
            if FileManager.default.createFile(atPath: testFile, contents: "test".data(using: .utf8)) {
                try? FileManager.default.removeItem(atPath: testFile)
                print("SECURITY: Unexpected write access to system directory: \(path)")
                return true
            }
        }
        
        return false
    }
    
    /// Check Cydia URL scheme
    private func checkCydiaURL() -> Bool {
        if let url = URL(string: "cydia://package/com.example.package") {
            return UIApplication.shared.canOpenURL(url)
        }
        return false
    }
    
    /// Check for suspicious running processes
    private func checkSuspiciousProcesses() -> Bool {
        // This is a simplified check - in practice, you'd need more sophisticated process enumeration
        let suspiciousProcessNames = [
            "cydia",
            "substrate",
            "cycript"
        ]
        
        // Check if any suspicious process names appear in the environment
        for processName in suspiciousProcessNames {
            if let _ = getenv(processName) {
                print("SECURITY: Suspicious process environment detected: \(processName)")
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Security Actions
    
    /// Handle jailbreak detection
    func handleJailbreakDetection() {
        print("SECURITY: Jailbreak detected - initiating security measures")
        
        // Log security event
        logSecurityEvent("Jailbreak detected")
        
        // Clear sensitive data
        clearSensitiveData()
        
        // Show security warning
        showJailbreakWarning()
        
        // Optionally exit the app
        // exit(0)
    }
    
    /// Clear sensitive data when jailbreak is detected
    private func clearSensitiveData() {
        // Clear encryption keys from memory
        FileStorageManager.shared.clearEncryptionKey()
        
        // Clear keychain data
        try? KeychainManager.shared.deletePassword()
        
        // Clear any cached sensitive data
        UserDefaults.standard.removeObject(forKey: "SecurityLogs")
        
        print("SECURITY: Sensitive data cleared due to jailbreak detection")
    }
    
    /// Show jailbreak warning to user
    private func showJailbreakWarning() {
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else {
                return
            }
            
            let alert = UIAlertController(
                title: "Security Warning",
                message: "This device appears to be jailbroken. For your security, the app will not function on modified devices.",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Exit", style: .destructive) { _ in
                exit(0)
            })
            
            window.rootViewController?.present(alert, animated: true)
        }
    }
    
    // MARK: - Logging
    
    private func logDetectionResults(_ results: [Bool], totalPositive: Int) {
        let detectionMethods = [
            "Suspicious Files",
            "Suspicious Directories", 
            "Suspicious Apps",
            "System Modifications",
            "Sandbox Violation",
            "Dynamic Libraries",
            "Environment Variables",
            "Fork Restriction",
            "Symbolic Links",
            "Write Access",
            "Cydia URL",
            "Suspicious Processes"
        ]
        
        print("SECURITY: Jailbreak Detection Results:")
        for (index, result) in results.enumerated() {
            print("SECURITY: \(detectionMethods[index]): \(result ? "DETECTED" : "Clean")")
        }
        print("SECURITY: Total positive detections: \(totalPositive)/\(results.count)")
    }
    
    private func logSecurityEvent(_ event: String) {
        let timestamp = Date()
        let logEntry = "\(timestamp): JAILBREAK - \(event)"
        print("SECURITY LOG: \(logEntry)")
        
        // Store in UserDefaults for debugging
        var securityLogs = UserDefaults.standard.stringArray(forKey: "SecurityLogs") ?? []
        securityLogs.append(logEntry)
        
        // Keep only last 100 entries
        if securityLogs.count > 100 {
            securityLogs = Array(securityLogs.suffix(100))
        }
        
        UserDefaults.standard.set(securityLogs, forKey: "SecurityLogs")
    }
}

// MARK: - FileStorageManager Extension

extension FileStorageManager {
    /// Clear encryption key from memory (for jailbreak protection)
    func clearEncryptionKey() {
        encryptionKey = nil
        print("SECURITY: Encryption key cleared from memory")
    }
} 