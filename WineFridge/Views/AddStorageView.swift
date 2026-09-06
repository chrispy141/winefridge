//
//  AddStorageView.swift
//  WineFridge
//

import SwiftUI

/// Lets the user name a new storage unit and choose which icon represents it.
struct AddStorageView: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (String, FridgeIcon) -> Void

    @State private var name = ""
    @State private var icon: FridgeIcon = .tall

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Storage Name", text: $name)
                }
                Section("Icon") {
                    HStack(spacing: 16) {
                        ForEach(FridgeIcon.allCases) { candidate in
                            FridgeIconOption(icon: candidate, isSelected: icon == candidate) {
                                icon = candidate
                            }
                        }
                        Spacer()
                    }
                }
            }
            .navigationTitle("New Storage")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(name, icon)
                        dismiss()
                    }
                }
            }
        }
    }
}

/// Shared by `AddStorageView` and `EditStorageView`.
struct FridgeIconOption: View {
    let icon: FridgeIcon
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 6) {
                Image(icon.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 2)
                    )
                Text(icon.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AddStorageView { _, _ in }
}
