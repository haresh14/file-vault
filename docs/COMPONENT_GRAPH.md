# Component graph

How File Vault is composed. `FileStorageManager`, `CoreDataManager`, `SecurityManager`, and `WebServerManager` are the public manager entry points; focused files behind them do the work.

## 1. Runtime layers

```mermaid
flowchart TB
    subgraph App["App"]
        FileVaultApp
        ContentView
        AuthCoordinator["AuthenticationCoordinator"]
    end

    subgraph UI["Views"]
        MainTabView
        FolderView
        CategoryView
        VaultMainView["VaultMainView (Gallery)"]
        WebUploadTabView
        SettingsView
        Media["UnifiedMediaViewerView / FilePreviewView"]
    end

    subgraph VM["View models"]
        FolderViewModel
        CategoryViewModel
        CategoryFilesViewModel
        VaultMainViewModel
        TrashViewModel
    end

    subgraph Services["Shared services"]
        VaultImportService
        ShareManager
        NotificationManager
    end

    subgraph Facades["Manager facades"]
        FileStorageManager
        CoreDataManager
        SecurityManager
        WebServerManager
        KeychainManager
        BiometricAuthManager
        LoginStateManager
        AppDataManager
        BackgroundUploadManager
    end

    subgraph Persist["Persistence"]
        SQLite["FileVault.sqlite (sealed metadata JSON)"]
        VaultDir["Documents/Vault (AES-GCM, UUID names)"]
        Thumbs["Documents/Thumbnails (AES-GCM, {uuid}.thumb)"]
        Keychain["Keychain (credential + PBKDF2 salt)"]
        Defaults["UserDefaults"]
    end

    FileVaultApp --> ContentView
    FileVaultApp --> DI["DependencyContainer"]
    ContentView --> AuthCoordinator
    ContentView --> SecurityManager
    ContentView --> MainTabView
    AuthCoordinator --> KeychainManager
    AuthCoordinator --> BiometricAuthManager
    AuthCoordinator --> LoginStateManager
    AuthCoordinator --> FileStorageManager

    MainTabView --> FolderView
    MainTabView --> CategoryView
    MainTabView --> VaultMainView
    MainTabView --> WebUploadTabView
    MainTabView --> SettingsView

    FolderView --> FolderViewModel
    CategoryView --> CategoryViewModel
    CategoryView --> CategoryFilesViewModel
    VaultMainView --> VaultMainViewModel
    SettingsView --> TrashViewModel

    FolderViewModel --> VaultImportService
    VaultMainViewModel --> VaultImportService
    VaultImportService --> FileStorageManager

    FolderViewModel --> FileStorageManager
    VaultMainViewModel --> FileStorageManager
    CategoryFilesViewModel --> CoreDataManager
    TrashViewModel --> FileStorageManager

    FileStorageManager --> CoreDataManager
    FileStorageManager --> VaultDir
    FileStorageManager --> Thumbs
    CoreDataManager --> SQLite
    KeychainManager --> Keychain
    SecurityManager --> Defaults
    WebServerManager --> FileStorageManager
    WebServerManager --> CoreDataManager
    WebServerManager --> BackgroundUploadManager
    DI --> Facades
```

## 2. Authentication and lock

`ContentView` owns the gate. `AuthenticationCoordinator` owns first-launch, biometric delay/fallback, scene-phase auto-lock, fake-login reset, and encryption-key setup. `SecurityManager` can post `.triggerSecurityLock`.

```mermaid
flowchart TD
    Launch["FileVaultApp"] --> CV["ContentView"]
    CV --> AC["AuthenticationCoordinator"]

    AC -->|"auth type not set"| ATS["AuthTypeSelectionView"]
    ATS --> Setup["PasscodeSetupView / PasswordSetupView"]
    AC -->|"password not set"| PVSet["PasscodeView isSettingPasscode"]
    AC -->|"checking biometrics"| Bio["BiometricCheckView"]
    AC -->|"need credential"| PV["PasscodeView / CustomNumberPadView"]
    AC -->|"authenticated"| Tabs["MainTabView"]

    Tabs --> Overlay["NotificationOverlayView"]
    Tabs --> UploadOverlay["UploadProgressOverlayView"]
    CV --> Privacy["EnhancedPrivacyOverlay"]

    AC --> KM["KeychainManager"]
    AC --> BAM["BiometricAuthManager"]
    AC --> LSM["LoginStateManager"]
    AC --> FSM["FileStorageManager.setupEncryptionKey"]
    SM["SecurityManager"] -->|"Notification.triggerSecurityLock"| AC
```

## 3. Tab UI components

Shared list/grid pieces: `VaultToolbarView`, `VaultItemCell`, `VaultGridView`, `UniversalAddContentView`, empty-state files, sort/folder pickers.

```mermaid
flowchart LR
    subgraph Folder["Folder tab"]
        FolderView --> FolderContentView
        FolderContentView --> FolderContentComponents
        FolderContentView --> FolderContentPresentation
        FolderContentView --> FolderRowViews
        FolderContentView --> FileRowViews
        FolderContentView --> FolderPickerView
    end

    subgraph Category["Category tab"]
        CategoryView --> CategoryCard
        CategoryView --> CategoryFilesView
        CategoryFilesView --> CategoryFilesComponents
    end

    subgraph Gallery["Gallery tab"]
        VaultMainView --> VaultGridView
        VaultMainView --> VaultItemCell
        VaultMainView --> GalleryFolderPickerView
    end

    subgraph Web["Web Upload tab"]
        WebUploadTabView --> WebUploadPresentationComponents
        WebUploadView --> WebUploadPresentationComponents
    end

    subgraph Settings["Settings tab"]
        SettingsView --> SettingsSections
        SettingsView --> TrashView
        SettingsView --> ChangeAuthenticationView
    end

    FolderContentView --> Media["UnifiedMediaViewerView"]
    CategoryFilesView --> Media
    VaultMainView --> Media
    FolderContentView --> Preview["FilePreviewView"]
    CategoryFilesView --> Preview
    VaultMainView --> Preview
```

### Media and document preview

```mermaid
flowchart TB
    UnifiedMediaViewerView --> ZoomablePhotoView
    UnifiedMediaViewerView --> AutoPlayVideoView
    AutoPlayVideoView --> VideoPlayerLifecycle
    AutoPlayVideoView --> ZoomableVideoPlayerSurface
    AutoPlayVideoView --> PlayerControlsView
    AutoPlayVideoView --> VideoPlaybackStateViews

    FilePreviewView --> DocumentPreviewView
    FilePreviewView --> AudioPreviewView
    FilePreviewView --> QuickLookPreview
    FilePreviewView --> UnsupportedFilePreviewView
    FilePreviewView --> FilePreviewLoadingView
    FilePreviewView --> FilePreviewErrorView
    FilePreviewView --> FilePreviewSharingService
    UnifiedMediaViewerView --> FileInfoPanel
    FilePreviewView --> FileInfoPanel
```

### Empty states

```mermaid
flowchart LR
    EmptyStateView --> EmptyStateConfiguration
    EmptyStateConfigurations --> EmptyStateConfiguration
    EmptyStateView --> EmptyStateActionButton
```

## 4. Storage and Core Data

`FileStorageManager` implements `FileStorageManaging` and delegates to focused services. Byte format, vault path, and thumbnail path stay here.

```mermaid
flowchart TB
    FSM["FileStorageManager"] --> MIME["MIMETypeMapper"]
    FSM --> Crypto["VaultCryptoService"]
    FSM --> KDF["VaultKeyDerivationStore"]
    FSM --> Store["EncryptedFileStore"]
    FSM --> Thumbs["ThumbnailGenerationService"]
    FSM --> Photos["PhotoImportService"]
    FSM --> Trash["TrashOperationsService"]
    FSM --> Share["TemporarySharingService"]
    FSM --> Meta["VaultMetadataSealer"]
    Store --> Crypto
    Thumbs --> Store
    KDF --> Keychain["Keychain vaultKeyDerivation"]
    FSM --> CDM["CoreDataManager"]

    CDM --> Items["CoreDataManager+VaultItems"]
    CDM --> Folders["CoreDataManager+Folders"]
    CDM --> BG["CoreDataManager+Background"]
    CDM --> Batch["CoreDataManager+BatchOperations"]
    CDM --> Model["FileVault.xcdatamodeld"]
```

```mermaid
erDiagram
    Folder ||--o{ Folder : parent
    Folder ||--o{ VaultItem : contains
    Folder {
        UUID id
        string name
        date createdAt
        date modifiedAt
    }
    VaultItem {
        UUID id
        string fileName
        string fileType
        bool isFavorite
        bool isDeleted
        date createdAt
        date deletedAt
    }
```

## 5. Security

```mermaid
flowchart TB
    SecurityManager --> Capture["SecurityCaptureMonitor"]
    SecurityManager --> Overlay["SecurityOverlayPresenter"]
    SecurityManager --> Motion["SecurityMotionDetector"]
    SecurityManager --> Logger["SecurityEventLogger"]
    Capture -->|"screenshot / recording / resign-active"| Overlay
    Motion -->|"shake / flip"| SecurityManager
    SecurityManager -->|"Notification.triggerSecurityLock"| AuthCoordinator
```

## 6. LAN web server

`WebServerManager` owns listener lifecycle, connections, and background tasks. Pure helpers live in infrastructure/HTML files.

```mermaid
flowchart TB
    UI["WebUploadTabView / WebUploadView"] --> WSM["WebServerManager"]
    WSM --> Access["WebAccessControl"]
    WSM --> Infra["WebServerInfrastructure"]
    WSM --> HTML["WebServerHTMLGenerator"]
    HTML --> Chunks["WebServerHTMLComponents"]
    WSM --> BUM["BackgroundUploadManager"]
    WSM --> FSM["FileStorageManager"]
    WSM --> CDM["CoreDataManager"]
    WSM --> Login["LoginStateManager"]
    Browser["LAN browser :8080"] --> WSM
```

## 7. Dependency injection

`DependencyContainer.shared` is injected on `ContentView`. Tests use `createForTesting(...)`. Many views still fall back to `.shared` on managers.

| Protocol | Production type |
|---|---|
| `CoreDataManaging` | `CoreDataManager` |
| `FileStorageManaging` | `FileStorageManager` |
| `VaultImportServicing` | `VaultImportService` |
| `KeychainManaging` | `KeychainManager` |
| `BiometricAuthManaging` | `BiometricAuthManager` |
| `LoginStateManaging` | `LoginStateManager` |
| `SecurityManaging` | `SecurityManager` |
| `WebServerManaging` | `WebServerManager` |
| `AppDataManaging` | `AppDataManager` |

View-model collaboration protocols (not DI): `SelectionManageable`, `ImportManageable`, `MediaViewerManageable`, `SearchManageable`, `AlertManageable`. `SheetManageable` and `ErrorManageable` exist in Models and are not adopted by current view models.

## 8. Cross-cutting notifications

Named in `Utilities/AppNotificationNames.swift`. Typical publishers: tab change, vault/file/folder mutations, web uploads, security lock.

```mermaid
flowchart LR
    Tabs["MainTabView"] -->|"tabDidChange"| VMs["Folder / Gallery / Category VMs"]
    Storage["FileStorage / Core Data"] -->|"file/folder changed"| VMs
    Web["WebServerManager"] -->|"upload progress / complete"| Overlays["UploadProgressOverlayView"]
    Security["SecurityManager"] -->|"triggerSecurityLock"| Auth["AuthenticationCoordinator"]
```
