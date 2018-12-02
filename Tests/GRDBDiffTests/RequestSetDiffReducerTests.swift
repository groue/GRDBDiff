import XCTest
import GRDB
@testable import GRDBDiff

private struct Player: Codable, Equatable, FetchableRecord, PersistableRecord {
    var id: Int64
    var name: String
}

private final class PlayerClass: Equatable, FetchableRecord, PersistableRecord {
    var player: Player
    var updateCount: Int
    
    init(id: Int64, name: String, updateCount: Int = 0) {
        self.player = Player(id: id, name: name)
        self.updateCount = updateCount
    }

    static let databaseTableName = Player.databaseTableName
    
    init(row: Row) {
        self.player = Player(row: row)
        self.updateCount = 0
    }
    
    func encode(to container: inout PersistenceContainer) {
        player.encode(to: &container)
    }

    static func == (lhs: PlayerClass, rhs: PlayerClass) -> Bool {
        if lhs.player != rhs.player { return false }
        if lhs.updateCount != rhs.updateCount { return false }
        return true
    }
}

final class RequestSetDiffReducerTests: XCTestCase {
    func testSetDifferences() throws {
        let dbQueue = DatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
            }
            try Player(id: 1, name: "Arthur").insert(db)
        }
        
        var diffs: [SetDiff<Player>] = []
        let expectedDiffs: [SetDiff<Player>] = [
            SetDiff(
                inserted: [Player(id: 1, name: "Arthur")],
                updated: [],
                deleted: []),
            SetDiff(
                inserted: [],
                updated: [Player(id: 1, name: "Barbara")],
                deleted: []),
            SetDiff(
                inserted: [],
                updated: [],
                deleted: [Player(id: 1, name: "Barbara")]),
            SetDiff(
                inserted: [Player(id: 1, name: "Craig"),
                           Player(id: 2, name: "Danielle")],
                updated: [],
                deleted: []),
            SetDiff(
                inserted: [Player(id: 3, name: "Gerhard")],
                updated: [Player(id: 2, name: "Fiona")],
                deleted: [Player(id: 1, name: "Craig")]),
            SetDiff(
                inserted: [],
                updated: [Player(id: 2, name: "Harriett")],
                deleted: []),
        ]
        let expectation = self.expectation(description: "diffs")
        expectation.assertForOverFulfill = true
        expectation.expectedFulfillmentCount = expectedDiffs.count
        
        let request = Player.all().orderByPrimaryKey()
        let observation = ValueObservation
            .trackingAll(request)
            .setDifferencesFromRequest()
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
    
    func testUpdateElement() throws {
        let dbQueue = DatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
            }
            try PlayerClass(id: 1, name: "Arthur").insert(db)
        }
        
        var diffs: [SetDiff<PlayerClass>] = []
        let expectedDiffs: [SetDiff<PlayerClass>] = [
            SetDiff(
                inserted: [PlayerClass(id: 1, name: "Arthur", updateCount: 0)],
                updated: [],
                deleted: []),
            SetDiff(
                inserted: [],
                updated: [PlayerClass(id: 1, name: "Barbara", updateCount: 1)],
                deleted: []),
            SetDiff(
                inserted: [],
                updated: [],
                deleted: [PlayerClass(id: 1, name: "Barbara", updateCount: 1)]),
            SetDiff(
                inserted: [PlayerClass(id: 1, name: "Craig", updateCount: 0),
                           PlayerClass(id: 2, name: "Danielle", updateCount: 0)],
                updated: [],
                deleted: []),
            SetDiff(
                inserted: [PlayerClass(id: 3, name: "Gerhard", updateCount: 0)],
                updated: [PlayerClass(id: 2, name: "Fiona", updateCount: 1)],
                deleted: [PlayerClass(id: 1, name: "Craig", updateCount: 0)]),
            SetDiff(
                inserted: [],
                updated: [PlayerClass(id: 2, name: "Harriett", updateCount: 2)],
                deleted: []),
            ]
        let expectation = self.expectation(description: "diffs")
        expectation.assertForOverFulfill = true
        expectation.expectedFulfillmentCount = expectedDiffs.count
        
        let request = PlayerClass.all().orderByPrimaryKey()
        let observation = ValueObservation
            .trackingAll(request)
            .setDifferencesFromRequest(updateElement: { (oldPlayer, row) in
                // Don't update and return oldPlayer because our test does not
                // check each invidual diff as they are notified, but the list
                // of all notified diffs: we must make sure that no instance
                // is reused.
                let newPlayer = PlayerClass(row: row)
                newPlayer.updateCount = oldPlayer.updateCount + 1
                return newPlayer
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
        ("testSetDifferences", testSetDifferences),
        ("testUpdateElement", testUpdateElement),
        ]
}
