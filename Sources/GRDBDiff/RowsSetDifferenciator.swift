struct RowsSetDifferenciator<Element, Raw: Equatable, Key: Comparable> {
    private struct Item {
        let key: Key
        let raw: Raw
        let element: Element
    }
    
    private let key: (Raw) -> Key
    private let makeElement: (Raw) -> Element
    private let updateElement: (Element, Raw) -> Element
    private var oldItems: [Item] = []
    
    init(
        key: @escaping (Raw) -> Key,
        initialElements: [(Raw, Element)],
        makeElement: @escaping (Raw) -> Element,
        updateElement: @escaping (Element, Raw) -> Element)
    {
        self.key = key
        self.makeElement = makeElement
        self.updateElement = updateElement
        self.oldItems = initialElements.map { pair in
            Item(key: key(pair.0), raw: pair.0, element: pair.1)
        }
    }
    
    mutating func diff(_ raws: [Raw]) -> SetDifferences<Element> {
        var diff = SetDifferences<Element>(inserted: [], updated: [], deleted: [])
        var newItems: [Item] = []
        defer { self.oldItems = newItems }
        
        let diffElements = SetDifferencesSequence(
            old: oldItems,
            new: raws.map { (key: key($0), raw: $0) },
            oldKey: { $0.key },
            newKey: { $0.key })
        
        for diffElement in diffElements {
            switch diffElement {
            case .inserted(let new):
                let element = makeElement(new.raw)
                diff.inserted.append(element)
                newItems.append(Item(key: new.key, raw: new.raw, element: element))
                
            case .updated(let old, let new):
                if new.raw == old.raw {
                    // unchanged
                    newItems.append(old)
                } else {
                    let updatedElement = updateElement(old.element, new.raw)
                    diff.updated.append(updatedElement)
                    newItems.append(Item(key: old.key, raw: new.raw, element: updatedElement))
                }
                
            case .deleted(let old):
                diff.deleted.append(old.element)
            }
        }
        
        return diff
    }
}
