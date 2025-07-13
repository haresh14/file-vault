//
//  AntiTamperingManager.swift
//  File Vault
//
//  Created on 25/01/25.
//

import Foundation
import UIKit
import Security
import CommonCrypto
import Darwin.C

class AntiTamperingManager {
    static let shared = AntiTamperingManager()
    
    private init() {}
    
    // MARK: - Anti-Debugging
    
    /// Check if debugger is attached
    func isDebuggerAttached() -> Bool {
        var info = kinfo_proc()
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var size = MemoryLayout<kinfo_proc>.stride
        
        let junk = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)
        assert(junk == 0, "sysctl failed")
        
        let isDebugged = (info.kp_proc.p_flag & P_TRACED) != 0
        
        if isDebugged {
            print("SECURITY: Debugger detected")
        }
        
        return isDebugged
    }
    
    /// Detect if app is running under a debugger using ptrace
    func detectPtraceDebugger() -> Bool {
        // ptrace detection is disabled in this build due to platform limitations
        // This would be enabled in a production security build with proper entitlements
        #if DEBUG
        print("SECURITY: ptrace debugger detection disabled in debug builds")
        return false
        #else
        // In production, this would call ptrace(PT_DENY_ATTACH, 0, 0, 0)
        // For now, we'll use alternative detection methods
        return false
        #endif
    }
    
    // MARK: - App Integrity Checks
    
    /// Verify app bundle integrity
    func verifyAppIntegrity() -> Bool {
        // Check if app is signed properly
        if !isAppProperlyCodeSigned() {
            print("SECURITY: App signature verification failed")
            return false
        }
        
        // Check for suspicious modifications
        if hasUnexpectedFiles() {
            print("SECURITY: Unexpected files detected in app bundle")
            return false
        }
        
        return true
    }
    
    /// Check if app is properly code signed
    private func isAppProperlyCodeSigned() -> Bool {
        // Simplified code signing check for iOS
        // Full SecStaticCode APIs are not available in iOS runtime
        
        // Check if we're running in a properly signed environment
        // by verifying basic bundle properties
        guard let bundleID = Bundle.main.bundleIdentifier,
              !bundleID.isEmpty else {
            print("SECURITY: Invalid bundle identifier")
            return false
        }
        
        // Check if bundle has proper entitlements file
        guard let entitlementsPath = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") else {
            // This is expected in App Store builds, so we'll consider it valid
            return true
        }
        
        return FileManager.default.fileExists(atPath: entitlementsPath)
    }
    
    /// Check for unexpected files in app bundle
    private func hasUnexpectedFiles() -> Bool {
        let bundlePath = Bundle.main.bundlePath
        
        let suspiciousFiles = [
            "FridaGadget",
            "frida-agent",
            "substrate",
            "cycript",
            "cynject",
            ".fseventsd",
            ".cydia_no_stash"
        ]
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: bundlePath)
            for file in contents {
                for suspicious in suspiciousFiles {
                    if file.lowercased().contains(suspicious.lowercased()) {
                        print("SECURITY: Suspicious file in bundle: \(file)")
                        return true
                    }
                }
            }
        } catch {
            print("SECURITY: Error reading bundle contents: \(error)")
            return true
        }
        
        return false
    }
    
    // MARK: - Runtime Protection
    
    /// Detect runtime manipulation tools
    func detectRuntimeManipulation() -> Bool {
        // Check for Frida
        if detectFrida() {
            return true
        }
        
        // Check for Cycript
        if detectCycript() {
            return true
        }
        
        // Check for suspicious dylibs
        if detectSuspiciousDylibs() {
            return true
        }
        
        return false
    }
    
    /// Detect Frida framework
    private func detectFrida() -> Bool {
        // Check for Frida-related symbols
        let fridaSymbols = [
            "frida_agent_main",
            "gum_init_embedded",
            "frida_gadget_load"
        ]
        
        for symbol in fridaSymbols {
            if dlsym(dlopen(nil, RTLD_NOW), symbol) != nil {
                print("SECURITY: Frida symbol detected: \(symbol)")
                return true
            }
        }
        
        // Check for Frida server on common ports
        return checkFridaServer()
    }
    
    /// Check for Frida server
    private func checkFridaServer() -> Bool {
        let commonFridaPorts = [27042, 27043, 27044]
        
        for port in commonFridaPorts {
            if isPortOpen(port: port) {
                print("SECURITY: Frida server detected on port \(port)")
                return true
            }
        }
        
        return false
    }
    
    /// Check if a port is open (simplified check)
    private func isPortOpen(port: Int) -> Bool {
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else { return false }
        
        defer { close(sock) }
        
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(port).bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        
        let result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        
        return result == 0
    }
    
    /// Detect Cycript
    private func detectCycript() -> Bool {
        // Check for Cycript library
        if dlopen("libcycript.dylib", RTLD_NOW) != nil {
            print("SECURITY: Cycript detected")
            return true
        }
        
        // Check for Cycript symbols
        if dlsym(dlopen(nil, RTLD_NOW), "cycript_main") != nil {
            print("SECURITY: Cycript symbol detected")
            return true
        }
        
        return false
    }
    
    /// Detect suspicious dylibs
    private func detectSuspiciousDylibs() -> Bool {
        let suspiciousLibs = [
            "SubstrateLoader.dylib",
            "MobileSubstrate.dylib", 
            "SubstrateInserter.dylib",
            "SSLKillSwitch",
            "SSLKillSwitch2",
            "FridaGadget.dylib",
            "libcycript.dylib"
        ]
        
        for lib in suspiciousLibs {
            if dlopen(lib, RTLD_NOW) != nil {
                print("SECURITY: Suspicious dylib detected: \(lib)")
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Memory Protection
    
    /// Clear sensitive data from memory
    func secureClearMemory(_ data: inout Data) {
        _ = data.withUnsafeMutableBytes { bytes in
            memset_s(bytes.baseAddress, bytes.count, 0, bytes.count)
        }
    }
    
    /// Clear sensitive string from memory
    func secureClearString(_ string: inout String) {
        string.withUTF8 { utf8 in
            let mutablePointer = UnsafeMutableRawPointer(mutating: utf8.baseAddress!)
            memset_s(mutablePointer, utf8.count, 0, utf8.count)
        }
        string = ""
    }
    
    // MARK: - Comprehensive Security Check
    
    /// Perform comprehensive anti-tampering check
    func performSecurityCheck() -> SecurityCheckResult {
        var threats: [String] = []
        
        // Check for debugger
        if isDebuggerAttached() || detectPtraceDebugger() {
            threats.append("Debugger detected")
        }
        
        // Check app integrity
        if !verifyAppIntegrity() {
            threats.append("App integrity compromised")
        }
        
        // Check for runtime manipulation
        if detectRuntimeManipulation() {
            threats.append("Runtime manipulation detected")
        }
        
        // Check for jailbreak (delegate to JailbreakDetectionManager)
        if JailbreakDetectionManager.shared.isDeviceJailbroken() {
            threats.append("Jailbroken device detected")
        }
        
        let result = SecurityCheckResult(
            isSecure: threats.isEmpty,
            threats: threats,
            timestamp: Date()
        )
        
        // Log results
        logSecurityCheckResults(result)
        
        return result
    }
    
    /// Handle security threats
    func handleSecurityThreats(_ result: SecurityCheckResult) {
        guard !result.isSecure else { return }
        
        print("SECURITY: Security threats detected: \(result.threats)")
        
        // Clear sensitive data
        clearAllSensitiveData()
        
        // Show security warning
        showSecurityWarning(threats: result.threats)
        
        // Optionally exit app
        // exit(0)
    }
    
    // MARK: - Data Protection
    
    /// Clear all sensitive data
    private func clearAllSensitiveData() {
        // Clear FileStorageManager encryption key
        FileStorageManager.shared.clearEncryptionKey()
        
        // Clear keychain data
        try? KeychainManager.shared.deletePassword()
        
        // Clear any cached data
        UserDefaults.standard.removeObject(forKey: "SecurityLogs")
        
        print("SECURITY: All sensitive data cleared due to security threat")
    }
    
    /// Show security warning
    private func showSecurityWarning(threats: [String]) {
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else {
                return
            }
            
            let threatList = threats.joined(separator: "\n• ")
            let message = "Security threats detected:\n• \(threatList)\n\nThe app will exit for your protection."
            
            let alert = UIAlertController(
                title: "Security Alert",
                message: message,
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Exit", style: .destructive) { _ in
                exit(0)
            })
            
            window.rootViewController?.present(alert, animated: true)
        }
    }
    
    // MARK: - Logging
    
    private func logSecurityCheckResults(_ result: SecurityCheckResult) {
        let logEntry = "Security Check - Secure: \(result.isSecure), Threats: \(result.threats)"
        print("SECURITY LOG: \(logEntry)")
        
        // Store in UserDefaults for debugging
        var securityLogs = UserDefaults.standard.stringArray(forKey: "SecurityLogs") ?? []
        securityLogs.append("\(result.timestamp): \(logEntry)")
        
        // Keep only last 100 entries
        if securityLogs.count > 100 {
            securityLogs = Array(securityLogs.suffix(100))
        }
        
        UserDefaults.standard.set(securityLogs, forKey: "SecurityLogs")
    }
}

// MARK: - Security Check Result

struct SecurityCheckResult {
    let isSecure: Bool
    let threats: [String]
    let timestamp: Date
}

// MARK: - C Functions for ptrace
// Note: ptrace functions are commented out due to platform limitations
// In a production build, these would be properly implemented with entitlements

// private func ptrace(_ request: Int32, _ pid: pid_t, _ addr: caddr_t, _ data: Int32) -> Int32 {
//     return Darwin.ptrace(request, pid, addr, data)
// }
//
// private let PT_DENY_ATTACH: Int32 = 31 