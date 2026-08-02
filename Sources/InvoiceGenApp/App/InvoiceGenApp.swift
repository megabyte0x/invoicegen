import AppKit
import SwiftUI
import InvoiceCore

@main
struct InvoiceGenApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("Local Invoice", id: "main") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 1040, minHeight: 640)
        }
        .defaultSize(width: 1280, height: 760)
        .commands {
            SidebarCommands()

            CommandGroup(after: .newItem) {
                Button("New Invoice") {
                    model.beginNewInvoice()
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("Save") {
                    commitActiveDraft()
                }
                .keyboardShortcut("s", modifiers: [.command])
                .disabled(!model.activeDraftIsDirty)

                Button("Cancel Changes") {
                    model.requestActiveDraftCancellation()
                }
                .keyboardShortcut(.cancelAction)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(model)
                .frame(width: 680)
                .onAppear {
                    activateSettingsDraft()
                }
        }
    }

    private func commitActiveDraft() {
        do {
            try model.commitActiveDraft()
            model.clearEditorIssues()
        } catch let error as EditorCommitError {
            model.presentEditorIssues(error.issues)
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }

    private func activateSettingsDraft() {
        if model.settingsDraft == nil {
            model.beginEditingSettings()
        } else {
            model.activeDraftRoute = .settings
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
