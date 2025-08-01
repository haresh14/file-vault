//
//  SheetManageable.swift
//  File Vault
//
//  Created on 10/07/25.
//

import Foundation
import SwiftUI
import Combine

/// Represents different types of sheets that can be presented
enum SheetType: Identifiable, Equatable {
    case photoPicker
    case documentPicker
    case sortActionSheet
    case addActionSheet
    case moveSheet
    case webUpload
    case qrCode
    case instructions
    case changeAuth
    case fakePasswordSetup
    case folderPicker(selectedItems: [Any])
    case customSheet(identifier: String, content: AnyView)
    
    var id: String {
        switch self {
        case .photoPicker: return "photoPicker"
        case .documentPicker: return "documentPicker"
        case .sortActionSheet: return "sortActionSheet"
        case .addActionSheet: return "addActionSheet"
        case .moveSheet: return "moveSheet"
        case .webUpload: return "webUpload"
        case .qrCode: return "qrCode"
        case .instructions: return "instructions"
        case .changeAuth: return "changeAuth"
        case .fakePasswordSetup: return "fakePasswordSetup"
        case .folderPicker: return "folderPicker"
        case .customSheet(let identifier, _): return "custom_\(identifier)"
        }
    }
    
    static func ==(lhs: SheetType, rhs: SheetType) -> Bool {
        lhs.id == rhs.id
    }
}

/// Represents different presentation styles for sheets
enum SheetPresentationStyle {
    case sheet
    case fullScreenCover
    case actionSheet
    case halfModal
    
    var usesFullScreenCover: Bool {
        switch self {
        case .fullScreenCover:
            return true
        default:
            return false
        }
    }
}

/// Configuration for sheet presentation
struct SheetConfiguration {
    let type: SheetType
    let presentationStyle: SheetPresentationStyle
    let dismissible: Bool
    let onDismiss: (() -> Void)?
    
    init(
        type: SheetType,
        presentationStyle: SheetPresentationStyle = .sheet,
        dismissible: Bool = true,
        onDismiss: (() -> Void)? = nil
    ) {
        self.type = type
        self.presentationStyle = presentationStyle
        self.dismissible = dismissible
        self.onDismiss = onDismiss
    }
}

/// Protocol for managing sheet presentation in ViewModels
protocol SheetManageable: ObservableObject {
    /// Current sheet configuration to be presented
    var currentSheet: SheetConfiguration? { get set }
    
    /// Whether a sheet is currently being shown
    var isShowingSheet: Bool { get set }
    
    /// Present a sheet with the given configuration
    func presentSheet(_ configuration: SheetConfiguration)
    
    /// Present a sheet with a specific type using default settings
    func presentSheet(_ type: SheetType)
    
    /// Dismiss the current sheet
    func dismissSheet()
    
    /// Check if a specific sheet type is currently being shown
    func isSheetPresented(_ type: SheetType) -> Bool
}

/// Default implementation for SheetManageable
extension SheetManageable {
    func presentSheet(_ configuration: SheetConfiguration) {
        currentSheet = configuration
        isShowingSheet = true
    }
    
    func presentSheet(_ type: SheetType) {
        let configuration = SheetConfiguration(type: type)
        presentSheet(configuration)
    }
    
    func dismissSheet() {
        currentSheet?.onDismiss?()
        currentSheet = nil
        isShowingSheet = false
    }
    
    func isSheetPresented(_ type: SheetType) -> Bool {
        currentSheet?.type == type && isShowingSheet
    }
}

/// Convenience methods for common sheet presentations
extension SheetManageable {
    
    /// Present photo picker sheet
    func presentPhotoPicker() {
        presentSheet(.photoPicker)
    }
    
    /// Present document picker sheet
    func presentDocumentPicker() {
        presentSheet(.documentPicker)
    }
    
    /// Present sort action sheet
    func presentSortActionSheet() {
        presentSheet(SheetConfiguration(
            type: .sortActionSheet,
            presentationStyle: .actionSheet
        ))
    }
    
    /// Present add action sheet
    func presentAddActionSheet() {
        presentSheet(SheetConfiguration(
            type: .addActionSheet,
            presentationStyle: .actionSheet
        ))
    }
    
    /// Present move sheet with selected items
    func presentMoveSheet(with selectedItems: [Any] = []) {
        presentSheet(.folderPicker(selectedItems: selectedItems))
    }
    
    /// Present web upload sheet
    func presentWebUpload() {
        presentSheet(.webUpload)
    }
    
    /// Present QR code sheet
    func presentQRCode() {
        presentSheet(.qrCode)
    }
    
    /// Present instructions sheet
    func presentInstructions() {
        presentSheet(.instructions)
    }
    
    /// Present change authentication sheet
    func presentChangeAuth() {
        presentSheet(.changeAuth)
    }
    
    /// Present fake password setup sheet
    func presentFakePasswordSetup() {
        presentSheet(.fakePasswordSetup)
    }
    
    /// Present custom sheet with custom content
    func presentCustomSheet(identifier: String, content: AnyView, style: SheetPresentationStyle = .sheet) {
        presentSheet(SheetConfiguration(
            type: .customSheet(identifier: identifier, content: content),
            presentationStyle: style
        ))
    }
}

/// Sheet presentation bindings for SwiftUI integration
extension SheetManageable {
    
    /// Binding for photo picker presentation
    var photoPickerBinding: Binding<Bool> {
        Binding(
            get: { [weak self] in self?.isSheetPresented(.photoPicker) ?? false },
            set: { [weak self] newValue in
                if !newValue && self?.isSheetPresented(.photoPicker) == true {
                    self?.dismissSheet()
                }
            }
        )
    }
    
    /// Binding for document picker presentation
    var documentPickerBinding: Binding<Bool> {
        Binding(
            get: { [weak self] in self?.isSheetPresented(.documentPicker) ?? false },
            set: { [weak self] newValue in
                if !newValue && self?.isSheetPresented(.documentPicker) == true {
                    self?.dismissSheet()
                }
            }
        )
    }
    
    /// Binding for sort action sheet presentation
    var sortActionSheetBinding: Binding<Bool> {
        Binding(
            get: { [weak self] in self?.isSheetPresented(.sortActionSheet) ?? false },
            set: { [weak self] newValue in
                if !newValue && self?.isSheetPresented(.sortActionSheet) == true {
                    self?.dismissSheet()
                }
            }
        )
    }
    
    /// Binding for add action sheet presentation
    var addActionSheetBinding: Binding<Bool> {
        Binding(
            get: { [weak self] in self?.isSheetPresented(.addActionSheet) ?? false },
            set: { [weak self] newValue in
                if !newValue && self?.isSheetPresented(.addActionSheet) == true {
                    self?.dismissSheet()
                }
            }
        )
    }
    
    /// Binding for move sheet presentation
    var moveSheetBinding: Binding<Bool> {
        Binding(
            get: { [weak self] in 
                self?.isSheetPresented(.folderPicker(selectedItems: [])) ?? false ||
                self?.isSheetPresented(.moveSheet) ?? false
            },
            set: { [weak self] newValue in
                if !newValue && (self?.isSheetPresented(.folderPicker(selectedItems: [])) == true || 
                                self?.isSheetPresented(.moveSheet) == true) {
                    self?.dismissSheet()
                }
            }
        )
    }
    
    /// Binding for web upload sheet presentation
    var webUploadBinding: Binding<Bool> {
        Binding(
            get: { [weak self] in self?.isSheetPresented(.webUpload) ?? false },
            set: { [weak self] newValue in
                if !newValue && self?.isSheetPresented(.webUpload) == true {
                    self?.dismissSheet()
                }
            }
        )
    }
}