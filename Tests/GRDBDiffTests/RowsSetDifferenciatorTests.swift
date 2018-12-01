import XCTest
import GRDB
@testable import GRDBDiff

class RowsSetDifferenciatorTests: XCTestCase {
    func testReducer() {
        var reducer = RowsSetDifferenciator<String>(
            key: { (row: Row) in RowValue(dbValues: [row["id"]]) },
            initialElements: [],
            makeElement: { (row: Row) in row["name"] as String },
            updateElement: { (element: String, row: Row) in row["name"] })
        
        do {
            let diff: SetDifferences<String> = reducer.diff([])
            XCTAssertTrue(diff.isEmpty)
        }
        
        do {
            let diff = reducer.diff([
                ["id": 1, "name": "Arthur"]
                ])
            XCTAssertEqual(diff.inserted.count, 1)
            XCTAssertEqual(diff.inserted[0], "Arthur")
            XCTAssertTrue(diff.updated.isEmpty)
            XCTAssertTrue(diff.deleted.isEmpty)
        }
        
        do {
            let diff = reducer.diff([
                ["id": 1, "name": "Barbara"]
                ])
            XCTAssertTrue(diff.inserted.isEmpty)
            XCTAssertEqual(diff.updated.count, 1)
            XCTAssertEqual(diff.updated[0], "Barbara")
            XCTAssertTrue(diff.deleted.isEmpty)
        }
        
        do {
            let diff = reducer.diff([
                ["id": 2, "name": "Craig"]
                ])
            XCTAssertEqual(diff.inserted.count, 1)
            XCTAssertEqual(diff.inserted[0], "Craig")
            XCTAssertTrue(diff.updated.isEmpty)
            XCTAssertEqual(diff.deleted.count, 1)
            XCTAssertEqual(diff.deleted[0], "Barbara")
        }
        
        do {
            let diff = reducer.diff([
                ["id": 1, "name": "David"],
                ["id": 2, "name": "Eugenia"],
                ["id": 3, "name": "Fiona"],
                ["id": 4, "name": "Gerhard"],
                ])
            XCTAssertEqual(diff.inserted.count, 3)
            XCTAssertEqual(Set(diff.inserted), ["David", "Fiona", "Gerhard"])
            XCTAssertEqual(diff.updated.count, 1)
            XCTAssertEqual(diff.updated[0], "Eugenia")
            XCTAssertTrue(diff.deleted.isEmpty)
        }
        
        do {
            let diff = reducer.diff([
                ["id": 1, "name": "Henri"],
                ["id": 3, "name": "Irene"],
                ["id": 5, "name": "Jules"],
                ["id": 6, "name": "Karl"],
                ])
            XCTAssertEqual(diff.inserted.count, 2)
            XCTAssertEqual(Set(diff.inserted), ["Jules", "Karl"])
            XCTAssertEqual(diff.updated.count, 2)
            XCTAssertEqual(Set(diff.updated), ["Henri", "Irene"])
            XCTAssertEqual(diff.deleted.count, 2)
            XCTAssertEqual(Set(diff.deleted), ["Eugenia", "Gerhard"])
        }
        
        do {
            let diff = reducer.diff([
                ["id": 1, "name": "Henri"],
                ["id": 3, "name": "Irene"],
                ["id": 5, "name": "Jules"],
                ["id": 6, "name": "Karl"],
                ])
            XCTAssertTrue(diff.isEmpty)
        }
    }
    
    func testUpdateElement() {
        class Element {
            var name: String
            var reuseCount = 0
            
            init(name: String, reuseCount: Int) {
                self.name = name
                self.reuseCount = reuseCount
            }
        }
        
        var reducer = RowsSetDifferenciator<Element>(
            key: { (row: Row) in RowValue(dbValues: [row["id"]]) },
            initialElements: [],
            makeElement: { (row: Row) in Element(name: row["name"], reuseCount: 0) },
            updateElement: { (element: Element, row: Row) in Element(name: row["name"], reuseCount: element.reuseCount + 1) })
        
        do {
            let diff = reducer.diff([["id": 1, "name": "Arthur"]])
            XCTAssertEqual(diff.inserted.count, 1)
            XCTAssertEqual(diff.inserted[0].name, "Arthur")
            XCTAssertEqual(diff.inserted[0].reuseCount, 0)
            XCTAssertTrue(diff.updated.isEmpty)
            XCTAssertTrue(diff.deleted.isEmpty)
        }
        
        do {
            let diff = reducer.diff([["id": 1, "name": "Barbara"]])
            XCTAssertTrue(diff.inserted.isEmpty)
            XCTAssertEqual(diff.updated.count, 1)
            XCTAssertEqual(diff.updated[0].name, "Barbara")
            XCTAssertEqual(diff.updated[0].reuseCount, 1)
            XCTAssertTrue(diff.deleted.isEmpty)
        }
        
        do {
            let diff = reducer.diff([["id": 1, "name": "Craig"]])
            XCTAssertTrue(diff.inserted.isEmpty)
            XCTAssertEqual(diff.updated.count, 1)
            XCTAssertEqual(diff.updated[0].name, "Craig")
            XCTAssertEqual(diff.updated[0].reuseCount, 2)
            XCTAssertTrue(diff.deleted.isEmpty)
        }
        
        do {
            let diff = reducer.diff([])
            XCTAssertTrue(diff.inserted.isEmpty)
            XCTAssertTrue(diff.updated.isEmpty)
            XCTAssertEqual(diff.deleted.count, 1)
            XCTAssertEqual(diff.deleted[0].name, "Craig")
            XCTAssertEqual(diff.deleted[0].reuseCount, 2)
        }
    }
    
    static var allTests = [
        ("testReducer", testReducer),
        ("testUpdateElement", testUpdateElement),
        ]
}
