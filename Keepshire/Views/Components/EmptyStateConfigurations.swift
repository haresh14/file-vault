import Foundation

extension EmptyStateConfiguration {
    static func noPhotos(onAddPhotos: @escaping () -> Void) -> EmptyStateConfiguration {
        EmptyStateConfiguration(
            iconName: "photo.on.rectangle.angled",
            title: "No Photos or Videos",
            subtitle: "Add photos and videos to see them here in your gallery",
            primaryAction: EmptyStateAction(title: "Add Photos", icon: "camera", action: onAddPhotos)
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
            primaryAction: canAddFiles
                ? EmptyStateAction(title: "Add Files", icon: "plus", action: onAddFiles)
                : nil,
            secondaryAction: canCreateFolders
                ? EmptyStateAction(
                    title: "Create Folder",
                    icon: "folder.badge.plus",
                    style: .secondary,
                    action: onCreateFolder
                )
                : nil
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
            )
        )
    }

    static let noContent = EmptyStateConfiguration(
        iconName: "folder.badge.questionmark",
        title: "No Content",
        subtitle: "This area appears to be empty"
    )

    static func emptyTrash() -> EmptyStateConfiguration {
        EmptyStateConfiguration(
            iconName: "trash",
            title: "Trash is Empty",
            subtitle: "Deleted files will appear here"
        )
    }
}
