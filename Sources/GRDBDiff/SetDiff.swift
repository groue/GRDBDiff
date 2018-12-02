public struct SetDiff<Element> {
    public var inserted: [Element]
    public var updated: [Element]
    public var deleted: [Element]
    
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
