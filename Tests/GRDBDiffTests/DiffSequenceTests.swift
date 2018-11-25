import XCTest
@testable import GRDBDiff

final class DiffSequenceTests: XCTestCase {
    func testDiffSequence() {
        var items: [String] = []
        for item in DiffSequence(
            left: [1, 2, 3],
            right: ["2", "3", "4"],
            leftKey: { "\($0)" },
            rightKey: { $0 })
        {
            switch item {
            case .left(let left):
                items.append("Left: \(left)")
            case .right(let right):
                items.append("Right: \(right)")
            case .common(let left, _):
                items.append("Common: \(left)")
            }
        }
        XCTAssertEqual(items, [
            "Left: 1",
            "Common: 2",
            "Common: 3",
            "Right: 4"])
    }

    static var allTests = [
        ("testDiffSequence", testDiffSequence),
    ]
}
