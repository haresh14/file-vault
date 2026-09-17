import SwiftUI

struct EmptyStateActionButton: View {
    private enum Layout {
        static let iconSpacing: CGFloat = 8
        static let horizontalPadding: CGFloat = 24
        static let verticalPadding: CGFloat = 12
        static let maximumWidth: CGFloat = 200
        static let cornerRadius: CGFloat = 10
        static let outlineWidth: CGFloat = 1.5
    }

    let action: EmptyStateAction

    var body: some View {
        Button(action: action.action) {
            HStack(spacing: Layout.iconSpacing) {
                if let icon = action.icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                }
                Text(action.title)
                    .fontWeight(.semibold)
            }
            .foregroundColor(foregroundColor)
            .frame(maxWidth: buttonMaxWidth)
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.vertical, Layout.verticalPadding)
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
        case .secondary, .outline, .link: return .accentColor
        case .custom(_, let foregroundColor): return foregroundColor
        }
    }

    private var backgroundColor: Color {
        switch action.style {
        case .primary: return .accentColor
        case .secondary: return Color(.systemGray5)
        case .outline, .link: return .clear
        case .custom(let backgroundColor, _): return backgroundColor
        }
    }

    private var borderColor: Color {
        action.style.isOutline ? .accentColor : .clear
    }

    private var borderWidth: CGFloat {
        action.style.isOutline ? Layout.outlineWidth : 0
    }

    private var buttonMaxWidth: CGFloat? {
        action.style.isLink ? nil : Layout.maximumWidth
    }

    private var buttonCornerRadius: CGFloat {
        action.style.isLink ? 0 : Layout.cornerRadius
    }
}

private extension EmptyStateAction.ActionStyle {
    var isOutline: Bool {
        if case .outline = self { return true }
        return false
    }

    var isLink: Bool {
        if case .link = self { return true }
        return false
    }
}
