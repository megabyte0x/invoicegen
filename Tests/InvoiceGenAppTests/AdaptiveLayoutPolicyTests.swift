import XCTest
@testable import InvoiceGenApp

final class AdaptiveLayoutPolicyTests: XCTestCase {
    func test1223PointWorkspaceUsesOneScreenAtATime() {
        XCTAssertEqual(
            WorkspaceLayoutPolicy.masterDetail(width: 983, hasDetail: true),
            .detail
        )
        XCTAssertEqual(
            WorkspaceLayoutPolicy.invoiceEditor(width: 983, requested: .edit),
            .edit
        )
    }

    func testWideWorkspaceAllowsSideBySideEditorAndPreview() {
        XCTAssertEqual(
            WorkspaceLayoutPolicy.invoiceEditor(width: 1_200, requested: .edit),
            .sideBySide
        )
    }
}
