import SwiftUI
import InvoiceCore

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 20) {
                // Brand Header
                HStack(spacing: 12) {
                    InvoiceGenLogoMark(size: 34)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("InvoiceGen")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color.runeyPrimary)
                        Text("Workspace")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Color.runeyMuted)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                List {
                    Section {
                        ForEach(AppSection.allCases) { section in
                            HStack(spacing: 10) {
                                Image(systemName: section.systemImage)
                                    .font(.body)
                                    .foregroundStyle(model.selectedSection == section ? Color.runeySecondary : Color.runeyMuted)
                                    .frame(width: 22, height: 22)
                                
                                Text(section.title)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(model.selectedSection == section ? Color.runeySecondary : Color.runeyPrimary)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background {
                                if model.selectedSection == section {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.runeyPrimary)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                model.selectedSection = section
                            }
                            .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                            .listRowSeparator(.hidden)
                        }
                    } header: {
                        Text("Workspace")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.runeyMuted)
                            .padding(.leading, 8)
                    }
                }
                .listStyle(.sidebar)
            }
            .background(Color.runeySecondary.ignoresSafeArea())
            .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 280)
        } detail: {
            detail
                .background(Color.runeyBackground)
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
        .alert("InvoiceGen", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
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
            SettingsView()
        }
    }
}
