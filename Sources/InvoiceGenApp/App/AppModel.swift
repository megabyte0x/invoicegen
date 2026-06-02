import Foundation
import SwiftUI
import InvoiceCore

enum AppSection: String, CaseIterable, Identifiable {
    case dashboard
    case invoices
    case clients
    case projects

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .invoices: return "Invoices"
        case .clients: return "Clients"
        case .projects: return "Projects"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: return "chart.bar.doc.horizontal"
        case .invoices: return "doc.text"
        case .clients: return "person.2"
        case .projects: return "folder"
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var book: InvoiceBook
    @Published var selectedSection: AppSection = .dashboard
    @Published var selectedInvoiceID: UUID?
    @Published var selectedClientID: UUID?
    @Published var selectedProjectID: UUID?
    @Published var searchText = ""
    @Published var errorMessage: String?

    let store: LocalInvoiceStore

    init(store: LocalInvoiceStore = LocalInvoiceStore()) {
        self.store = store
        do {
            self.book = try store.load()
        } catch {
            self.book = .empty
            self.errorMessage = error.localizedDescription
        }
    }

    func reload() {
        do {
            book = try store.load()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save() {
        do {
            book.refreshInvoiceStatuses()
            try store.save(book)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func seedSampleData() {
        book = .sample()
        selectedSection = .dashboard
        selectedInvoiceID = book.invoices.first?.id
        save()
    }

    func addInvoice() {
        let now = Date()
        let clientId = book.clients.first?.id
        let dueDays = book.businessProfile.paymentTermsDays
        let invoice = Invoice(
            number: book.nextInvoiceNumber(date: now),
            clientId: clientId,
            issueDate: now,
            dueDate: Calendar.current.date(byAdding: .day, value: dueDays, to: now) ?? now,
            currencyCode: book.businessProfile.currencyCode,
            lineItems: [
                InvoiceLineItem(title: "Professional services", quantity: 1, unitPriceMinorUnits: 0)
            ],
            terms: "Net \(dueDays)."
        )
        book.invoices.insert(invoice, at: 0)
        selectedSection = .invoices
        selectedInvoiceID = invoice.id
        save()
    }

    func deleteSelectedInvoice() {
        guard let id = selectedInvoiceID else { return }
        book.invoices.removeAll { $0.id == id }
        selectedInvoiceID = book.invoices.first?.id
        save()
    }

    func addClient() {
        let client = Client(name: "New Client")
        book.clients.insert(client, at: 0)
        selectedSection = .clients
        selectedClientID = client.id
        save()
    }

    func deleteSelectedClient() {
        guard let id = selectedClientID else { return }
        book.clients.removeAll { $0.id == id }
        for index in book.invoices.indices where book.invoices[index].clientId == id {
            book.invoices[index].clientId = nil
        }
        selectedClientID = book.clients.first?.id
        save()
    }

    func addProject() {
        let project = Project(
            clientId: book.clients.first?.id,
            name: "New Project",
            currencyCode: book.businessProfile.currencyCode
        )
        book.projects.insert(project, at: 0)
        selectedSection = .projects
        selectedProjectID = project.id
        save()
    }

    func deleteSelectedProject() {
        guard let id = selectedProjectID else { return }
        book.projects.removeAll { $0.id == id }
        for index in book.invoices.indices where book.invoices[index].projectId == id {
            book.invoices[index].projectId = nil
        }
        selectedProjectID = book.projects.first?.id
        save()
    }

    func invoiceBinding(id: UUID) -> Binding<Invoice>? {
        guard let index = book.invoices.firstIndex(where: { $0.id == id }) else {
            return nil
        }
        return Binding(
            get: { self.book.invoices[index] },
            set: { newValue in
                self.book.invoices[index] = newValue
                self.book.invoices[index].updatedAt = Date()
                self.save()
            }
        )
    }

    func clientBinding(id: UUID) -> Binding<Client>? {
        guard let index = book.clients.firstIndex(where: { $0.id == id }) else {
            return nil
        }
        return Binding(
            get: { self.book.clients[index] },
            set: { newValue in
                self.book.clients[index] = newValue
                self.book.clients[index].updatedAt = Date()
                self.save()
            }
        )
    }

    func projectBinding(id: UUID) -> Binding<Project>? {
        guard let index = book.projects.firstIndex(where: { $0.id == id }) else {
            return nil
        }
        return Binding(
            get: { self.book.projects[index] },
            set: { newValue in
                self.book.projects[index] = newValue
                self.book.projects[index].updatedAt = Date()
                self.save()
            }
        )
    }
}
