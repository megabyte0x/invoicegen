import XCTest

final class InvoiceListLayoutArchitectureTests: XCTestCase {
    func testInvoicesViewDoesNotNestNavigationSplitViewInsideAppDetail() throws {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let packageRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = packageRoot.appendingPathComponent("Sources/InvoiceGenApp/Views/InvoicesView.swift")
        let source = try String(contentsOf: sourceURL)

        XCTAssertFalse(
            source.contains("NavigationSplitView {"),
            "InvoicesView must not nest NavigationSplitView inside the app detail because the inner sidebar can render under toolbar chrome."
        )
        XCTAssertTrue(
            source.contains("HSplitView"),
            "InvoicesView should use a plain split layout inside the outer app navigation."
        )
    }
}
