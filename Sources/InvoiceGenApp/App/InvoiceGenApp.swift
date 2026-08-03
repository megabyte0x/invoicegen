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
            SettingsView()
                .environmentObject(model)
                .onAppear {
                    activateSettingsDraft()
                }
        }
        .defaultSize(width: 680, height: 560)
    }

    private func activateSettingsDraft() {
        if model.settingsDraft == nil {
            model.beginEditingSettings()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
