import AppKit
import SwiftUI
import InvoiceCore

@main
struct InvoiceGenApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("InvoiceGen", id: "main") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 1080, minHeight: 680)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Invoice") {
                    model.addInvoice()
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("Save") {
                    model.save()
                }
                .keyboardShortcut("s", modifiers: [.command])
            }
        }

        Settings {
            SettingsView()
                .environmentObject(model)
                .frame(width: 520)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
