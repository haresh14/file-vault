//
//  SortOption.swift
//  File Vault
//
//  Created on 10/07/25.
//

import Foundation

enum SortOption: String, CaseIterable {
    case userDefault = "User Default"
    case name = "Name"
    case size = "Size"
    case date = "Date"
    case kind = "Kind"
    case favorites = "Favorites"
    
    var systemImage: String {
        switch self {
        case .userDefault:
            return "person"
        case .name:
            return "textformat.abc"
        case .size:
            return "arrow.up.arrow.down"
        case .date:
            return "calendar"
        case .kind:
            return "folder"
        case .favorites:
            return "heart.fill"
        }
    }
}