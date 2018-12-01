import XCTest

#if !os(macOS)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(IdentifiableSetDifferencesReducerTests.allTests),
        testCase(RecordSetDifferencesReducerTests.allTests),
        testCase(RecordSetDifferenciatorTests.allTests),
        testCase(RowValueTests.allTests),
        testCase(SetDifferencesSequenceTests.allTests),
    ]
}
#endif
