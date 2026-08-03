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
        }
        .defaultSize(width: 1180, height: 760)
        .commands {
            SidebarCommands()

            CommandGroup(after: .newItem) {
                Button("New Invoice") {
                    model.beginNewInvoice()
                }
                .keyboardShortcut("n", modifiers: [.command])
            }

            DraftCommands(model: model)
        }

        Settings {
            SettingsSceneRoot(model: model)
        }
        .defaultSize(width: 680, height: 560)
    }
}

private struct SettingsSceneRoot: View {
    @ObservedObject var model: AppModel
    @State private var sceneID = UUID()

    var body: some View {
        SettingsView(sceneID: sceneID)
            .environmentObject(model)
            .focusedSceneValue(
                \.draftCommandTarget,
                DraftCommandTarget(sceneID: sceneID, kind: .settings)
            )
            .modifier(FocusedDraftCancellationAlert(model: model))
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
