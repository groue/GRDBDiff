import XCTest

#if !os(macOS)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(RequestSetDiffReducerTests.allTests),
        testCase(RowValueTests.allTests),
        testCase(SetDiffReducerTests.allTests),
        testCase(SetDiffSequenceTests.allTests),
        testCase(SetDifferTests.allTests),
    ]
}
#endif
