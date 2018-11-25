import XCTest

import GRDBDiffTests

var tests = [XCTestCaseEntry]()
tests += GRDBDiffTests.allTests()
XCTMain(tests)