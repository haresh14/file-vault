//
//  EmptyStateViewTests.swift
//  KeepshireTests
//
//  Created on 01/08/25.
//

import Testing
import Foundation
import SwiftUI
@testable import Keepshire

struct EmptyStateViewTests {
    
    @Test func testEmptyStateConfiguration() async throws {
        let config = EmptyStateConfiguration(
            iconName: "photo",
            title: "Test Title",
            subtitle: "Test Message"
        )
        
        #expect(config.title == "Test Title", "Configuration title should be set correctly")
        #expect(config.subtitle == "Test Message", "Configuration subtitle should be set correctly")
        #expect(config.iconName == "photo", "Configuration icon should be set correctly")
    }
    
    @Test func testEmptyStateAction() async throws {
        var actionCalled = false
        
        let action = EmptyStateAction(
            title: "Test Action",
            icon: "plus",
            action: { actionCalled = true }
        )
        
        #expect(action.title == "Test Action", "Action title should be set correctly")
        #expect(action.icon == "plus", "Action icon should be set correctly")
        
        action.action()
        #expect(actionCalled == true, "Action should be executed when called")
    }
    
    @Test func testEmptyStateStyles() async throws {
        let styles: [EmptyStateStyle] = [.default, .compact, .prominent]
        
        #expect(styles.count == 3, "Should have 3 empty state styles")
    }
    
    @Test func testEmptyStateAnimations() async throws {
        let animations: [EmptyStateAnimation] = [.none, .gentle, .dynamic, .playful]
        
        #expect(animations.count == 4, "Should have 4 empty state animations")
        #expect(EmptyStateAnimation.AnimationType.fadeIn == .fadeIn)
        #expect(EmptyStateAnimation.AnimationType.slideUp == .slideUp)
    }
    
    @Test func testPredefinedConfigurations() async throws {
        let noPhotos = EmptyStateConfiguration.noPhotos(onAddPhotos: {})
        #expect(noPhotos.title == "No Photos or Videos", "No photos configuration should have correct title")
        #expect(noPhotos.iconName == "photo.on.rectangle.angled", "No photos configuration should have correct image")
        
        let noContent = EmptyStateConfiguration.noContent
        #expect(noContent.title == "No Content", "No content configuration should have correct title")
        #expect(noContent.iconName == "folder.badge.questionmark", "No content configuration should have correct image")
        
        let emptyFolder = EmptyStateConfiguration.emptyFolder(
            canCreateFolders: true,
            canAddFiles: true,
            onCreateFolder: {},
            onAddFiles: {}
        )
        #expect(emptyFolder.title == "Empty Folder", "Empty folder configuration should have correct title")
        #expect(emptyFolder.iconName == "folder", "Empty folder configuration should have correct image")
        #expect(emptyFolder.primaryAction != nil, "Empty folder should have primary action")
        #expect(emptyFolder.secondaryAction != nil, "Empty folder should have secondary action")
        
        let noFolders = EmptyStateConfiguration.noFolders(onCreateFolder: {})
        #expect(noFolders.title == "No Folders Yet", "No folders configuration should have correct title")
        #expect(noFolders.iconName == "folder.badge.plus", "No folders configuration should have correct image")
    }
    
    @Test func testEmptyStateViewCreation() async throws {
        let config = EmptyStateConfiguration(
            iconName: "star",
            title: "Test",
            subtitle: "Test message"
        )
        
        let emptyStateView = EmptyStateView(config)
        
        #expect(emptyStateView != nil, "EmptyStateView should be created successfully")
    }
    
    @Test func testConfigurationWithActions() async throws {
        var primaryActionCalled = false
        var secondaryActionCalled = false
        
        let primaryAction = EmptyStateAction(
            title: "Primary",
            icon: "plus",
            action: { primaryActionCalled = true }
        )
        
        let secondaryAction = EmptyStateAction(
            title: "Secondary",
            icon: "gear",
            style: .secondary,
            action: { secondaryActionCalled = true }
        )
        
        let config = EmptyStateConfiguration(
            iconName: "star",
            title: "Test",
            subtitle: "Test message",
            primaryAction: primaryAction,
            secondaryAction: secondaryAction
        )
        
        #expect(config.primaryAction != nil, "Configuration should have primary action")
        #expect(config.secondaryAction != nil, "Configuration should have secondary action")
        
        config.primaryAction?.action()
        config.secondaryAction?.action()
        
        #expect(primaryActionCalled == true, "Primary action should be executed")
        #expect(secondaryActionCalled == true, "Secondary action should be executed")
    }
}
