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

    static func dismantleNSView(_ view: GuardView, coordinator: Coordinator) {
        view.coordinator = nil
        coordinator.uninstall()
    }

    final class Coordinator: NSObject, NSWindowDelegate {
        weak var model: AppModel?
        weak var window: NSWindow?
        var previousDelegate: NSWindowDelegate?

        init(model: AppModel) {
            self.model = model
        }

        func install(on window: NSWindow?) {
            guard let window else {
                uninstall()
                return
            }
            if self.window === window {
                if window.delegate !== self {
                    previousDelegate = window.delegate
                    window.delegate = self
                }
                return
            }

            uninstall()
            self.window = window
            previousDelegate = window.delegate
            window.delegate = self
        }

        func uninstall() {
            guard let window else {
                previousDelegate = nil
                return
            }
            if window.delegate === self {
                window.delegate = previousDelegate
            }
            self.window = nil
            previousDelegate = nil
        }

        func windowShouldClose(_ sender: NSWindow) -> Bool {
            guard model?.hasDirtyDraft == true else {
                return previousDelegate?.windowShouldClose?(sender) ?? true
            }

            model?.requestNavigation(to: .closeWindow)
            return false
        }

        override func responds(to selector: Selector!) -> Bool {
            super.responds(to: selector) || previousDelegate?.responds(to: selector) == true
        }

        override func forwardingTarget(for selector: Selector!) -> Any? {
            if previousDelegate?.responds(to: selector) == true {
                return previousDelegate
            }
            return super.forwardingTarget(for: selector)
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
