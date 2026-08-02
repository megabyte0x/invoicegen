import AppKit
import SwiftUI

struct WindowCloseGuard: NSViewRepresentable {
    @ObservedObject var model: AppModel

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    func makeNSView(context: Context) -> GuardView {
        let view = GuardView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ view: GuardView, context: Context) {
        context.coordinator.model = model
        context.coordinator.install(on: view.window)
    }

    final class Coordinator: NSObject, NSWindowDelegate {
        weak var model: AppModel?
        weak var window: NSWindow?
        weak var previousDelegate: NSWindowDelegate?

        init(model: AppModel) {
            self.model = model
        }

        func install(on window: NSWindow?) {
            guard let window, self.window !== window else { return }

            self.window = window
            previousDelegate = window.delegate
            window.delegate = self
        }

        func windowShouldClose(_ sender: NSWindow) -> Bool {
            guard model?.hasDirtyDraft == true else {
                return previousDelegate?.windowShouldClose?(sender) ?? true
            }

            model?.requestNavigation(to: .closeWindow)
            return false
        }
    }

    final class GuardView: NSView {
        weak var coordinator: Coordinator?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            coordinator?.install(on: window)
        }
    }
}
