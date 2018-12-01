import XCTest
@testable import GRDBDiff

class RowsSetDifferenciatorTests: XCTestCase {
    func testReducer() {
        struct Raw: Equatable {
            var id: Int
            var name: String
        }
        var reducer = RowsSetDifferenciator<String, Raw, Int>(
            key: { (raw: Raw) in raw.id },
            initialElements: [],
            makeElement: { (raw: Raw) in raw.name },
            updateElement: { (element: String, raw: Raw) in raw.name })
        
        do {
            let diff: SetDifferences<String> = reducer.diff([])
            XCTAssertTrue(diff.isEmpty)
        }
        
        do {
            let diff = reducer.diff([
                Raw(id: 1, name: "Arthur")
                ])
            XCTAssertEqual(diff.inserted.count, 1)
            XCTAssertEqual(diff.inserted[0], "Arthur")
            XCTAssertTrue(diff.updated.isEmpty)
            XCTAssertTrue(diff.deleted.isEmpty)
        }
        
        do {
            let diff = reducer.diff([
                Raw(id: 1, name: "Barbara")
                ])
            XCTAssertTrue(diff.inserted.isEmpty)
            XCTAssertEqual(diff.updated.count, 1)
            XCTAssertEqual(diff.updated[0], "Barbara")
            XCTAssertTrue(diff.deleted.isEmpty)
        }
        
        do {
            let diff = reducer.diff([
                Raw(id: 2, name: "Craig")
                ])
            XCTAssertEqual(diff.inserted.count, 1)
            XCTAssertEqual(diff.inserted[0], "Craig")
            XCTAssertTrue(diff.updated.isEmpty)
            XCTAssertEqual(diff.deleted.count, 1)
            XCTAssertEqual(diff.deleted[0], "Barbara")
        }
        
        do {
            let diff = reducer.diff([
                Raw(id: 1, name: "David"),
                Raw(id: 2, name: "Eugenia"),
                Raw(id: 3, name: "Fiona"),
                Raw(id: 4, name: "Gerhard"),
                ])
            XCTAssertEqual(diff.inserted.count, 3)
            XCTAssertEqual(Set(diff.inserted), ["David", "Fiona", "Gerhard"])
            XCTAssertEqual(diff.updated.count, 1)
            XCTAssertEqual(diff.updated[0], "Eugenia")
            XCTAssertTrue(diff.deleted.isEmpty)
        }
        
        do {
            let diff = reducer.diff([
                Raw(id: 1, name: "Henri"),
                Raw(id: 3, name: "Irene"),
                Raw(id: 5, name: "Jules"),
                Raw(id: 6, name: "Karl"),
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
                Raw(id: 1, name: "Henri"),
                Raw(id: 3, name: "Irene"),
                Raw(id: 5, name: "Jules"),
                Raw(id: 6, name: "Karl"),
                ])
            XCTAssertTrue(diff.isEmpty)
        }
    }
    
    func testUpdateElement() {
        struct Raw: Equatable {
            var id: Int
            var name: String
        }
        class Element {
            var name: String
            var reuseCount = 0
            
            init(name: String) {
                self.name = name
            }
        }
        
        var reducer = RowsSetDifferenciator<Element, Raw, Int>(
            key: { (raw: Raw) in raw.id },
            initialElements: [],
            makeElement: { (raw: Raw) in Element(name: raw.name) },
            updateElement: { (element: Element, raw: Raw) in
                element.name = raw.name
                element.reuseCount += 1
                return element })
        
        do {
            let diff = reducer.diff([Raw(id: 1, name: "Arthur")])
            XCTAssertEqual(diff.inserted.count, 1)
            XCTAssertEqual(diff.inserted[0].name, "Arthur")
            XCTAssertEqual(diff.inserted[0].reuseCount, 0)
            XCTAssertTrue(diff.updated.isEmpty)
            XCTAssertTrue(diff.deleted.isEmpty)
        }
        
        do {
            let diff = reducer.diff([Raw(id: 1, name: "Barbara")])
            XCTAssertTrue(diff.inserted.isEmpty)
            XCTAssertEqual(diff.updated.count, 1)
            XCTAssertEqual(diff.updated[0].name, "Barbara")
            XCTAssertEqual(diff.updated[0].reuseCount, 1)
            XCTAssertTrue(diff.deleted.isEmpty)
        }
        
        do {
            let diff = reducer.diff([Raw(id: 1, name: "Craig")])
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
