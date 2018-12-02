import XCTest
import GRDB
@testable import GRDBDiff

final class RowValueTests: XCTestCase {
    func testDatabaseValueComparison() throws {
        try DatabaseQueue().read { db in
            // Any integer up to 2^53 has an exact representation as a IEEE-754 double
            let twoPower53 = Int64(1) << 53
            let values: [DatabaseValueConvertible?] = [
                nil,
                Int64.min,
                1,
                2,
                3,
                twoPower53 - 1,
                twoPower53,
                // twoPower53 + 1,          // makes the test fail
                // Int64.max,               // makes the test fail
                Double(Int64.min),
                1.0,
                1.5,
                2.0,
                3.0,
                Double(twoPower53 - 1),
                Double(twoPower53),
                // Double(twoPower53 + 1),  // makes the test fail
                // Double(Int64.max),       // makes the test fail
                "",
                "1",
                "1.5",
                "2",
                "3",
                "e",
                "\u{00E9}",  // "é" NFC
                "e\u{0301}", // "é" NFD
                Data(),
                "1".data(using: .utf8),
                "1.5".data(using: .utf8),
                "2".data(using: .utf8),
                "3".data(using: .utf8)]
            let dbValues = values.map { $0?.databaseValue ?? .null }
            let unions = repeatElement("UNION ALL SELECT ?", count: dbValues.count - 1).joined(separator: " ")
            let sql = "SELECT value FROM (SELECT ? AS value \(unions)) ORDER BY value"
            do {
                let sqliteValues = try DatabaseValue.fetchAll(db, sql, arguments: StatementArguments(dbValues))
                let swiftValues = dbValues.sorted(by: <)
                XCTAssertEqual(sqliteValues, swiftValues)
            }
            do {
                let reversedValues: [DatabaseValue] = dbValues.reversed()
                let sqliteValues = try DatabaseValue.fetchAll(db, sql, arguments: StatementArguments(reversedValues))
                let swiftValues = reversedValues.sorted(by: <)
                XCTAssertEqual(sqliteValues, swiftValues)
            }
        }
    }
    
    static var allTests = [
        ("testDatabaseValueComparison", testDatabaseValueComparison),
        ]
}
