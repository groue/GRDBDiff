import GRDB

struct RowsSetDifferenciator<Element> {
    private struct Item: Identifiable {
        let identity: RowValue
        let row: Row
        let element: Element
    }
    
    private struct NewItem: Identifiable {
        let identity: RowValue
        let row: Row
    }

    private let key: (Row) -> RowValue
    private let makeElement: (Row) -> Element
    private let updateElement: (Element, Row) -> Element
    private var oldItems: [Item] = []
    
    init(
        key: @escaping (Row) -> RowValue,
        initialElements: [(Row, Element)],
        makeElement: @escaping (Row) -> Element,
        updateElement: @escaping (Element, Row) -> Element)
    {
        self.key = key
        self.makeElement = makeElement
        self.updateElement = updateElement
        self.oldItems = initialElements.map { pair in
            Item(identity: key(pair.0), row: pair.0, element: pair.1)
        }
    }
    
    mutating func diff(_ rows: [Row]) -> SetDifferences<Element> {
        var diff = SetDifferences<Element>(inserted: [], updated: [], deleted: [])
        var newItems: [Item] = []
        defer { self.oldItems = newItems }
        
        let diffElements = SetDifferencesSequence(
            old: oldItems,
            new: rows.map { NewItem(identity: key($0), row: $0) })
        
        for diffElement in diffElements {
            switch diffElement {
            case .inserted(let new):
                let element = makeElement(new.row)
                diff.inserted.append(element)
                newItems.append(Item(identity: new.identity, row: new.row, element: element))
                
            case .updated(let old, let new):
                if new.row == old.row {
                    // unchanged
                    newItems.append(old)
                } else {
                    let updatedElement = updateElement(old.element, new.row)
                    diff.updated.append(updatedElement)
                    newItems.append(Item(identity: old.identity, row: new.row, element: updatedElement))
                }
                
            case .deleted(let old):
                diff.deleted.append(old.element)
            }
        }
        
        return diff
    }
}
