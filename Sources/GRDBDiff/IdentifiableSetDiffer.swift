struct IdentifiableSetDiffer<Element: Identifiable>
    where Element: Equatable,
    Element.Identity: Comparable
{
    private let updateElement: (Element, Element) -> Element
    private var oldElements: [Element] = []
    
    init(updateElement: @escaping (Element, Element) -> Element) {
        self.updateElement = updateElement
    }
    
    mutating func diff<S: Sequence>(_ elements: S) -> SetDifferences<Element> where S.Element == Element {
        var diff = SetDifferences<Element>(inserted: [], updated: [], deleted: [])
        var newElements: [Element] = []
        defer { self.oldElements = newElements }
        
        for diffElement in SetDifferencesSequence(old: oldElements, new: elements) {
            switch diffElement {
            case .inserted(let new):
                diff.inserted.append(new)
                newElements.append(new)
                
            case .common(let old, let new):
                if new == old {
                    // Unchanged. Keep old element, so that we reuse reference types.
                    newElements.append(old)
                } else {
                    let updatedElement = updateElement(old, new)
                    diff.updated.append(updatedElement)
                    newElements.append(updatedElement)
                }
                
            case .deleted(let old):
                diff.deleted.append(old)
            }
        }
        
        return diff
    }
}
