//
//  EmptyStateView.swift
//  File Vault
//
//  Created on 10/07/25.
//

import SwiftUI

/// Comprehensive empty state configuration with animation and styling options
struct EmptyStateConfiguration {
    // MARK: - Content Properties
    let iconName: String?
    let customIcon: AnyView?
    let title: String
    let subtitle: String?
    let additionalMessage: String?
    
    // MARK: - Action Properties
    let primaryAction: EmptyStateAction?
    let secondaryAction: EmptyStateAction?
    
    // MARK: - Style Properties
    let style: EmptyStateStyle
    let animation: EmptyStateAnimation
    let spacing: CGFloat
    
    // MARK: - Layout Properties
    let maxWidth: CGFloat?
    let contentPadding: EdgeInsets
    
    init(
        iconName: String? = nil,
        customIcon: AnyView? = nil,
        title: String,
        subtitle: String? = nil,
        additionalMessage: String? = nil,
        primaryAction: EmptyStateAction? = nil,
        secondaryAction: EmptyStateAction? = nil,
        style: EmptyStateStyle = .default,
        animation: EmptyStateAnimation = .gentle,
        spacing: CGFloat = 20,
        maxWidth: CGFloat? = 400,
        contentPadding: EdgeInsets = EdgeInsets(top: 40, leading: 20, bottom: 40, trailing: 20)
    ) {
        self.iconName = iconName
        self.customIcon = customIcon
        self.title = title
        self.subtitle = subtitle
        self.additionalMessage = additionalMessage
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
        self.style = style
        self.animation = animation
        self.spacing = spacing
        self.maxWidth = maxWidth
        self.contentPadding = contentPadding
    }
}

/// Action configuration for empty state buttons
struct EmptyStateAction {
    let title: String
    let icon: String?
    let style: ActionStyle
    let action: () -> Void
    
    enum ActionStyle {
        case primary
        case secondary
        case outline
        case link
        case custom(backgroundColor: Color, foregroundColor: Color)
    }
    
    init(
        title: String,
        icon: String? = nil,
        style: ActionStyle = .primary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
    }
}

/// Style configuration for empty state appearance
struct EmptyStateStyle {
    let iconSize: CGFloat
    let iconColor: Color
    let titleFont: Font
    let titleColor: Color
    let subtitleFont: Font
    let subtitleColor: Color
    let backgroundColor: Color?
    
    static let `default` = EmptyStateStyle(
        iconSize: 80,
        iconColor: .gray,
        titleFont: .title2,
        titleColor: .primary,
        subtitleFont: .body,
        subtitleColor: .secondary,
        backgroundColor: nil
    )
    
    static let compact = EmptyStateStyle(
        iconSize: 60,
        iconColor: .gray,
        titleFont: .headline,
        titleColor: .primary,
        subtitleFont: .subheadline,
        subtitleColor: .secondary,
        backgroundColor: nil
    )
    
    static let prominent = EmptyStateStyle(
        iconSize: 100,
        iconColor: .accentColor,
        titleFont: .largeTitle,
        titleColor: .primary,
        subtitleFont: .title3,
        subtitleColor: .secondary,
        backgroundColor: Color(.systemGray6)
    )
}

/// Animation configuration for empty state appearance
struct EmptyStateAnimation {
    let enabled: Bool
    let delay: Double
    let duration: Double
    let type: AnimationType
    
    enum AnimationType {
        case fadeIn
        case slideUp
        case scale
        case bounce
        case none
    }
    
    static let gentle = EmptyStateAnimation(
        enabled: true,
        delay: 0.2,
        duration: 0.6,
        type: .fadeIn
    )
    
    static let dynamic = EmptyStateAnimation(
        enabled: true,
        delay: 0.1,
        duration: 0.8,
        type: .slideUp
    )
    
    static let playful = EmptyStateAnimation(
        enabled: true,
        delay: 0.3,
        duration: 1.0,
        type: .bounce
    )
    
    static let none = EmptyStateAnimation(
        enabled: false,
        delay: 0,
        duration: 0,
        type: .none
    )
}

/// Main reusable empty state view component
struct EmptyStateView: View {
    let configuration: EmptyStateConfiguration
    @State private var isVisible = false
    
    init(_ configuration: EmptyStateConfiguration) {
        self.configuration = configuration
    }
    
    var body: some View {
        VStack(spacing: configuration.spacing) {
            // Icon
            if let customIcon = configuration.customIcon {
                customIcon
            } else if let iconName = configuration.iconName {
                Image(systemName: iconName)
                    .font(.system(size: configuration.style.iconSize))
                    .foregroundColor(configuration.style.iconColor)
            }
            
            // Title
            Text(configuration.title)
                .font(configuration.style.titleFont)
                .fontWeight(.semibold)
                .foregroundColor(configuration.style.titleColor)
                .multilineTextAlignment(.center)
            
            // Subtitle
            if let subtitle = configuration.subtitle {
                Text(subtitle)
                    .font(configuration.style.subtitleFont)
                    .foregroundColor(configuration.style.subtitleColor)
                    .multilineTextAlignment(.center)
            }
            
            // Additional Message
            if let additionalMessage = configuration.additionalMessage {
                Text(additionalMessage)
                    .font(.caption)
                    .foregroundColor(Color.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 5)
            }
            
            // Actions
            if configuration.primaryAction != nil || configuration.secondaryAction != nil {
                VStack(spacing: 12) {
                    if let primaryAction = configuration.primaryAction {
                        EmptyStateActionButton(action: primaryAction)
                    }
                    
                    if let secondaryAction = configuration.secondaryAction {
                        EmptyStateActionButton(action: secondaryAction)
                    }
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: configuration.maxWidth)
        .padding(configuration.contentPadding)
        .background(configuration.style.backgroundColor)
        .cornerRadius(configuration.style.backgroundColor != nil ? 12 : 0)
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.8)
        .offset(y: isVisible ? 0 : 20)
        .onAppear {
            if configuration.animation.enabled {
                withAnimation(
                    .easeOut(duration: configuration.animation.duration)
                    .delay(configuration.animation.delay)
                ) {
                    isVisible = true
                }
            } else {
                isVisible = true
            }
        }
    }
}

/// Action button component for empty states
private struct EmptyStateActionButton: View {
    let action: EmptyStateAction
    
    var body: some View {
        Button(action: action.action) {
            HStack(spacing: 8) {
                if let icon = action.icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                }
                Text(action.title)
                    .fontWeight(.semibold)
            }
            .foregroundColor(foregroundColor)
            .frame(maxWidth: buttonMaxWidth)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(backgroundColor)
            .cornerRadius(buttonCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: buttonCornerRadius)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
        }
    }
    
    private var foregroundColor: Color {
        switch action.style {
        case .primary: return .white
        case .secondary: return .accentColor
        case .outline: return .accentColor
        case .link: return .accentColor
        case .custom(_, let foregroundColor): return foregroundColor
        }
    }
    
    private var backgroundColor: Color {
        switch action.style {
        case .primary: return .accentColor
        case .secondary: return Color(.systemGray5)
        case .outline: return .clear
        case .link: return .clear
        case .custom(let backgroundColor, _): return backgroundColor
        }
    }
    
    private var borderColor: Color {
        switch action.style {
        case .outline: return .accentColor
        case .link: return .clear
        default: return .clear
        }
    }
    
    private var borderWidth: CGFloat {
        switch action.style {
        case .outline: return 1.5
        default: return 0
        }
    }
    
    private var buttonMaxWidth: CGFloat? {
        switch action.style {
        case .link: return nil
        default: return 200
        }
    }
    
    private var buttonCornerRadius: CGFloat {
        switch action.style {
        case .link: return 0
        default: return 10
        }
    }
}

// MARK: - Predefined Configurations

extension EmptyStateConfiguration {
    // MARK: - File Vault Specific
    
    static func noFiles(onAddFiles: @escaping () -> Void) -> EmptyStateConfiguration {
        EmptyStateConfiguration(
            iconName: "doc.badge.plus",
            title: "No Files Yet",
            subtitle: "Add your first files to get started with File Vault",
            primaryAction: EmptyStateAction(
                title: "Add Files",
                icon: "plus",
                action: onAddFiles
            ),
            style: .default
        )
    }
    
    static func noPhotos(onAddPhotos: @escaping () -> Void) -> EmptyStateConfiguration {
        EmptyStateConfiguration(
            iconName: "photo.on.rectangle.angled",
            title: "No Photos or Videos",
            subtitle: "Add photos and videos to see them here in your gallery",
            primaryAction: EmptyStateAction(
                title: "Add Photos",
                icon: "camera",
                action: onAddPhotos
            ),
            style: .default
        )
    }
    
    static func emptyFolder(
        canCreateFolders: Bool = true,
        canAddFiles: Bool = true,
        onCreateFolder: @escaping () -> Void = {},
        onAddFiles: @escaping () -> Void = {}
    ) -> EmptyStateConfiguration {
        EmptyStateConfiguration(
            iconName: "folder",
            title: "Empty Folder",
            subtitle: "Add files or create subfolders to organize your content",
            primaryAction: canAddFiles ? EmptyStateAction(
                title: "Add Files",
                icon: "plus",
                action: onAddFiles
            ) : nil,
            secondaryAction: canCreateFolders ? EmptyStateAction(
                title: "Create Folder",
                icon: "folder.badge.plus",
                style: .secondary,
                action: onCreateFolder
            ) : nil,
            style: .default
        )
    }
    
    static func noFolders(onCreateFolder: @escaping () -> Void) -> EmptyStateConfiguration {
        EmptyStateConfiguration(
            iconName: "folder.badge.plus",
            title: "No Folders Yet",
            subtitle: "Create folders to organize your files",
            primaryAction: EmptyStateAction(
                title: "Create Folder",
                icon: "folder.badge.plus",
                action: onCreateFolder
            ),
            style: .default
        )
    }
    
    // MARK: - Search & Filter States
    
    static func noSearchResults(searchText: String, onClearSearch: @escaping () -> Void) -> EmptyStateConfiguration {
        EmptyStateConfiguration(
            iconName: "magnifyingglass",
            title: "No Results Found",
            subtitle: "No items match \"\\(searchText)\"",
            additionalMessage: "Try adjusting your search terms or browse all files",
            primaryAction: EmptyStateAction(
                title: "Clear Search",
                icon: "xmark.circle",
                style: .secondary,
                action: onClearSearch
            ),
            style: .compact
        )
    }
    
    static func noFilterResults(filterName: String, onClearFilter: @escaping () -> Void) -> EmptyStateConfiguration {
        EmptyStateConfiguration(
            iconName: "line.horizontal.3.decrease.circle",
            title: "No \\(filterName) Files",
            subtitle: "Try selecting a different filter or browse all files",
            primaryAction: EmptyStateAction(
                title: "Clear Filter",
                icon: "xmark.circle",
                style: .secondary,
                action: onClearFilter
            ),
            style: .compact
        )
    }
    
    // MARK: - Error & Loading States
    
    static func loadingError(onRetry: @escaping () -> Void) -> EmptyStateConfiguration {
        EmptyStateConfiguration(
            iconName: "exclamationmark.triangle",
            title: "Unable to Load",
            subtitle: "Something went wrong while loading your files",
            additionalMessage: "Check your connection and try again",
            primaryAction: EmptyStateAction(
                title: "Try Again",
                icon: "arrow.clockwise",
                action: onRetry
            ),
            style: .default
        )
    }
    
    static func accessDenied(onRequestAccess: @escaping () -> Void) -> EmptyStateConfiguration {
        EmptyStateConfiguration(
            iconName: "lock",
            title: "Access Required",
            subtitle: "File Vault needs permission to access your files",
            primaryAction: EmptyStateAction(
                title: "Grant Access",
                icon: "key",
                action: onRequestAccess
            ),
            style: .default
        )
    }
    
    // MARK: - Generic States
    
    static let noContent = EmptyStateConfiguration(
        iconName: "folder.badge.questionmark",
        title: "No Content",
        subtitle: "This area appears to be empty",
        style: .default
    )
    
    static func emptyTrash() -> EmptyStateConfiguration {
        EmptyStateConfiguration(
            iconName: "trash",
            title: "Trash is Empty",
            subtitle: "Deleted files will appear here",
            style: .default
        )
    }
    
    static let comingSoon = EmptyStateConfiguration(
        iconName: "clock",
        title: "Coming Soon",
        subtitle: "This feature is under development",
        style: .compact
    )
    
    static func maintenance(estimatedTime: String) -> EmptyStateConfiguration {
        EmptyStateConfiguration(
            iconName: "wrench.and.screwdriver",
            title: "Under Maintenance",
            subtitle: "We're making improvements to serve you better",
            additionalMessage: "Estimated time: \\(estimatedTime)",
            style: .default
        )
    }
}

// MARK: - View Extensions

extension View {
    /// Conditionally shows empty state based on a condition
    func emptyState(
        _ isEmpty: Bool,
        configuration: EmptyStateConfiguration
    ) -> some View {
        ZStack {
            self
                .opacity(isEmpty ? 0 : 1)
            
            if isEmpty {
                EmptyStateView(configuration)
            }
        }
    }
    
    /// Shows empty state for array-based content
    func emptyState<T>(
        for items: [T],
        configuration: EmptyStateConfiguration
    ) -> some View {
        emptyState(items.isEmpty, configuration: configuration)
    }
}