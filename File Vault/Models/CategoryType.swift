import SwiftUI

/// Represents the top-level item categories displayed in the vault.
///
/// Keeping this model separate from any particular view makes it reusable
/// across the project (e.g. in `VaultMainView`, filters, etc.).
public enum CategoryType: String, CaseIterable {
    case photos = "Photos"
    case videos = "Videos"
    case audio = "Audio"
    case documents = "Documents"
    case other = "Other"
    case allFiles = "All Files"

    /// System SF Symbol associated with each category.
    var systemImage: String {
        switch self {
        case .photos: return "photo"
        case .videos: return "video"
        case .audio: return "music.note"
        case .documents: return "doc"
        case .other: return "doc.questionmark"
        case .allFiles: return "folder"
        }
    }

    /// Primary accent color used for iconography in the UI.
    var color: Color {
        switch self {
        case .photos: return .blue
        case .videos: return .purple
        case .audio: return .green
        case .documents: return .orange
        case .other: return .brown
        case .allFiles: return .gray
        }
    }
} 