import XCTest

#if !os(macOS)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(RowValueTests.allTests),
        testCase(SetDifferencesObservationIdentifiableTests.allTests),
        testCase(SetDifferencesObservationRecordTests.allTests),
        testCase(SetDifferencesSequenceTests.allTests),
        testCase(_SetDifferencesReducerTests.allTests),
    ]
}
#endif
