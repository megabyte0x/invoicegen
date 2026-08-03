import Foundation

public enum LocalInvoiceStoreError: Error, LocalizedError {
    case missingHomeDirectory

    public var errorDescription: String? {
        switch self {
        case .missingHomeDirectory:
            return "Could not determine a writable local home directory."
        }
    }
}

public final class LocalInvoiceStore {
    public let url: URL
    private let fileManager: FileManager
    private let legacyURL: URL?

    public init(
        url: URL? = nil,
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.fileManager = fileManager
        if let url {
            self.url = url
            self.legacyURL = nil
        } else {
            self.url = Self.defaultStoreURL(environment: environment)
            self.legacyURL = Self.legacyStoreURL(environment: environment)
        }
    }

    public static func defaultStoreURL(environment: [String: String]) -> URL {
        let overrideKey = "INVOICEGEN_APP_STORE"
        if let override = environment[overrideKey], !override.isEmpty {
            return URL(fileURLWithPath: NSString(string: override).expandingTildeInPath)
        }

        return defaultAppStoreURL(environment: environment)
    }

    private static func defaultAppStoreURL(environment: [String: String]) -> URL {
        #if os(macOS)
        if let home = environment["HOME"], !home.isEmpty {
            return URL(fileURLWithPath: NSString(string: home).expandingTildeInPath)
                .appendingPathComponent("Documents", isDirectory: true)
                .appendingPathComponent("InvoiceGen", isDirectory: true)
                .appendingPathComponent("store.json")
        }
        if let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            return documents
                .appendingPathComponent("InvoiceGen", isDirectory: true)
                .appendingPathComponent("store.json")
        }
        #endif

        return xdgStoreURL(directoryName: "invoicegen-app", environment: environment)
    }

    private static func legacyStoreURL(environment: [String: String]) -> URL? {
        if let override = environment["INVOICEGEN_APP_STORE"], !override.isEmpty {
            return nil
        }

        #if os(macOS)
        if let home = environment["HOME"], !home.isEmpty {
            return URL(fileURLWithPath: NSString(string: home).expandingTildeInPath)
                .appendingPathComponent("Library/Application Support/InvoiceGen", isDirectory: true)
                .appendingPathComponent("store.json")
        }
        if let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first {
            return appSupport
                .appendingPathComponent("InvoiceGen", isDirectory: true)
                .appendingPathComponent("store.json")
        }
        #endif

        return nil
    }

    private static func xdgStoreURL(directoryName: String, environment: [String: String]) -> URL {
        if let xdgDataHome = environment["XDG_DATA_HOME"], !xdgDataHome.isEmpty {
            return URL(fileURLWithPath: NSString(string: xdgDataHome).expandingTildeInPath)
                .appendingPathComponent(directoryName, isDirectory: true)
                .appendingPathComponent("store.json")
        }

        return URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".local/share/\(directoryName)", isDirectory: true)
            .appendingPathComponent("store.json")
    }

    public func load() throws -> InvoiceBook {
        try migrateLegacyStoreIfNeeded()
        guard fileManager.fileExists(atPath: url.path) else {
            return .empty
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var book = try decoder.decode(InvoiceBook.self, from: data)
        book.schemaVersion = InvoiceBook.currentSchemaVersion
        book.refreshInvoiceStatuses()
        return book
    }

    private func migrateLegacyStoreIfNeeded() throws {
        guard !fileManager.fileExists(atPath: url.path),
              let legacyURL,
              fileManager.fileExists(atPath: legacyURL.path) else { return }

        let data = try Data(contentsOf: legacyURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var book = try decoder.decode(InvoiceBook.self, from: data)
        book.schemaVersion = InvoiceBook.currentSchemaVersion
        book.refreshInvoiceStatuses()
        try save(book)
    }

    public func save(_ book: InvoiceBook) throws {
        try book.validateForSave()

        let directory = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(book)
        if fileManager.fileExists(atPath: url.path) {
            let backupURL = url.appendingPathExtension("bak")
            if fileManager.fileExists(atPath: backupURL.path) {
                try fileManager.removeItem(at: backupURL)
            }
            try fileManager.copyItem(at: url, to: backupURL)
        }
        try data.write(to: url, options: [.atomic])
    }

    public func exportStore(to destinationURL: URL) throws {
        _ = try load()
        if url.standardizedFileURL == destinationURL.standardizedFileURL {
            return
        }

        let directory = destinationURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        if fileManager.fileExists(atPath: url.path) {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.copyItem(at: url, to: destinationURL)
        } else {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(InvoiceBook.empty)
            try data.write(to: destinationURL, options: [.atomic])
        }
    }

    @discardableResult
    public func restoreStore(from sourceURL: URL) throws -> InvoiceBook {
        let data = try Data(contentsOf: sourceURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var restored = try decoder.decode(InvoiceBook.self, from: data)
        restored.schemaVersion = InvoiceBook.currentSchemaVersion
        restored.refreshInvoiceStatuses()
        try save(restored)
        return restored
    }

    public func update<T>(_ transform: (inout InvoiceBook) throws -> T) throws -> T {
        var book = try load()
        let result = try transform(&book)
        try save(book)
        return result
    }
}
