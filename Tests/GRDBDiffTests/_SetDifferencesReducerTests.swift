import XCTest
@testable import GRDBDiff

class _SetDifferencesReducerTests: XCTestCase {
    func testReducer() {
        struct Raw: Equatable {
            var id: Int
            var name: String
        }
        var reducer = _SetDifferencesReducer<String, Raw, Int>(
            key: { (raw: Raw) in raw.id },
            makeElement: { (raw: Raw) in raw.name },
            updateElement: { (oldElement: String, raw: Raw) in raw.name })

        do {
            let diff: SetDifferences<String>? = reducer.value([])
            XCTAssertNil(diff)
        }

        do {
            let diff = reducer.value([
                Raw(id: 1, name: "Arthur")
                ])
            if let diff = diff {
                XCTAssertEqual(diff.inserted.count, 1)
                XCTAssertEqual(diff.inserted[0], "Arthur")
                XCTAssertTrue(diff.updated.isEmpty)
                XCTAssertTrue(diff.deleted.isEmpty)
            } else {
                XCTFail("Expected diff")
            }
        }

        do {
            let diff = reducer.value([
                Raw(id: 1, name: "Barbara")
                ])
            if let diff = diff {
                XCTAssertTrue(diff.inserted.isEmpty)
                XCTAssertEqual(diff.updated.count, 1)
                XCTAssertEqual(diff.updated[0], "Barbara")
                XCTAssertTrue(diff.deleted.isEmpty)
            } else {
                XCTFail("Expected diff")
            }
        }

        do {
            let diff = reducer.value([
                Raw(id: 2, name: "Craig")
                ])
            if let diff = diff {
                XCTAssertEqual(diff.inserted.count, 1)
                XCTAssertEqual(diff.inserted[0], "Craig")
                XCTAssertTrue(diff.updated.isEmpty)
                XCTAssertEqual(diff.deleted.count, 1)
                XCTAssertEqual(diff.deleted[0], "Barbara")
            } else {
                XCTFail("Expected diff")
            }
        }

        do {
            let diff = reducer.value([
                Raw(id: 1, name: "David"),
                Raw(id: 2, name: "Eugenia"),
                Raw(id: 3, name: "Fiona"),
                Raw(id: 4, name: "Gerhard"),
                ])
            if let diff = diff {
                XCTAssertEqual(diff.inserted.count, 3)
                XCTAssertEqual(Set(diff.inserted), ["David", "Fiona", "Gerhard"])
                XCTAssertEqual(diff.updated.count, 1)
                XCTAssertEqual(diff.updated[0], "Eugenia")
                XCTAssertTrue(diff.deleted.isEmpty)
            } else {
                XCTFail("Expected diff")
            }
        }

        do {
            let diff = reducer.value([
                Raw(id: 1, name: "Henri"),
                Raw(id: 3, name: "Irene"),
                Raw(id: 5, name: "Jules"),
                Raw(id: 6, name: "Karl"),
                ])
            if let diff = diff {
                XCTAssertEqual(diff.inserted.count, 2)
                XCTAssertEqual(Set(diff.inserted), ["Jules", "Karl"])
                XCTAssertEqual(diff.updated.count, 2)
                XCTAssertEqual(Set(diff.updated), ["Henri", "Irene"])
                XCTAssertEqual(diff.deleted.count, 2)
                XCTAssertEqual(Set(diff.deleted), ["Eugenia", "Gerhard"])
            } else {
                XCTFail("Expected diff")
            }
        }

        do {
            let diff = reducer.value([
                Raw(id: 1, name: "Henri"),
                Raw(id: 3, name: "Irene"),
                Raw(id: 5, name: "Jules"),
                Raw(id: 6, name: "Karl"),
                ])
            XCTAssertNil(diff)
        }
    }

    static var allTests = [
        ("testReducer", testReducer),
        ]
}
