import XCTest

#if !os(macOS)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(IdentifiableCollectionSetDifferencesReducerTests.allTests),
        testCase(RowsSetDifferencesObservationTests.allTests),
        testCase(RowsSetDifferenciatorTests.allTests),
        testCase(RowValueTests.allTests),
        testCase(SetDifferencesSequenceTests.allTests),
    ]
}
#endif
