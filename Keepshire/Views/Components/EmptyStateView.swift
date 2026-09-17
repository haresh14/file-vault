import SwiftUI

struct EmptyStateView: View {
    private enum Layout {
        static let actionsSpacing: CGFloat = 12
        static let actionsTopPadding: CGFloat = 8
        static let additionalMessageTopPadding: CGFloat = 5
        static let backgroundCornerRadius: CGFloat = 12
        static let hiddenScale: CGFloat = 0.8
        static let hiddenOffset: CGFloat = 20
    }

    let configuration: EmptyStateConfiguration
    @State private var isVisible = false

    init(_ configuration: EmptyStateConfiguration) {
        self.configuration = configuration
    }

    var body: some View {
        VStack(spacing: configuration.spacing) {
            icon

            Text(configuration.title)
                .font(configuration.style.titleFont)
                .fontWeight(.semibold)
                .foregroundColor(configuration.style.titleColor)
                .multilineTextAlignment(.center)

            if let subtitle = configuration.subtitle {
                Text(subtitle)
                    .font(configuration.style.subtitleFont)
                    .foregroundColor(configuration.style.subtitleColor)
                    .multilineTextAlignment(.center)
            }

            if let additionalMessage = configuration.additionalMessage {
                Text(additionalMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, Layout.additionalMessageTopPadding)
            }

            actions
        }
        .frame(maxWidth: configuration.maxWidth)
        .padding(configuration.contentPadding)
        .background(configuration.style.backgroundColor)
        .cornerRadius(configuration.style.backgroundColor == nil ? 0 : Layout.backgroundCornerRadius)
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : Layout.hiddenScale)
        .offset(y: isVisible ? 0 : Layout.hiddenOffset)
        .onAppear(perform: reveal)
    }

    @ViewBuilder
    private var icon: some View {
        if let customIcon = configuration.customIcon {
            customIcon
        } else if let iconName = configuration.iconName {
            Image(systemName: iconName)
                .font(.system(size: configuration.style.iconSize))
                .foregroundColor(configuration.style.iconColor)
        }
    }

    @ViewBuilder
    private var actions: some View {
        if configuration.primaryAction != nil || configuration.secondaryAction != nil {
            VStack(spacing: Layout.actionsSpacing) {
                if let primaryAction = configuration.primaryAction {
                    EmptyStateActionButton(action: primaryAction)
                }
                if let secondaryAction = configuration.secondaryAction {
                    EmptyStateActionButton(action: secondaryAction)
                }
            }
            .padding(.top, Layout.actionsTopPadding)
        }
    }

    private func reveal() {
        guard configuration.animation.enabled else {
            isVisible = true
            return
        }

        withAnimation(
            .easeOut(duration: configuration.animation.duration)
                .delay(configuration.animation.delay)
        ) {
            isVisible = true
        }
    }
}

extension View {
    func emptyState(
        _ isEmpty: Bool,
        configuration: EmptyStateConfiguration
    ) -> some View {
        ZStack {
            self.opacity(isEmpty ? 0 : 1)
            if isEmpty {
                EmptyStateView(configuration)
            }
        }
    }

    func emptyState<T>(
        for items: [T],
        configuration: EmptyStateConfiguration
    ) -> some View {
        emptyState(items.isEmpty, configuration: configuration)
    }
}
