import SwiftUI

public enum FolderSortOption: String, CaseIterable {
    case name = "Name"
    case date = "Date"
    case size = "Size"
    case kind = "Kind"

    var systemImage: String {
        switch self {
        case .name: return "textformat.abc"
        case .date: return "calendar"
        case .size: return "arrow.up.arrow.down"
        case .kind: return "folder"
        }
    }
} 