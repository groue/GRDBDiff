import XCTest

#if !os(macOS)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(IdentifiableSetDifferencesReducerTests.allTests),
        testCase(RecordSetDifferencesReducerTests.allTests),
        testCase(RecordSetDifferTests.allTests),
        testCase(RowValueTests.allTests),
        testCase(SetDifferencesSequenceTests.allTests),
    ]
}
#endif
