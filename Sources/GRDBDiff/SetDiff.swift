/// SetDiff describes the difference between two sets of elements.
public struct SetDiff<Element> {
    /// The inserted elements
    public var inserted: [Element]
    /// The updated elements
    public var updated: [Element]
    /// The deleted elements
    public var deleted: [Element]
    
    /// True if diff contains no inserted, updated, or deleted element.
    var isEmpty: Bool {
        return inserted.isEmpty && updated.isEmpty && deleted.isEmpty
    }
}

extension SetDiff: Equatable where Element: Equatable {
    public static func == (lhs: SetDiff, rhs: SetDiff) -> Bool {
        if lhs.inserted != rhs.inserted { return false }
        if lhs.updated != rhs.updated { return false }
        if lhs.deleted != rhs.deleted { return false }
        return true
    }
}
