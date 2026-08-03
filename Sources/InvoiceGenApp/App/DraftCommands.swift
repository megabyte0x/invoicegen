import SwiftUI

private struct DraftCommandTargetKey: FocusedValueKey {
    typealias Value = DraftKind
}

extension FocusedValues {
    var draftCommandTarget: DraftKind? {
        get { self[DraftCommandTargetKey.self] }
        set { self[DraftCommandTargetKey.self] = newValue }
    }
}

struct DraftCommands: Commands {
    @ObservedObject var model: AppModel
    @FocusedValue(\.draftCommandTarget) private var target

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Save") { saveFocusedDraft() }
                .keyboardShortcut("s", modifiers: [.command])
                .disabled(target.map(model.isDraftDirty) != true)

            Button("Cancel Changes") {
                if let target {
                    model.requestDraftCancellation(target)
                }
            }
            .keyboardShortcut(.cancelAction)
            .disabled(target == nil)
        }
    }

    private func saveFocusedDraft() {
        guard let target else { return }

        do {
            try model.commitDraft(target)
            model.clearEditorIssues()
        } catch let error as EditorCommitError {
            model.presentEditorIssues(error.issues)
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }
}

struct FocusedDraftCancellationAlert: ViewModifier {
    @ObservedObject var model: AppModel
    @FocusedValue(\.draftCommandTarget) private var focusedTarget

    func body(content: Content) -> some View {
        content.alert("Discard unsaved changes?", isPresented: isPresented) {
            Button("Discard Changes", role: .destructive) {
                guard let focusedTarget,
                      model.draftKindPendingCancellation == focusedTarget else { return }
                model.cancelDraft(focusedTarget)
                model.draftKindPendingCancellation = nil
            }
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("Your changes have not been saved.")
        }
    }

    private var isPresented: Binding<Bool> {
        Binding(
            get: {
                guard let focusedTarget else { return false }
                return model.draftKindPendingCancellation == focusedTarget
            },
            set: { presented in
                guard !presented,
                      let focusedTarget,
                      model.draftKindPendingCancellation == focusedTarget else { return }
                model.draftKindPendingCancellation = nil
            }
        )
    }
}
