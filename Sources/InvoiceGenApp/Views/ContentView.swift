import Foundation
import SwiftUI
import InvoiceCore

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var sceneID = UUID()

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: sidebarSelection) {
                Section("Workspace") {
                    ForEach(AppSection.allCases) { section in
                        Label {
                            Text(section.title)
                        } icon: {
                            Image(systemName: section.systemImage)
                                .foregroundStyle(.secondary)
                        }
                        .tag(section)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 280)
            .navigationTitle("Local Invoice")
        } detail: {
            detail
                .searchable(text: $model.searchText, placement: .toolbar)
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        if columnVisibility == .detailOnly {
                            Button("Workspace") {
                                columnVisibility = .all
                            }
                            .help("Show Workspace")
                        }
                    }

                    ToolbarItemGroup(placement: .primaryAction) {
                        Button {
                            model.beginNewInvoice()
                        } label: {
                            Label("New Invoice", systemImage: "plus")
                        }
                        .help("New Invoice")
                    }
                }
        }
        .background(WindowCloseGuard(model: model))
        .focusedSceneValue(\.draftCommandTarget, commandTarget)
        .modifier(FocusedDraftCancellationAlert(model: model))
        .alert("Local Invoice", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .alert(navigationConfirmationTitle, isPresented: pendingNavigationPresented) {
            Button(isClosingWindow ? "Save and Close" : "Save and Continue") {
                saveAndContinueNavigation()
            }
            Button(isClosingWindow ? "Discard and Close" : "Discard Changes", role: .destructive) {
                model.discardDirtyDraftsAndContinue()
            }
            Button(isClosingWindow ? "Keep Editing" : "Stay Here", role: .cancel) {
                model.cancelPendingNavigation()
            }
        } message: {
            Text("Your changes have not been saved.")
        }
    }

    private var sidebarSelection: Binding<AppSection?> {
        Binding(
            get: { model.selectedSection },
            set: { section in
                guard let section else { return }
                model.requestNavigation(to: .section(section))
            }
        )
    }

    private var commandTarget: DraftCommandTarget? {
        let kind: DraftKind?

        switch model.selectedSection {
        case .invoices where model.invoiceDraft != nil:
            kind = .invoice
        case .clients where model.clientDraft != nil:
            kind = .client
        case .projects where model.projectDraft != nil:
            kind = .project
        case .settings where model.settingsDraft != nil:
            kind = .settings
        default:
            kind = nil
        }

        return kind.map { DraftCommandTarget(sceneID: sceneID, kind: $0) }
    }

    @ViewBuilder
    private var detail: some View {
        switch model.selectedSection {
        case .dashboard:
            DashboardView()
        case .invoices:
            InvoicesView()
        case .clients:
            ClientsView()
        case .projects:
            ProjectsView()
        case .settings:
            SettingsView(sceneID: sceneID)
                .onAppear {
                    activateSettingsDraft()
                }
        }
    }

    private var pendingNavigationPresented: Binding<Bool> {
        Binding(
            get: { model.pendingNavigation != nil },
            set: { isPresented in
                if !isPresented {
                    model.cancelPendingNavigation()
                }
            }
        )
    }

    private var isClosingWindow: Bool {
        guard let pendingNavigation = model.pendingNavigation else { return false }
        if case .closeWindow = pendingNavigation {
            return true
        }
        return false
    }

    private var navigationConfirmationTitle: String {
        isClosingWindow ? "Save changes before closing?" : "Save changes before leaving?"
    }

    private func saveAndContinueNavigation() {
        let intent = model.pendingNavigation
        guard let draftKind = model.dirtyDraftRequiringDecision else {
            model.cancelPendingNavigation()
            return
        }

        do {
            try model.commitDraft(draftKind)
            model.clearEditorIssues()
            model.cancelPendingNavigation()
            if let intent {
                model.requestNavigation(to: intent)
            }
        } catch let error as EditorCommitError {
            model.presentEditorIssues(error.issues)
            model.cancelPendingNavigation()
        } catch {
            model.errorMessage = error.localizedDescription
            model.cancelPendingNavigation()
        }
    }

    private func activateSettingsDraft() {
        if model.settingsDraft == nil {
            model.beginEditingSettings()
        }
    }
}
