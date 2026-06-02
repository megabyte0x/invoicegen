import Foundation

public enum InvoiceStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case draft
    case sent
    case paid
    case overdue
    case void

    public var id: String { rawValue }

    public var label: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }
}

public struct BusinessProfile: Codable, Equatable, Sendable {
    public var name: String
    public var email: String
    public var address: String
    public var taxIdentifier: String
    public var currencyCode: String
    public var paymentTermsDays: Int

    public init(
        name: String = "My Business",
        email: String = "",
        address: String = "",
        taxIdentifier: String = "",
        currencyCode: String = "USD",
        paymentTermsDays: Int = 14
    ) {
        self.name = name
        self.email = email
        self.address = address
        self.taxIdentifier = taxIdentifier
        self.currencyCode = currencyCode
        self.paymentTermsDays = paymentTermsDays
    }
}

public struct Client: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var company: String
    public var email: String
    public var address: String
    public var notes: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        company: String = "",
        email: String = "",
        address: String = "",
        notes: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.company = company
        self.email = email
        self.address = address
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct Project: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var clientId: UUID?
    public var name: String
    public var summary: String
    public var hourlyRateMinorUnits: Int64
    public var currencyCode: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        clientId: UUID? = nil,
        name: String,
        summary: String = "",
        hourlyRateMinorUnits: Int64 = 0,
        currencyCode: String = "USD",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.clientId = clientId
        self.name = name
        self.summary = summary
        self.hourlyRateMinorUnits = hourlyRateMinorUnits
        self.currencyCode = currencyCode
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct InvoiceLineItem: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var details: String
    public var quantity: Double
    public var unitPriceMinorUnits: Int64
    public var taxRatePercent: Double

    public init(
        id: UUID = UUID(),
        title: String,
        details: String = "",
        quantity: Double = 1,
        unitPriceMinorUnits: Int64,
        taxRatePercent: Double = 0
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.quantity = quantity
        self.unitPriceMinorUnits = unitPriceMinorUnits
        self.taxRatePercent = taxRatePercent
    }

    public var subtotalMinorUnits: Int64 {
        Int64((quantity * Double(unitPriceMinorUnits)).rounded())
    }

    public var taxMinorUnits: Int64 {
        Int64((Double(subtotalMinorUnits) * taxRatePercent / 100).rounded())
    }

    public var totalMinorUnits: Int64 {
        subtotalMinorUnits + taxMinorUnits
    }
}

public struct Payment: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var amountMinorUnits: Int64
    public var paidAt: Date
    public var reference: String
    public var notes: String

    public init(
        id: UUID = UUID(),
        amountMinorUnits: Int64,
        paidAt: Date = Date(),
        reference: String = "",
        notes: String = ""
    ) {
        self.id = id
        self.amountMinorUnits = amountMinorUnits
        self.paidAt = paidAt
        self.reference = reference
        self.notes = notes
    }
}

public struct Invoice: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var number: String
    public var clientId: UUID?
    public var projectId: UUID?
    public var issueDate: Date
    public var dueDate: Date
    public var status: InvoiceStatus
    public var currencyCode: String
    public var lineItems: [InvoiceLineItem]
    public var payments: [Payment]
    public var notes: String
    public var terms: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        number: String,
        clientId: UUID? = nil,
        projectId: UUID? = nil,
        issueDate: Date = Date(),
        dueDate: Date,
        status: InvoiceStatus = .draft,
        currencyCode: String = "USD",
        lineItems: [InvoiceLineItem] = [],
        payments: [Payment] = [],
        notes: String = "",
        terms: String = "Payment due on receipt.",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.number = number
        self.clientId = clientId
        self.projectId = projectId
        self.issueDate = issueDate
        self.dueDate = dueDate
        self.status = status
        self.currencyCode = currencyCode
        self.lineItems = lineItems
        self.payments = payments
        self.notes = notes
        self.terms = terms
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var subtotalMinorUnits: Int64 {
        lineItems.reduce(0) { $0 + $1.subtotalMinorUnits }
    }

    public var taxMinorUnits: Int64 {
        lineItems.reduce(0) { $0 + $1.taxMinorUnits }
    }

    public var totalMinorUnits: Int64 {
        subtotalMinorUnits + taxMinorUnits
    }

    public var paidMinorUnits: Int64 {
        payments.reduce(0) { $0 + $1.amountMinorUnits }
    }

    public var balanceDueMinorUnits: Int64 {
        max(0, totalMinorUnits - paidMinorUnits)
    }

    public mutating func refreshStatus(now: Date = Date()) {
        guard status != .void else { return }

        if totalMinorUnits > 0, paidMinorUnits >= totalMinorUnits {
            status = .paid
        } else if status == .sent, dueDate < now {
            status = .overdue
        }
        updatedAt = now
    }
}

public struct InvoiceBook: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var businessProfile: BusinessProfile
    public var clients: [Client]
    public var projects: [Project]
    public var invoices: [Invoice]

    public init(
        schemaVersion: Int = 1,
        businessProfile: BusinessProfile = BusinessProfile(),
        clients: [Client] = [],
        projects: [Project] = [],
        invoices: [Invoice] = []
    ) {
        self.schemaVersion = schemaVersion
        self.businessProfile = businessProfile
        self.clients = clients
        self.projects = projects
        self.invoices = invoices
    }

    public static var empty: InvoiceBook {
        InvoiceBook()
    }

    public mutating func refreshInvoiceStatuses(now: Date = Date()) {
        for index in invoices.indices {
            invoices[index].refreshStatus(now: now)
        }
    }

    public func client(for invoice: Invoice) -> Client? {
        guard let clientId = invoice.clientId else { return nil }
        return clients.first { $0.id == clientId }
    }

    public func project(for invoice: Invoice) -> Project? {
        guard let projectId = invoice.projectId else { return nil }
        return projects.first { $0.id == projectId }
    }

    public func nextInvoiceNumber(date: Date = Date()) -> String {
        let year = Calendar(identifier: .gregorian).component(.year, from: date)
        let prefix = "INV-\(year)-"
        let maxSequence = invoices
            .map(\.number)
            .filter { $0.hasPrefix(prefix) }
            .compactMap { Int($0.dropFirst(prefix.count)) }
            .max() ?? 0
        return "\(prefix)\(String(format: "%04d", maxSequence + 1))"
    }
}
