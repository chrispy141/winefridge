//
//  AutocompleteTextField.swift
//  WineStorage
//

import SwiftUI

/// A text field that shows tap-to-fill suggestions from `suggestions` while
/// focused, filtered to whatever prefix has been typed so far.
///
/// The field name is shown as a persistent caption above the field, separate
/// from `placeholder`, so it stays visible once the person has typed a value
/// — a plain `TextField`'s label doubles as its placeholder and disappears
/// as soon as there's text.
struct AutocompleteTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let suggestions: [String]

    init(title: String, placeholder: String? = nil, text: Binding<String>, suggestions: [String]) {
        self.title = title
        self.placeholder = placeholder ?? title
        self._text = text
        self.suggestions = suggestions
    }

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
        // each button gets its own independent tap target. The title/field
        // pairing below is a `VStack`, but that's fine since it contains no
        // buttons of its own — it's still just one row.
        Group {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField(placeholder, text: $text)
                    .focused($isFocused)
            }
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
