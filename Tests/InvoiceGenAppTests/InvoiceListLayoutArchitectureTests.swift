import XCTest
@testable import InvoiceGenApp

final class InvoiceListLayoutArchitectureTests: XCTestCase {
    func testSectionViewsDoNotNestNavigationSplitViewInsideAppDetail() throws {
        for fileName in ["InvoicesView.swift", "ClientsView.swift", "ProjectsView.swift"] {
            let source = try viewSource(named: fileName)

            XCTAssertFalse(
                source.contains("NavigationSplitView"),
                "\(fileName) must not nest NavigationSplitView inside the app detail."
            )
        }
    }

    func testContentViewOwnsTheNavigationSplitView() throws {
        let source = try viewSource(named: "ContentView.swift")

        XCTAssertTrue(
            source.contains("NavigationSplitView"),
            "ContentView must own the app-level NavigationSplitView."
        )
    }

    func testAppSectionIncludesSettings() {
        XCTAssertTrue(AppSection.allCases.contains(.settings))
    }

    private func viewSource(named fileName: String) throws -> String {
        let sourceURL = packageRoot
            .appendingPathComponent("Sources/InvoiceGenApp/Views")
            .appendingPathComponent(fileName)
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }

    private var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
