import XCTest
@testable import GRDBDiff

final class GRDBDiffTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(GRDBDiff().sqliteVersion, "3.24.0")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
