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

    public init(url: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.url = url ?? Self.defaultStoreURL(environment: ProcessInfo.processInfo.environment)
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
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            return appSupport
                .appendingPathComponent("InvoiceGen", isDirectory: true)
                .appendingPathComponent("store.json")
        }
        #endif

        return xdgStoreURL(directoryName: "invoicegen-app", environment: environment)
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

    public func restoreStore(from sourceURL: URL) throws {
        let data = try Data(contentsOf: sourceURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var book = try decoder.decode(InvoiceBook.self, from: data)
        book.schemaVersion = InvoiceBook.currentSchemaVersion
        try save(book)
    }

    public func update<T>(_ transform: (inout InvoiceBook) throws -> T) throws -> T {
        var book = try load()
        let result = try transform(&book)
        try save(book)
        return result
    }
}
