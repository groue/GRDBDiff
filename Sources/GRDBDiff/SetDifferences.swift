public struct SetDifferences<Element> {
    public var inserted: [Element]
    public var updated: [Element]
    public var deleted: [Element]
    
    // Internal for testability
    /* private */ var isEmpty: Bool {
        return inserted.isEmpty && updated.isEmpty && deleted.isEmpty
    }
}

extension SetDifferences: Equatable where Element: Equatable {
    public static func == (lhs: SetDifferences, rhs: SetDifferences) -> Bool {
        if lhs.inserted != rhs.inserted { return false }
        if lhs.updated != rhs.updated { return false }
        if lhs.deleted != rhs.deleted { return false }
        return true
    }
}
