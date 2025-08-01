//
//  SheetViewModel.swift
//  File Vault
//
//  Created on 10/07/25.
//

import Foundation
import SwiftUI
import Combine
import PhotosUI

/// Centralized sheet management ViewModel
final class SheetViewModel: ObservableObject, SheetManageable {
    // MARK: - Published Properties
    
    @Published var currentSheet: SheetConfiguration?
    @Published var isShowingSheet: Bool = false
    
    // MARK: - Private Properties
    
    private var sheetQueue: [SheetConfiguration] = []
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        setupBindings()
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Auto-process queued sheets when current sheet is dismissed
        $isShowingSheet
            .filter { !$0 }
            .sink { [weak self] _ in
                self?.processNextSheet()
            }
            .store(in: &cancellables)
    }
    
    private func processNextSheet() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            
            if !self.sheetQueue.isEmpty {
                let nextSheet = self.sheetQueue.removeFirst()
                self.presentSheet(nextSheet)
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Queue a sheet to be shown after current sheet is dismissed
    func queueSheet(_ configuration: SheetConfiguration) {
        if currentSheet != nil {
            sheetQueue.append(configuration)
        } else {
            presentSheet(configuration)
        }
    }
    
    /// Queue a sheet with type only
    func queueSheet(_ type: SheetType) {
        let configuration = SheetConfiguration(type: type)
        queueSheet(configuration)
    }
    
    /// Clear all queued sheets
    func clearQueue() {
        sheetQueue.removeAll()
    }
    
    /// Get the number of queued sheets
    var queueCount: Int {
        sheetQueue.count
    }
    
    /// Check if there are queued sheets
    var hasQueuedSheets: Bool {
        !sheetQueue.isEmpty
    }
}

/// Convenient view extension for sheet handling
extension View {
    func sheetHandler(_ sheetManager: SheetViewModel) -> some View {
        self
            .sheet(isPresented: Binding(
                get: { sheetManager.isShowingSheet },
                set: { newValue in 
                    if !newValue {
                        sheetManager.dismissSheet()
                    }
                }
            )) {
                if let currentSheet = sheetManager.currentSheet,
                   !currentSheet.presentationStyle.usesFullScreenCover {
                    EmptyView() // Placeholder - should be replaced with actual sheet content
                }
            }
    }
}

/// Convenient sheet builders for common sheet types
struct SheetBuilder {
    
    /// Build a photo picker sheet
    static func photoPicker(onSelection: @escaping ([PHPickerResult]) -> Void) -> some View {
        PhotoPickerView { results in
            onSelection(results)
        }
    }
    
    /// Build a document picker sheet
    static func documentPicker(onSelection: @escaping ([(Data, String)]) -> Void) -> some View {
        DocumentPickerView { documents in
            onSelection(documents)
        }
    }
    
    /// Build a sort action sheet
    static func sortActionSheet<T: Equatable>(
        currentSort: T,
        sortOptions: [T],
        optionTitles: [T: String],
        onSelection: @escaping (T) -> Void
    ) -> some View {
        VStack {
            Text("Sort Options")
                .font(.headline)
                .padding()
            
            ForEach(Array(sortOptions.enumerated()), id: \.offset) { _, option in
                Button(action: {
                    onSelection(option)
                }) {
                    HStack {
                        Text(optionTitles[option] ?? "Unknown")
                        Spacer()
                        if option == currentSort {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Spacer()
        }
        .presentationDetents([.medium])
    }
    
    /// Build an add action sheet
    static func addActionSheet(
        onPhotoPicker: @escaping () -> Void,
        onDocumentPicker: @escaping () -> Void,
        onWebUpload: (() -> Void)? = nil
    ) -> some View {
        VStack(spacing: 20) {
            Text("Add Files")
                .font(.headline)
                .padding()
            
            Button(action: onPhotoPicker) {
                Label("Import Photos", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
            }
            
            Button(action: onDocumentPicker) {
                Label("Import Documents", systemImage: "doc.badge.plus")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(10)
            }
            
            if let onWebUpload = onWebUpload {
                Button(action: onWebUpload) {
                    Label("Web Upload", systemImage: "globe")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(10)
                }
            }
            
            Spacer()
        }
        .padding()
        .presentationDetents([.medium])
    }
}