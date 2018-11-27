import XCTest
import GRDB
@testable import GRDBDiff

private struct Player: Codable, Equatable, FetchableRecord, PersistableRecord {
    var id: Int64
    var name: String
}

private final class PlayerClass: Equatable, FetchableRecord, PersistableRecord, CustomStringConvertible {
    var player: Player
    var reuseCount: Int
    
    var description: String {
        return String(describing: player) + " (reuseCount: \(reuseCount))"
    }
    
    init(id: Int64, name: String, reuseCount: Int = 0) {
        self.player = Player(id: id, name: name)
        self.reuseCount = reuseCount
    }

    static let databaseTableName = Player.databaseTableName
    
    init(row: Row) {
        self.player = Player(row: row)
        self.reuseCount = 0
    }
    
    func encode(to container: inout PersistenceContainer) {
        player.encode(to: &container)
    }
    
    func updated(from row: Row) -> PlayerClass {
        let updated = PlayerClass(row: row)
        updated.reuseCount = reuseCount + 1
        return updated
    }

    static func == (lhs: PlayerClass, rhs: PlayerClass) -> Bool {
        if lhs.player != rhs.player { return false }
        if lhs.reuseCount != rhs.reuseCount { return false }
        return true
    }
}

final class SetDifferencesObservationTests: XCTestCase {
    func testRequestSetDifferences() throws {
        let dbQueue = DatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
            }
            try Player(id: 1, name: "Arthur").insert(db)
        }
        
        var diffs: [SetDifferences<Player>] = []
        let expectedDiffs: [SetDifferences<Player>] = [
            SetDifferences(
                inserted: [Player(id: 1, name: "Arthur")],
                updated: [],
                deleted: []),
            SetDifferences(
                inserted: [],
                updated: [Player(id: 1, name: "Barbara")],
                deleted: []),
            SetDifferences(
                inserted: [],
                updated: [],
                deleted: [Player(id: 1, name: "Barbara")]),
            SetDifferences(
                inserted: [Player(id: 1, name: "Craig"),
                           Player(id: 2, name: "Danielle")],
                updated: [],
                deleted: []),
            SetDifferences(
                inserted: [Player(id: 3, name: "Gerhard")],
                updated: [Player(id: 2, name: "Fiona")],
                deleted: [Player(id: 1, name: "Craig")]),
            SetDifferences(
                inserted: [],
                updated: [Player(id: 2, name: "Harriett")],
                deleted: []),
        ]
        let expectation = self.expectation(description: "diffs")
        expectation.assertForOverFulfill = true
        expectation.expectedFulfillmentCount = expectedDiffs.count
        
        let request = Player.all().orderByPrimaryKey()
        let observation = ValueObservation.trackingSetDifferences(in: request)
        let observer = try observation.start(in: dbQueue) { diff in
            diffs.append(diff)
            expectation.fulfill()
        }
        try withExtendedLifetime(observer) {
            try dbQueue.write { db in
                try Player(id: 1, name: "Barbara").update(db)
            }
            try dbQueue.write { db in
                _ = try Player.deleteAll(db)
            }
            try dbQueue.write { db in
                try Player(id: 1, name: "Craig").insert(db)
                try Player(id: 2, name: "Danielle").insert(db)
            }
            try dbQueue.write { db in
                try Player.deleteOne(db, key: 1)
                try Player(id: 2, name: "Fiona").update(db)
                try Player(id: 3, name: "Gerhard").insert(db)
            }
            try dbQueue.write { db in
                try Player(id: 2, name: "Harriett").update(db)
            }

            waitForExpectations(timeout: 1, handler: nil)
        }
        XCTAssertEqual(diffs, expectedDiffs)
    }
    
    func testRequestUpdateElement() throws {
        let dbQueue = DatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
            }
            try PlayerClass(id: 1, name: "Arthur").insert(db)
        }
        
        var diffs: [SetDifferences<PlayerClass>] = []
        let expectedDiffs: [SetDifferences<PlayerClass>] = [
            SetDifferences(
                inserted: [PlayerClass(id: 1, name: "Arthur", reuseCount: 0)],
                updated: [],
                deleted: []),
            SetDifferences(
                inserted: [],
                updated: [PlayerClass(id: 1, name: "Barbara", reuseCount: 1)],
                deleted: []),
            SetDifferences(
                inserted: [],
                updated: [],
                deleted: [PlayerClass(id: 1, name: "Barbara", reuseCount: 1)]),
            SetDifferences(
                inserted: [PlayerClass(id: 1, name: "Craig", reuseCount: 0),
                           PlayerClass(id: 2, name: "Danielle", reuseCount: 0)],
                updated: [],
                deleted: []),
            SetDifferences(
                inserted: [PlayerClass(id: 3, name: "Gerhard", reuseCount: 0)],
                updated: [PlayerClass(id: 2, name: "Fiona", reuseCount: 1)],
                deleted: [PlayerClass(id: 1, name: "Craig", reuseCount: 0)]),
            SetDifferences(
                inserted: [],
                updated: [PlayerClass(id: 2, name: "Harriett", reuseCount: 2)],
                deleted: []),
            ]
        let expectation = self.expectation(description: "diffs")
        expectation.assertForOverFulfill = true
        expectation.expectedFulfillmentCount = expectedDiffs.count
        
        let request = PlayerClass.all().orderByPrimaryKey()
        let observation = ValueObservation.trackingSetDifferences(in: request, updateElement: { (player, row) in
            return player.updated(from: row)
        })
        let observer = try observation.start(in: dbQueue) { diff in
            diffs.append(diff)
            expectation.fulfill()
        }
        try withExtendedLifetime(observer) {
            try dbQueue.write { db in
                try PlayerClass(id: 1, name: "Barbara").update(db)
            }
            try dbQueue.write { db in
                _ = try PlayerClass.deleteAll(db)
            }
            try dbQueue.write { db in
                try PlayerClass(id: 1, name: "Craig").insert(db)
                try PlayerClass(id: 2, name: "Danielle").insert(db)
            }
            try dbQueue.write { db in
                try PlayerClass.deleteOne(db, key: 1)
                try PlayerClass(id: 2, name: "Fiona").update(db)
                try PlayerClass(id: 3, name: "Gerhard").insert(db)
            }
            try dbQueue.write { db in
                try PlayerClass(id: 2, name: "Harriett").update(db)
            }

            waitForExpectations(timeout: 1, handler: nil)
        }
        XCTAssertEqual(diffs, expectedDiffs)
    }
    
    static var allTests = [
        ("testRequestSetDifferences", testRequestSetDifferences),
        ("testRequestUpdateElement", testRequestUpdateElement),
        ]
}
