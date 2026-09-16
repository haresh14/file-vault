import SwiftUI

struct EmptyStateConfiguration {
    let iconName: String?
    let customIcon: AnyView?
    let title: String
    let subtitle: String?
    let additionalMessage: String?
    let primaryAction: EmptyStateAction?
    let secondaryAction: EmptyStateAction?
    let style: EmptyStateStyle
    let animation: EmptyStateAnimation
    let spacing: CGFloat
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

    static let gentle = EmptyStateAnimation(enabled: true, delay: 0.2, duration: 0.6, type: .fadeIn)
    static let dynamic = EmptyStateAnimation(enabled: true, delay: 0.1, duration: 0.8, type: .slideUp)
    static let playful = EmptyStateAnimation(enabled: true, delay: 0.3, duration: 1.0, type: .bounce)
    static let none = EmptyStateAnimation(enabled: false, delay: 0, duration: 0, type: .none)
}
