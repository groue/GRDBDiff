import XCTest

#if !os(macOS)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(RowValueTests.allTests),
        testCase(SetDifferencesObservationTests.allTests),
        testCase(SetDifferencesSequenceTests.allTests),
        testCase(_SetDifferencesReducerTests.allTests),
    ]
}
#endif
