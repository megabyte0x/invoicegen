import SwiftUI
import InvoiceCore

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationSplitView {
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
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button {
                            model.addInvoice()
                        } label: {
                            Label("New Invoice", systemImage: "plus")
                        }
                        .help("New Invoice")

                        Button {
                            model.save()
                        } label: {
                            Label("Save", systemImage: "tray.and.arrow.down")
                        }
                        .help("Save")
                    }
                }
        }
        .alert("Local Invoice", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var sidebarSelection: Binding<AppSection?> {
        Binding(
            get: { model.selectedSection },
            set: { newValue in
                if let newValue {
                    model.selectedSection = newValue
                }
            }
        )
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
        }
    }
}
