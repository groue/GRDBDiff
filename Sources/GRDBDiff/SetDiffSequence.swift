/// Given two sequences (old and new), SetDiffSequence emits "diff elements"
/// which tell whether elements are only found in the old sequence, in the new,
/// or in both.
///
/// To give correct results, the two sequences must honor a few preconditions:
///
/// - Both sequences do not have to share the same element type, but elements
///     must share a common *identity* which conforms to Comparable.
///
/// - Both sequences must be sorted by identity (checked in DEBUG builds).
///
/// - Identities must be unique in each sequences (checked in DEBUG builds).
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
    
    #if DEBUG
    private var oldPreviousId: Old.Element.Identity?
    private var newPreviousId: New.Element.Identity?
    private var oldElem: Old.Element? {
        didSet {
            if let oldElem = oldElem, let oldPreviousId = oldPreviousId {
                precondition(oldPreviousId != oldElem.identity, "Sequence identities are not unique")
                precondition(oldPreviousId < oldElem.identity, "Sequence is not sorted by identity")
            }
            oldPreviousId = oldElem?.identity
        }
    }
    private var newElem: New.Element? {
        didSet {
            if let newElem = newElem, let newPreviousId = newPreviousId {
                precondition(newPreviousId != newElem.identity, "Sequence identities are not unique")
                precondition(newPreviousId < newElem.identity, "Sequence is not sorted by identity")
            }
            newPreviousId = newElem?.identity
        }
    }
    #else
    private var oldElem: Old.Element?
    private var newElem: New.Element?
    #endif

    /// Creates a SetDifferencesSequence.
    ///
    /// - parameter old: The old sequence.
    /// - parameter new: The new sequence.
    init(old: Old, new: New) {
        oldIter = old.makeIterator()
        newIter = new.makeIterator()
        oldElem = oldIter.next()
        newElem = newIter.next()
        #if DEBUG
        oldPreviousId = oldElem?.identity
        newPreviousId = newElem?.identity
        #endif
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
