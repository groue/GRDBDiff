import XCTest
import GRDB
@testable import GRDBDiff

class IdentifiableSetDifferTests: XCTestCase {
    func testDiff() {
        struct Element: Identifiable, Equatable {
            var identity: Int
            var name: String
        }
        
        var differ = IdentifiableSetDiffer<Element>(
            updateElement: { (oldElement, newElement) in newElement })
        
        do {
            let diff: SetDifferences<Element> = differ.diff([])
            XCTAssertTrue(diff.isEmpty)
        }
        
        do {
            let diff = differ.diff([
                Element(identity: 1, name: "Arthur")
                ])
            XCTAssertEqual(diff.inserted.count, 1)
            XCTAssertEqual(diff.inserted[0].name, "Arthur")
            XCTAssertTrue(diff.updated.isEmpty)
            XCTAssertTrue(diff.deleted.isEmpty)
        }
        
        do {
            let diff = differ.diff([
                Element(identity: 1, name: "Barbara")
                ])
            XCTAssertTrue(diff.inserted.isEmpty)
            XCTAssertEqual(diff.updated.count, 1)
            XCTAssertEqual(diff.updated[0].name, "Barbara")
            XCTAssertTrue(diff.deleted.isEmpty)
        }
        
        do {
            let diff = differ.diff([
                Element(identity: 2, name: "Craig")
                ])
            XCTAssertEqual(diff.inserted.count, 1)
            XCTAssertEqual(diff.inserted[0].name, "Craig")
            XCTAssertTrue(diff.updated.isEmpty)
            XCTAssertEqual(diff.deleted.count, 1)
            XCTAssertEqual(diff.deleted[0].name, "Barbara")
        }
        
        do {
            let diff = differ.diff([
                Element(identity: 1, name: "David"),
                Element(identity: 2, name: "Eugenia"),
                Element(identity: 3, name: "Fiona"),
                Element(identity: 4, name: "Gerhard"),
                ])
            XCTAssertEqual(diff.inserted.count, 3)
            XCTAssertEqual(Set(diff.inserted.map { $0.name }), ["David", "Fiona", "Gerhard"])
            XCTAssertEqual(diff.updated.count, 1)
            XCTAssertEqual(diff.updated[0].name, "Eugenia")
            XCTAssertTrue(diff.deleted.isEmpty)
        }
        
        do {
            let diff = differ.diff([
                Element(identity: 1, name: "Henri"),
                Element(identity: 3, name: "Irene"),
                Element(identity: 5, name: "Jules"),
                Element(identity: 6, name: "Karl"),
                ])
            XCTAssertEqual(diff.inserted.count, 2)
            XCTAssertEqual(Set(diff.inserted.map { $0.name }), ["Jules", "Karl"])
            XCTAssertEqual(diff.updated.count, 2)
            XCTAssertEqual(Set(diff.updated.map { $0.name }), ["Henri", "Irene"])
            XCTAssertEqual(diff.deleted.count, 2)
            XCTAssertEqual(Set(diff.deleted.map { $0.name }), ["Eugenia", "Gerhard"])
        }
        
        do {
            let diff = differ.diff([
                Element(identity: 1, name: "Henri"),
                Element(identity: 3, name: "Irene"),
                Element(identity: 5, name: "Jules"),
                Element(identity: 6, name: "Karl"),
                ])
            XCTAssertTrue(diff.isEmpty)
        }
    }
    
    func testUpdateElement() {
        struct Element: Identifiable, Equatable {
            var identity: Int
            var name: String
            var updateCount = 0
        }
        
        var differ = IdentifiableSetDiffer<Element>(
            updateElement: { (oldElement, newElement) in
                var newElement = newElement
                newElement.updateCount = oldElement.updateCount + 1
                return newElement
        })
        
        do {
            let diff = differ.diff([Element(identity: 1, name: "Arthur", updateCount: 0)])
            XCTAssertEqual(diff.inserted.count, 1)
            XCTAssertEqual(diff.inserted[0].name, "Arthur")
            XCTAssertEqual(diff.inserted[0].updateCount, 0)
            XCTAssertTrue(diff.updated.isEmpty)
            XCTAssertTrue(diff.deleted.isEmpty)
        }
        
        do {
            let diff = differ.diff([Element(identity: 1, name: "Barbara", updateCount: 0)])
            XCTAssertTrue(diff.inserted.isEmpty)
            XCTAssertEqual(diff.updated.count, 1)
            XCTAssertEqual(diff.updated[0].name, "Barbara")
            XCTAssertEqual(diff.updated[0].updateCount, 1)
            XCTAssertTrue(diff.deleted.isEmpty)
        }
        
        do {
            let diff = differ.diff([Element(identity: 1, name: "Craig", updateCount: 0)])
            XCTAssertTrue(diff.inserted.isEmpty)
            XCTAssertEqual(diff.updated.count, 1)
            XCTAssertEqual(diff.updated[0].name, "Craig")
            XCTAssertEqual(diff.updated[0].updateCount, 2)
            XCTAssertTrue(diff.deleted.isEmpty)
        }
        
        do {
            let diff = differ.diff([])
            XCTAssertTrue(diff.inserted.isEmpty)
            XCTAssertTrue(diff.updated.isEmpty)
            XCTAssertEqual(diff.deleted.count, 1)
            XCTAssertEqual(diff.deleted[0].name, "Craig")
            XCTAssertEqual(diff.deleted[0].updateCount, 2)
        }
    }
    
    static var allTests = [
        ("testDiff", testDiff),
        ("testUpdateElement", testUpdateElement),
        ]
}
