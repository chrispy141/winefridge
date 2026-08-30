//
//  AutocompleteTextField.swift
//  WineFridge
//

import SwiftUI

/// A text field that shows tap-to-fill suggestions from `suggestions` while
/// focused, filtered to whatever prefix has been typed so far.
struct AutocompleteTextField: View {
    let label: String
    @Binding var text: String
    let suggestions: [String]

    @FocusState private var isFocused: Bool

    private var matches: [String] {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return [] }
        return Array(
            suggestions
                .filter { $0.lowercased().hasPrefix(query) && $0.lowercased() != query }
                .prefix(5)
        )
    }

    var body: some View {
        // Important: this must be a `Group` (a transparent multi-view marker),
        // not a `VStack`/`HStack`. Inside a Form/List `Section`, a `VStack`
        // collapses the TextField and all suggestion `Button`s into a single
        // row, and a row with multiple `Button`s only forwards taps to the
        // last button regardless of where within the row you tap. Using
        // `Group` makes the TextField and each suggestion its own row, so
        // each button gets its own independent tap target.
        Group {
            TextField(label, text: $text)
                .focused($isFocused)
            if isFocused {
                ForEach(matches, id: \.self) { suggestion in
                    Button {
                        text = suggestion
                        isFocused = false
                    } label: {
                        Text(suggestion)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
