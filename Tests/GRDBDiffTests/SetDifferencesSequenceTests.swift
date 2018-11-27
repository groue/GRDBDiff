import XCTest
@testable import GRDBDiff

final class SetDifferencesSequenceTests: XCTestCase {
    func testDiffSequence() {
        func assertDiff(
            from old: [Int],
            to new: [String],
            isEqualTo expected: [String],
            file: StaticString = #file, line: UInt = #line)
        {
            var elements: [String] = []
            for element in SetDifferencesSequence(old: old, new: new, oldKey: { $0 }, newKey: { Int($0)! }) {
                switch element {
                case .deleted(let old):
                    elements.append("-\(old)")
                case .updated(let old, _):
                    elements.append("=\(old)")
                case .inserted(let new):
                    elements.append("+\(new)")
                }
            }
            XCTAssertEqual(elements, expected, file: file, line: line)
        }
        //
        assertDiff(
            from: [1, 2, 3],
            to: ["1", "2", "3"],
            isEqualTo: ["=1", "=2", "=3"])
        //
        assertDiff(
            from: [2, 3],
            to: ["1", "2", "3"],
            isEqualTo: ["+1", "=2", "=3"])
        assertDiff(
            from: [1, 2, 3],
            to: ["2", "3"],
            isEqualTo: ["-1", "=2", "=3"])
        //
        assertDiff(
            from: [1, 3],
            to: ["1", "2", "3"],
            isEqualTo: ["=1", "+2", "=3"])
        assertDiff(
            from: [1, 2, 3],
            to: ["1", "3"],
            isEqualTo: ["=1", "-2", "=3"])
        //
        assertDiff(
            from: [1, 2],
            to: ["1", "2", "3"],
            isEqualTo: ["=1", "=2", "+3"])
        assertDiff(
            from: [1, 2, 3],
            to: ["1", "2"],
            isEqualTo: ["=1", "=2", "-3"])
        //
        assertDiff(
            from: [1],
            to: ["1", "2", "3"],
            isEqualTo: ["=1", "+2", "+3"])
        assertDiff(
            from: [1, 2, 3],
            to: ["1"],
            isEqualTo: ["=1", "-2", "-3"])
        //
        assertDiff(
            from: [2],
            to: ["1", "2", "3"],
            isEqualTo: ["+1", "=2", "+3"])
        assertDiff(
            from: [1, 2, 3],
            to: ["2"],
            isEqualTo: ["-1", "=2", "-3"])
        //
        assertDiff(
            from: [3],
            to: ["1", "2", "3"],
            isEqualTo: ["+1", "+2", "=3"])
        assertDiff(
            from: [1, 2, 3],
            to: ["3"],
            isEqualTo: ["-1", "-2", "=3"])
        //
        assertDiff(
            from: [],
            to: ["1", "2", "3"],
            isEqualTo: ["+1", "+2", "+3"])
        assertDiff(
            from: [1, 2, 3],
            to: [],
            isEqualTo: ["-1", "-2", "-3"])
        //
        assertDiff(
            from: [1, 2, 3, 5, 7, 11, 13, 17, 23],
            to: ["1", "3", "5", "7", "9", "11", "13", "15", "17", "19", "21", "23"],
            isEqualTo: ["=1", "-2", "=3", "=5", "=7", "+9", "=11", "=13", "+15", "=17", "+19", "+21", "=23"])
        assertDiff(
            from: [1, 3, 5, 7, 9, 11, 13, 15, 17, 19, 21, 23],
            to: ["1", "2", "3", "5", "7", "11", "13", "17", "23"],
            isEqualTo: ["=1", "+2", "=3", "=5", "=7", "-9", "=11", "=13", "-15", "=17", "-19", "-21", "=23"])
    }
    
    static var allTests = [
        ("testDiffSequence", testDiffSequence),
        ]
}
