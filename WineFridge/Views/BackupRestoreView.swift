//
//  BackupRestoreView.swift
//  WineFridge
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct BackupRestoreView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var exportDocument: BackupDocument?
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var pendingRestoreURL: URL?
    @State private var isConfirmingRestore = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Button {
                    prepareExport()
                } label: {
                    Label("Back Up…", systemImage: "square.and.arrow.up")
                }
            } footer: {
                Text("Saves all your storage, shelves, and bottles — including photos — into a single backup file. You choose where to save it and what to name it.")
            }

            Section {
                Button {
                    isImporting = true
                } label: {
                    Label("Restore from Backup…", systemImage: "square.and.arrow.down")
                }
            } footer: {
                Text("Restoring replaces everything currently in your inventory with the contents of the chosen backup file. This can't be undone.")
            }
        }
        .navigationTitle("Backup & Restore")
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .wineStorageBackup,
            defaultFilename: defaultBackupFilename()
        ) { result in
            if case .failure(let error) = result {
                errorMessage = error.localizedDescription
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.wineStorageBackup]
        ) { result in
            switch result {
            case .success(let url):
                pendingRestoreURL = url
                isConfirmingRestore = true
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
        .confirmationDialog(
            "Restore from Backup?",
            isPresented: $isConfirmingRestore,
            titleVisibility: .visible,
            presenting: pendingRestoreURL
        ) { url in
            Button("Restore", role: .destructive) {
                restore(from: url)
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("This replaces everything currently in your inventory with the contents of this backup. This can't be undone.")
        }
        .alert(
            "Backup Error",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func prepareExport() {
        do {
            let package = try BackupPackage(modelContext: modelContext)
            exportDocument = BackupDocument(data: try package.encoded())
            isExporting = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func restore(from url: URL) {
        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer { if didStartAccess { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            let package = try BackupPackage(data: data)
            try package.restore(into: modelContext)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func defaultBackupFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "Wine Storage Backup \(formatter.string(from: .now))"
    }
}

#Preview {
    NavigationStack {
        BackupRestoreView()
    }
    .modelContainer(for: [Storage.self, Bottle.self, Shelf.self], inMemory: true)
}
