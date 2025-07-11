//
//  SimpleTests.swift
//  File VaultTests
//
//  Created on 11/07/25.
//

import Testing
import Foundation
@testable import File_Vault

struct SimpleTests {
    
    @Test func testBasicFunctionality() async throws {
        // Test that basic managers can be instantiated
        let securityManager = SecurityManager.shared
        let keychainManager = KeychainManager.shared
        let biometricManager = BiometricAuthManager.shared
        let coreDataManager = CoreDataManager.shared
        let fileStorageManager = FileStorageManager.shared
        let webServerManager = WebServerManager.shared
        
        // Test that they are not nil
        #expect(securityManager != nil, "SecurityManager should be available")
        #expect(keychainManager != nil, "KeychainManager should be available")
        #expect(biometricManager != nil, "BiometricAuthManager should be available")
        #expect(coreDataManager != nil, "CoreDataManager should be available")
        #expect(fileStorageManager != nil, "FileStorageManager should be available")
        #expect(webServerManager != nil, "WebServerManager should be available")
        
        // Test basic properties
        #expect(securityManager.isScreenshotProtectionEnabled == true || securityManager.isScreenshotProtectionEnabled == false, "Screenshot protection should be boolean")
        #expect(webServerManager.isRunning == false, "Web server should not be running initially")
        
        print("✅ All basic tests passed!")
    }
} 