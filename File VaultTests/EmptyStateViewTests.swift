//
//  EmptyStateViewTests.swift
//  File VaultTests
//
//  Created on 01/08/25.
//

import Testing
import Foundation
import SwiftUI
@testable import File_Vault

struct EmptyStateViewTests {
    
    @Test func testEmptyStateConfiguration() async throws {
        // Test basic configuration creation
        let config = EmptyStateConfiguration(
            id: "test",
            title: "Test Title",
            message: "Test Message",
            systemImage: "photo"
        )
        
        #expect(config.id == "test", "Configuration ID should be set correctly")
        #expect(config.title == "Test Title", "Configuration title should be set correctly")
        #expect(config.message == "Test Message", "Configuration message should be set correctly")
        #expect(config.systemImage == "photo", "Configuration system image should be set correctly")
    }
    
    @Test func testEmptyStateAction() async throws {
        var actionCalled = false
        
        let action = EmptyStateAction(
            title: "Test Action",
            systemImage: "plus",
            action: { actionCalled = true }
        )
        
        #expect(action.title == "Test Action", "Action title should be set correctly")
        #expect(action.systemImage == "plus", "Action system image should be set correctly")
        
        // Test action execution
        action.action()
        #expect(actionCalled == true, "Action should be executed when called")
    }
    
    @Test func testEmptyStateStyles() async throws {
        // Test that all style cases exist
        let styles: [EmptyStateStyle] = [.default, .compact, .prominent]
        
        #expect(styles.count == 3, "Should have 3 empty state styles")
    }
    
    @Test func testEmptyStateAnimations() async throws {
        // Test that all animation cases exist
        let animations: [EmptyStateAnimation] = [.none, .fadeIn, .slideUp, .bounce]
        
        #expect(animations.count == 4, "Should have 4 empty state animations")
    }
    
    @Test func testPredefinedConfigurations() async throws {
        // Test predefined configurations
        let noPhotos = EmptyStateConfiguration.noPhotos(onAddPhotos: {})
        #expect(noPhotos.title == "No Photos", "No photos configuration should have correct title")
        #expect(noPhotos.systemImage == "photo.on.rectangle", "No photos configuration should have correct image")
        
        let noContent = EmptyStateConfiguration.noContent
        #expect(noContent.title == "No Content", "No content configuration should have correct title")
        #expect(noContent.systemImage == "tray", "No content configuration should have correct image")
        
        let emptyFolder = EmptyStateConfiguration.emptyFolder(
            canCreateFolders: true,
            canAddFiles: true,
            onCreateFolder: {},
            onAddFiles: {}
        )
        #expect(emptyFolder.title == "Empty Folder", "Empty folder configuration should have correct title")
        #expect(emptyFolder.systemImage == "folder", "Empty folder configuration should have correct image")
        #expect(emptyFolder.primaryAction != nil, "Empty folder should have primary action")
        #expect(emptyFolder.secondaryAction != nil, "Empty folder should have secondary action")
        
        let noFolders = EmptyStateConfiguration.noFolders(onCreateFolder: {})
        #expect(noFolders.title == "No Folders", "No folders configuration should have correct title")
        #expect(noFolders.systemImage == "folder.badge.plus", "No folders configuration should have correct image")
    }
    
    @Test func testEmptyStateViewCreation() async throws {
        let config = EmptyStateConfiguration(
            id: "test",
            title: "Test",
            message: "Test message",
            systemImage: "star"
        )
        
        let emptyStateView = EmptyStateView(config: config)
        
        // Test that view can be created without errors
        #expect(emptyStateView != nil, "EmptyStateView should be created successfully")
    }
    
    @Test func testConfigurationWithActions() async throws {
        var primaryActionCalled = false
        var secondaryActionCalled = false
        
        let primaryAction = EmptyStateAction(
            title: "Primary",
            systemImage: "plus",
            action: { primaryActionCalled = true }
        )
        
        let secondaryAction = EmptyStateAction(
            title: "Secondary",
            systemImage: "gear",
            action: { secondaryActionCalled = true }
        )
        
        let config = EmptyStateConfiguration(
            id: "test",
            title: "Test",
            message: "Test message",
            systemImage: "star",
            primaryAction: primaryAction,
            secondaryAction: secondaryAction
        )
        
        #expect(config.primaryAction != nil, "Configuration should have primary action")
        #expect(config.secondaryAction != nil, "Configuration should have secondary action")
        
        // Test action execution
        config.primaryAction?.action()
        config.secondaryAction?.action()
        
        #expect(primaryActionCalled == true, "Primary action should be executed")
        #expect(secondaryActionCalled == true, "Secondary action should be executed")
    }
}