import SwiftUI

struct EditorActionBar: View {
    var title: String
    var isDirty: Bool
    var save: () -> Void
    var cancel: () -> Void

    var body: some View {
        HStack {
            Text(isDirty ? "Unsaved changes" : "No changes")
                .foregroundStyle(.secondary)
            Spacer()
            Button("Cancel", action: cancel)
            Button("Save", action: save)
                .keyboardShortcut(.defaultAction)
                .disabled(!isDirty)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }
}
