/// Given two sorted sequences (old and new), SetDifferencesSequence emits
/// "diff elements" which tell whether elements are only found in the old
/// sequence, in the new, or in both.
///
/// Both sequences do not have to share the same element type. Yet elements must
/// share a common comparable *identity*.
///
/// Both sequences must be sorted by identity.
///
/// Identities must be unique in both sequences.
struct SetDiffSequence<Old: Sequence, New: Sequence>: IteratorProtocol, Sequence
    where
    Old.Element: Identifiable,
    New.Element: Identifiable,
    Old.Element.Identity == New.Element.Identity,
    Old.Element.Identity: Comparable
{
    enum Element {
        /// An element only found in the new sequence:
        case inserted(New.Element)
        /// Old and new elements share the same key:
        case common(Old.Element, New.Element)
        /// An element only found in the old sequence:
        case deleted(Old.Element)
    }
    
    private var oldIter: Old.Iterator
    private var newIter: New.Iterator
    private var oldElem: Old.Element?
    private var newElem: New.Element?

    /// Creates a SetDifferencesSequence.
    ///
    /// - parameters:
    ///     - old: The old sequence.
    ///     - new: The new sequence.
    init(old: Old, new: New) {
        self.oldIter = old.makeIterator()
        self.newIter = new.makeIterator()
        self.oldElem = oldIter.next()
        self.newElem = newIter.next()
    }
    
    mutating func next() -> Element? {
        switch (oldElem, newElem) {
        case (let old?, let new?):
            let oldId = old.identity
            let newId = new.identity
            if oldId > newId {
                newElem = newIter.next()
                return .inserted(new)
            } else if oldId == newId {
                oldElem = oldIter.next()
                newElem = newIter.next()
                return .common(old, new)
            } else {
                oldElem = oldIter.next()
                return .deleted(old)
            }
        case (nil, let new?):
            newElem = newIter.next()
            return .inserted(new)
        case (let old?, nil):
            oldElem = oldIter.next()
            return .deleted(old)
        case (nil, nil):
            return nil
        }
    }
}
