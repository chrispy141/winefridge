//
//  BackupRestoreView.swift
//  WineStorage
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
    @State private var restoreSummaryMessage: String?

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
            // Older backups (including ones exported before the app's
            // `.winestoragebackup` extension existed, back when it was still
            // named WineFridge) don't carry a recognizable extension, so the
            // picker would otherwise refuse to let them be selected. Falling
            // back to `.data` allows picking any file; `restore(from:)`
            // still validates the contents and reports an error if it's not
            // actually a backup.
            allowedContentTypes: [.wineStorageBackup, .data]
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
        .alert(
            "Restore Complete",
            isPresented: Binding(
                get: { restoreSummaryMessage != nil },
                set: { if !$0 { restoreSummaryMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(restoreSummaryMessage ?? "")
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
            restoreSummaryMessage = "Restored \(pluralized(package.storages.count, singular: "storage", plural: "storages")) and \(pluralized(package.bottles.count, singular: "bottle", plural: "bottles"))."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Formats a count with its noun, using the singular form only when the
    /// count is exactly one (e.g. "1 bottle" vs "5 bottles").
    private func pluralized(_ count: Int, singular: String, plural: String) -> String {
        "\(count) \(count == 1 ? singular : plural)"
    }

    private func defaultBackupFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        // Spell out the extension explicitly rather than relying on
        // `fileExporter` to infer it from `contentType`, so the saved file
        // reliably carries the `.winestoragebackup` UTI extension declared
        // in Info.plist and can always be recognized again on restore.
        return "Wine Storage Backup \(formatter.string(from: .now)).winestoragebackup"
    }
}

#Preview {
    NavigationStack {
        BackupRestoreView()
    }
    .modelContainer(for: [Storage.self, Bottle.self, Shelf.self], inMemory: true)
}
