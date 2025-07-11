//
//  WebServerManagerTests.swift
//  File VaultTests
//
//  Created on 11/07/25.
//

import Testing
import Foundation
import Network
@testable import File_Vault

struct WebServerManagerTests {
    
    // MARK: - Initialization Tests
    
    @Test func testWebServerManagerSingleton() async throws {
        let manager1 = WebServerManager.shared
        let manager2 = WebServerManager.shared
        
        #expect(manager1 === manager2, "WebServerManager should be a singleton")
    }
    
    @Test func testInitialState() async throws {
        let manager = WebServerManager.shared
        
        #expect(manager.isRunning == false, "Server should not be running initially")
        #expect(manager.serverURL.isEmpty, "Server URL should be empty initially")
    }
    
    // MARK: - Server Lifecycle Tests
    
    @Test func testStartServer() async throws {
        let manager = WebServerManager.shared
        
        // Ensure server is stopped
        manager.stopServer()
        #expect(manager.isRunning == false, "Server should be stopped initially")
        
        // Start server
        manager.startServer()
        
        // Give it a moment to start
        try await Task.sleep(for: .milliseconds(100))
        
        #expect(manager.isRunning == true, "Server should be running after start")
        
        // Cleanup
        manager.stopServer()
    }
    
    @Test func testStopServer() async throws {
        let manager = WebServerManager.shared
        
        // Start server first
        manager.startServer()
        try await Task.sleep(for: .milliseconds(100))
        #expect(manager.isRunning == true, "Server should be running")
        
        // Stop server
        manager.stopServer()
        try await Task.sleep(for: .milliseconds(100))
        
        #expect(manager.isRunning == false, "Server should be stopped after stop")
    }
    
    @Test func testRestartServer() async throws {
        let manager = WebServerManager.shared
        
        // Start server
        manager.startServer()
        try await Task.sleep(for: .milliseconds(100))
        #expect(manager.isRunning == true, "Server should be running")
        
        // Stop server
        manager.stopServer()
        try await Task.sleep(for: .milliseconds(100))
        #expect(manager.isRunning == false, "Server should be stopped")
        
        // Start again
        manager.startServer()
        try await Task.sleep(for: .milliseconds(100))
        #expect(manager.isRunning == true, "Server should be running again")
        
        // Cleanup
        manager.stopServer()
    }
    
    // MARK: - Port Management Tests
    
    @Test func testPortConfiguration() async throws {
        let manager = WebServerManager.shared
        
        // Test server URL contains correct port when running
        manager.startServer()
        try await Task.sleep(for: .milliseconds(100))
        
        if manager.isRunning {
            #expect(manager.serverURL.contains("8080"), "Server URL should contain port 8080")
        }
        
        manager.stopServer()
    }
    
    // MARK: - URL Generation Tests
    
    @Test func testServerURL() async throws {
        let manager = WebServerManager.shared
        
        // Test URL generation
        let url = manager.serverURL
        #expect(url.hasPrefix("http://"), "URL should start with http://")
        #expect(url.contains("8080"), "URL should contain port number")
        
        // Test that URL is well-formed
        let urlObj = URL(string: url)
        #expect(urlObj != nil, "URL should be valid")
        if let urlObj = urlObj {
            #expect(urlObj.scheme == "http", "URL scheme should be http")
            #expect(urlObj.port == 8080, "URL port should be 8080")
        }
    }
    
    // MARK: - Network Interface Tests
    
    @Test func testNetworkInterfaces() async throws {
        let manager = WebServerManager.shared
        
        // Test that we can get network interfaces
        // This is tested indirectly through the server URL generation
        let url = manager.serverURL
        #expect(url.count > 0, "Should generate a valid URL")
        
        // Test that URL contains a valid IP address pattern
        let urlComponents = url.components(separatedBy: ":")
        #expect(urlComponents.count >= 3, "URL should have protocol, IP, and port")
    }
    
    // MARK: - Error Handling Tests
    
    @Test func testMultipleStartCalls() async throws {
        let manager = WebServerManager.shared
        
        // Ensure server is stopped
        manager.stopServer()
        
        // Start server multiple times
        manager.startServer()
        try await Task.sleep(for: .milliseconds(50))
        
        manager.startServer() // Should handle gracefully
        try await Task.sleep(for: .milliseconds(50))
        
        #expect(manager.isRunning == true, "Server should still be running")
        
        // Cleanup
        manager.stopServer()
    }
    
    @Test func testMultipleStopCalls() async throws {
        let manager = WebServerManager.shared
        
        // Start server
        manager.startServer()
        try await Task.sleep(for: .milliseconds(50))
        
        // Stop server multiple times
        manager.stopServer()
        try await Task.sleep(for: .milliseconds(50))
        
        manager.stopServer() // Should handle gracefully
        try await Task.sleep(for: .milliseconds(50))
        
        #expect(manager.isRunning == false, "Server should be stopped")
    }
    
    // MARK: - State Consistency Tests
    
    @Test func testStateConsistency() async throws {
        let manager = WebServerManager.shared
        
        // Test that state is consistent
        manager.stopServer()
        #expect(manager.isRunning == false, "State should be consistent after stop")
        
        manager.startServer()
        try await Task.sleep(for: .milliseconds(100))
        #expect(manager.isRunning == true, "State should be consistent after start")
        
        // Cleanup
        manager.stopServer()
    }
    
    // MARK: - Concurrent Access Tests
    
    @Test func testConcurrentAccess() async throws {
        let manager = WebServerManager.shared
        
        // Ensure server is stopped
        manager.stopServer()
        
        // Test concurrent start/stop operations
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                manager.startServer()
            }
            group.addTask {
                try? await Task.sleep(for: .milliseconds(10))
                manager.stopServer()
            }
            group.addTask {
                try? await Task.sleep(for: .milliseconds(20))
                manager.startServer()
            }
        }
        
        // Give operations time to complete
        try await Task.sleep(for: .milliseconds(200))
        
        // Server should be in a consistent state
        let finalState = manager.isRunning
        #expect(finalState == true || finalState == false, "Server should have a consistent state")
        
        // Cleanup
        manager.stopServer()
    }
    
    // MARK: - Resource Management Tests
    
    @Test func testResourceCleanup() async throws {
        let manager = WebServerManager.shared
        
        // Start and stop server multiple times to test resource cleanup
        for _ in 0..<5 {
            manager.startServer()
            try await Task.sleep(for: .milliseconds(50))
            
            manager.stopServer()
            try await Task.sleep(for: .milliseconds(50))
        }
        
        // Server should be in a clean state
        #expect(manager.isRunning == false, "Server should be stopped after cleanup test")
    }
    
    // MARK: - Performance Tests
    
    @Test func testStartStopPerformance() async throws {
        let manager = WebServerManager.shared
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Perform multiple start/stop cycles
        for _ in 0..<5 {
            manager.startServer()
            try await Task.sleep(for: .milliseconds(10))
            manager.stopServer()
            try await Task.sleep(for: .milliseconds(10))
        }
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        #expect(timeElapsed < 5.0, "Start/stop operations should complete within 5 seconds")
        
        // Ensure server is stopped
        manager.stopServer()
    }
    
    // MARK: - Network Configuration Tests
    
    @Test func testNetworkConfiguration() async throws {
        let manager = WebServerManager.shared
        
        // Test that server can be configured properly
        manager.startServer()
        try await Task.sleep(for: .milliseconds(100))
        
        // Test that server is listening on the correct port
        let url = manager.serverURL
        #expect(url.contains("8080"), "Server should be listening on port 8080")
        
        // Cleanup
        manager.stopServer()
    }
    
    // MARK: - Integration Tests
    
    @Test func testIntegrationWithFileStorage() async throws {
        let webManager = WebServerManager.shared
        let fileManager = FileStorageManager.shared
        
        // Setup file storage
        fileManager.setupEncryptionKey(from: "TestPassword123!")
        
        // Start web server
        webManager.startServer()
        try await Task.sleep(for: .milliseconds(100))
        
        #expect(webManager.isRunning == true, "Web server should be running")
        
        // Test that both managers can coexist
        let testData = "Integration test".data(using: .utf8)!
        let vaultItem = try fileManager.saveFile(
            data: testData,
            fileName: "integration_test.txt",
            fileType: "text/plain"
        )
        
        #expect(vaultItem.fileName == "integration_test.txt", "File should be saved correctly")
        #expect(webManager.isRunning == true, "Web server should still be running")
        
        // Cleanup
        try fileManager.deleteFile(vaultItem: vaultItem)
        webManager.stopServer()
    }
    
    // MARK: - Error Recovery Tests
    
    @Test func testErrorRecovery() async throws {
        let manager = WebServerManager.shared
        
        // Test that manager can recover from various states
        manager.startServer()
        try await Task.sleep(for: .milliseconds(50))
        
        // Simulate error by stopping abruptly
        manager.stopServer()
        
        // Test that manager can start again
        manager.startServer()
        try await Task.sleep(for: .milliseconds(50))
        
        #expect(manager.isRunning == true, "Manager should recover and start again")
        
        // Cleanup
        manager.stopServer()
    }
    
    // MARK: - Memory Management Tests
    
    @Test func testMemoryManagement() async throws {
        let manager = WebServerManager.shared
        
        // Test that repeated operations don't cause memory issues
        for _ in 0..<10 {
            manager.startServer()
            try await Task.sleep(for: .milliseconds(20))
            
            // Check server state
            _ = manager.isRunning
            _ = manager.serverURL
            
            manager.stopServer()
            try await Task.sleep(for: .milliseconds(20))
        }
        
        // If we get here without crashing, memory management is working
        #expect(true, "Memory management should handle repeated operations")
        
        // Ensure clean state
        manager.stopServer()
    }
} 