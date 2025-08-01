//
//  DependencyContainerTests.swift
//  File VaultTests
//
//  Created on 01/08/25.
//

import Testing
import Foundation
@testable import File_Vault

struct DependencyContainerTests {
    
    @Test func testDependencyContainerSingleton() async throws {
        let container1 = DependencyContainer.shared
        let container2 = DependencyContainer.shared
        
        #expect(container1 === container2, "DependencyContainer should be a singleton")
    }
    
    @Test func testAllManagersAvailable() async throws {
        let container = DependencyContainer.shared
        
        // Test that all managers are available
        #expect(container.coreDataManager != nil, "CoreDataManager should be available")
        #expect(container.fileStorageManager != nil, "FileStorageManager should be available")
        #expect(container.keychainManager != nil, "KeychainManager should be available")
        #expect(container.biometricAuthManager != nil, "BiometricAuthManager should be available")
        #expect(container.loginStateManager != nil, "LoginStateManager should be available")
        #expect(container.securityManager != nil, "SecurityManager should be available")
        #expect(container.webServerManager != nil, "WebServerManager should be available")
        #expect(container.appDataManager != nil, "AppDataManager should be available")
    }
    
    @Test func testCreateForTesting() async throws {
        // Test that createForTesting returns a different instance
        let testContainer = DependencyContainer.createForTesting()
        let sharedContainer = DependencyContainer.shared
        
        #expect(testContainer !== sharedContainer, "Test container should be different from shared instance")
        
        // Test that all managers are still available in test container
        #expect(testContainer.coreDataManager != nil, "Test container should have CoreDataManager")
        #expect(testContainer.fileStorageManager != nil, "Test container should have FileStorageManager")
        #expect(testContainer.keychainManager != nil, "Test container should have KeychainManager")
        #expect(testContainer.biometricAuthManager != nil, "Test container should have BiometricAuthManager")
        #expect(testContainer.loginStateManager != nil, "Test container should have LoginStateManager")
        #expect(testContainer.securityManager != nil, "Test container should have SecurityManager")
        #expect(testContainer.webServerManager != nil, "Test container should have WebServerManager")
        #expect(testContainer.appDataManager != nil, "Test container should have AppDataManager")
    }
    
    @Test func testProtocolConformance() async throws {
        let container = DependencyContainer.shared
        
        // Test that managers conform to their protocols
        #expect(container.coreDataManager is CoreDataManaging, "CoreDataManager should conform to CoreDataManaging")
        #expect(container.fileStorageManager is FileStorageManaging, "FileStorageManager should conform to FileStorageManaging")
        #expect(container.keychainManager is KeychainManaging, "KeychainManager should conform to KeychainManaging")
        #expect(container.biometricAuthManager is BiometricAuthManaging, "BiometricAuthManager should conform to BiometricAuthManaging")
        #expect(container.loginStateManager is LoginStateManaging, "LoginStateManager should conform to LoginStateManaging")
        #expect(container.securityManager is SecurityManaging, "SecurityManager should conform to SecurityManaging")
        #expect(container.webServerManager is WebServerManaging, "WebServerManager should conform to WebServerManaging")
        #expect(container.appDataManager is AppDataManaging, "AppDataManager should conform to AppDataManaging")
    }
}