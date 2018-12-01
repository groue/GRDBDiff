import XCTest
import GRDB
@testable import GRDBDiff

class RecordSetDifferenciatorTests: XCTestCase {
    func testReducer() {
        struct Element: FetchableRecord {
            var name: String
            
            init(row: Row) {
                self.name = row["name"]
            }
        }
        
        var reducer = RecordSetDifferenciator<Element>(
            key: { (row: Row) in RowValue(dbValues: [row["id"]]) },
            initialElements: [],
            updateElement: { (element: Element, row: Row) in Element(row: row) })
        
        do {
            let diff: SetDifferences<Element> = reducer.diff([])
            XCTAssertTrue(diff.isEmpty)
        }
        
        do {
            let diff = reducer.diff([
                ["id": 1, "name": "Arthur"]
                ])
            XCTAssertEqual(diff.inserted.count, 1)
            XCTAssertEqual(diff.inserted[0].name, "Arthur")
            XCTAssertTrue(diff.updated.isEmpty)
            XCTAssertTrue(diff.deleted.isEmpty)
        }
        
        do {
            let diff = reducer.diff([
                ["id": 1, "name": "Barbara"]
                ])
            XCTAssertTrue(diff.inserted.isEmpty)
            XCTAssertEqual(diff.updated.count, 1)
            XCTAssertEqual(diff.updated[0].name, "Barbara")
            XCTAssertTrue(diff.deleted.isEmpty)
        }
        
        do {
            let diff = reducer.diff([
                ["id": 2, "name": "Craig"]
                ])
            XCTAssertEqual(diff.inserted.count, 1)
            XCTAssertEqual(diff.inserted[0].name, "Craig")
            XCTAssertTrue(diff.updated.isEmpty)
            XCTAssertEqual(diff.deleted.count, 1)
            XCTAssertEqual(diff.deleted[0].name, "Barbara")
        }
        
        do {
            let diff = reducer.diff([
                ["id": 1, "name": "David"],
                ["id": 2, "name": "Eugenia"],
                ["id": 3, "name": "Fiona"],
                ["id": 4, "name": "Gerhard"],
                ])
            XCTAssertEqual(diff.inserted.count, 3)
            XCTAssertEqual(Set(diff.inserted.map { $0.name }), ["David", "Fiona", "Gerhard"])
            XCTAssertEqual(diff.updated.count, 1)
            XCTAssertEqual(diff.updated[0].name, "Eugenia")
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
            XCTAssertEqual(Set(diff.inserted.map { $0.name }), ["Jules", "Karl"])
            XCTAssertEqual(diff.updated.count, 2)
            XCTAssertEqual(Set(diff.updated.map { $0.name }), ["Henri", "Irene"])
            XCTAssertEqual(diff.deleted.count, 2)
            XCTAssertEqual(Set(diff.deleted.map { $0.name }), ["Eugenia", "Gerhard"])
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
        final class Element: FetchableRecord {
            var name: String
            var updateCount = 0
            
            init(row: Row) {
                self.name = row["name"]
            }
        }
        
        var reducer = RecordSetDifferenciator<Element>(
            key: { (row: Row) in RowValue(dbValues: [row["id"]]) },
            initialElements: [],
            updateElement: { (element: Element, row: Row) in
                let new = Element(row: row)
                new.updateCount = element.updateCount + 1
                return new
        })
        
        do {
            let diff = reducer.diff([["id": 1, "name": "Arthur"]])
            XCTAssertEqual(diff.inserted.count, 1)
            XCTAssertEqual(diff.inserted[0].name, "Arthur")
            XCTAssertEqual(diff.inserted[0].updateCount, 0)
            XCTAssertTrue(diff.updated.isEmpty)
            XCTAssertTrue(diff.deleted.isEmpty)
        }
        
        do {
            let diff = reducer.diff([["id": 1, "name": "Barbara"]])
            XCTAssertTrue(diff.inserted.isEmpty)
            XCTAssertEqual(diff.updated.count, 1)
            XCTAssertEqual(diff.updated[0].name, "Barbara")
            XCTAssertEqual(diff.updated[0].updateCount, 1)
            XCTAssertTrue(diff.deleted.isEmpty)
        }
        
        do {
            let diff = reducer.diff([["id": 1, "name": "Craig"]])
            XCTAssertTrue(diff.inserted.isEmpty)
            XCTAssertEqual(diff.updated.count, 1)
            XCTAssertEqual(diff.updated[0].name, "Craig")
            XCTAssertEqual(diff.updated[0].updateCount, 2)
            XCTAssertTrue(diff.deleted.isEmpty)
        }
        
        do {
            let diff = reducer.diff([])
            XCTAssertTrue(diff.inserted.isEmpty)
            XCTAssertTrue(diff.updated.isEmpty)
            XCTAssertEqual(diff.deleted.count, 1)
            XCTAssertEqual(diff.deleted[0].name, "Craig")
            XCTAssertEqual(diff.deleted[0].updateCount, 2)
        }
    }
    
    static var allTests = [
        ("testReducer", testReducer),
        ("testUpdateElement", testUpdateElement),
        ]
}
