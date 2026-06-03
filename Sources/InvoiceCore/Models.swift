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

public enum PaymentAcceptanceKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case bankDetails
    case cryptocurrency

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .bankDetails:
            return "Bank Details"
        case .cryptocurrency:
            return "Cryptocurrency"
        }
    }
}

public struct PaymentAcceptanceDetail: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var kind: PaymentAcceptanceKind
    public var label: String
    public var details: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        kind: PaymentAcceptanceKind,
        label: String,
        details: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.label = label
        self.details = details
        self.createdAt = createdAt
        self.updatedAt = updatedAt
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
    public var acceptedPaymentDetailIDs: [UUID]
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
        acceptedPaymentDetailIDs: [UUID] = [],
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
        self.acceptedPaymentDetailIDs = acceptedPaymentDetailIDs
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
        } else if status == .sent || status == .overdue || status == .paid {
            status = dueDate < now ? .overdue : .sent
        }
        updatedAt = now
    }

    public mutating func markUnpaid(now: Date = Date()) {
        guard status != .void else { return }

        payments.removeAll()
        status = dueDate < now ? .overdue : .sent
        updatedAt = now
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case number
        case clientId
        case projectId
        case issueDate
        case dueDate
        case status
        case currencyCode
        case lineItems
        case payments
        case notes
        case terms
        case acceptedPaymentDetailIDs
        case createdAt
        case updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        number = try container.decode(String.self, forKey: .number)
        clientId = try container.decodeIfPresent(UUID.self, forKey: .clientId)
        projectId = try container.decodeIfPresent(UUID.self, forKey: .projectId)
        issueDate = try container.decode(Date.self, forKey: .issueDate)
        dueDate = try container.decode(Date.self, forKey: .dueDate)
        status = try container.decodeIfPresent(InvoiceStatus.self, forKey: .status) ?? .draft
        currencyCode = try container.decodeIfPresent(String.self, forKey: .currencyCode) ?? "USD"
        lineItems = try container.decodeIfPresent([InvoiceLineItem].self, forKey: .lineItems) ?? []
        payments = try container.decodeIfPresent([Payment].self, forKey: .payments) ?? []
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        terms = try container.decodeIfPresent(String.self, forKey: .terms) ?? "Payment due on receipt."
        acceptedPaymentDetailIDs = try container.decodeIfPresent([UUID].self, forKey: .acceptedPaymentDetailIDs) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? issueDate
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }
}

public struct InvoiceBook: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 2

    public var schemaVersion: Int
    public var businessProfile: BusinessProfile
    public var clients: [Client]
    public var projects: [Project]
    public var paymentAcceptanceDetails: [PaymentAcceptanceDetail]
    public var invoices: [Invoice]

    public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        businessProfile: BusinessProfile = BusinessProfile(),
        clients: [Client] = [],
        projects: [Project] = [],
        paymentAcceptanceDetails: [PaymentAcceptanceDetail] = [],
        invoices: [Invoice] = []
    ) {
        self.schemaVersion = schemaVersion
        self.businessProfile = businessProfile
        self.clients = clients
        self.projects = projects
        self.paymentAcceptanceDetails = paymentAcceptanceDetails
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

    public func paymentAcceptanceDetails(for invoice: Invoice) -> [PaymentAcceptanceDetail] {
        let detailsByID = Dictionary(uniqueKeysWithValues: paymentAcceptanceDetails.map { ($0.id, $0) })
        return invoice.acceptedPaymentDetailIDs.compactMap { detailsByID[$0] }
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

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case businessProfile
        case clients
        case projects
        case paymentAcceptanceDetails
        case invoices
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? Self.currentSchemaVersion
        businessProfile = try container.decodeIfPresent(BusinessProfile.self, forKey: .businessProfile) ?? BusinessProfile()
        clients = try container.decodeIfPresent([Client].self, forKey: .clients) ?? []
        projects = try container.decodeIfPresent([Project].self, forKey: .projects) ?? []
        paymentAcceptanceDetails = try container.decodeIfPresent([PaymentAcceptanceDetail].self, forKey: .paymentAcceptanceDetails) ?? []
        invoices = try container.decodeIfPresent([Invoice].self, forKey: .invoices) ?? []
    }
}

public struct InvoiceBookValidationError: LocalizedError, Equatable, Sendable {
    public var issues: [String]

    public init(issues: [String]) {
        self.issues = issues
    }

    public var errorDescription: String? {
        "Invoice validation failed: " + issues.joined(separator: "; ")
    }
}

public extension InvoiceBook {
    func validateForSave() throws {
        let issues = validationIssues()
        if !issues.isEmpty {
            throw InvoiceBookValidationError(issues: issues)
        }
    }

    func validationIssues() -> [String] {
        var issues: [String] = []

        if !isValidCurrencyCode(businessProfile.currencyCode) {
            issues.append("Business profile currency must be a three-letter uppercase code")
        }
        if !(0...120).contains(businessProfile.paymentTermsDays) {
            issues.append("Payment terms must be between 0 and 120 days")
        }

        var seenInvoiceNumbers: [String: UUID] = [:]
        for invoice in invoices {
            let trimmedNumber = invoice.number.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedNumber.isEmpty {
                issues.append("Invoice number is required")
            } else {
                let normalizedNumber = trimmedNumber.lowercased()
                if seenInvoiceNumbers[normalizedNumber] != nil {
                    issues.append("Invoice number must be unique: \(trimmedNumber)")
                } else {
                    seenInvoiceNumbers[normalizedNumber] = invoice.id
                }
            }

            if invoice.dueDate < invoice.issueDate {
                issues.append("Due date cannot be before issue date for invoice \(displayNumber(for: invoice))")
            }

            if !isValidCurrencyCode(invoice.currencyCode) {
                issues.append("Invoice currency must be a three-letter uppercase code for invoice \(displayNumber(for: invoice))")
            }

            if invoice.paidMinorUnits > invoice.totalMinorUnits {
                issues.append("Payments cannot exceed invoice total for invoice \(displayNumber(for: invoice))")
            }

            for payment in invoice.payments where payment.amountMinorUnits <= 0 {
                issues.append("Payment amount must be greater than zero for invoice \(displayNumber(for: invoice))")
            }

            for item in invoice.lineItems {
                let itemLabel = item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "line item" : item.title
                if item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    issues.append("Line item title is required for invoice \(displayNumber(for: invoice))")
                }
                if item.quantity <= 0 || !item.quantity.isFinite {
                    issues.append("Line item quantity must be greater than zero for \(itemLabel)")
                }
                if item.unitPriceMinorUnits < 0 {
                    issues.append("Line item unit price cannot be negative for \(itemLabel)")
                }
                if item.taxRatePercent < 0 || item.taxRatePercent > 100 || !item.taxRatePercent.isFinite {
                    issues.append("Line item tax rate must be between 0 and 100 for \(itemLabel)")
                }
            }
        }

        return issues
    }

    private func displayNumber(for invoice: Invoice) -> String {
        let trimmed = invoice.number.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? invoice.id.uuidString : trimmed
    }

    private func isValidCurrencyCode(_ value: String) -> Bool {
        let scalars = value.unicodeScalars
        return scalars.count == 3 && scalars.allSatisfy { scalar in
            scalar.value >= UnicodeScalar("A").value && scalar.value <= UnicodeScalar("Z").value
        }
    }
}
