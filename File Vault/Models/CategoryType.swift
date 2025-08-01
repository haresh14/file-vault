import SwiftUI

/// Represents the top-level item categories displayed in the vault.
///
/// Keeping this model separate from any particular view makes it reusable
/// across the project (e.g. in `VaultMainView`, filters, etc.).
public enum CategoryType: String, CaseIterable {
    case photos = "Photos"
    case videos = "Videos"
    case documents = "Documents"
    case allFiles = "All Files"

    /// System SF Symbol associated with each category.
    var systemImage: String {
        switch self {
        case .photos: return "photo"
        case .videos: return "video"
        case .documents: return "doc"
        case .allFiles: return "folder"
        }
    }

    /// Primary accent color used for iconography in the UI.
    var color: Color {
        switch self {
        case .photos: return .blue
        case .videos: return .purple
        case .documents: return .orange
        case .allFiles: return .gray
        }
    }
} 