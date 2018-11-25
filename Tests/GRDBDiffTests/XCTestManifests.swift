import XCTest

#if !os(macOS)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(DiffSequenceTests.allTests),
        testCase(RowValueTests.allTests),
    ]
}
#endif
