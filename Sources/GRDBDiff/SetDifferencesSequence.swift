/// Given two sorted sequences (old and new), SetDifferencesSequence emits
/// "diff elements" which tell whether elements are only found in the old
/// sequence, in the new, or in both.
///
/// Both sequences do not have to share the same element type. Yet elements must
/// share a common comparable *key*.
///
/// Both sequences must be sorted by this key.
///
/// Keys must be unique in both sequences.
///
/// The example below compare two sequences sorted by integer representation:
///
///     for item in SetDifferencesSequence(
///         old: [1,2,3],
///         new: ["2", "3", "4"],
///         oldKey: { $0 },
///         newKey: { Int($0)! })
///     {
///         switch item {
///         case .deleted(let old):
///             print("- old: \(old)")
///         case .updated(let old, let new):
///             print("- updated: \(old), \(new)")
///         case .inserted(let new):
///             print("- new: \(new)")
///         }
///     }
///     // Prints:
///     // - deleted: 1
///     // - updated: 2, 2
///     // - updated: 3, 3
///     // - inserted: 4
struct SetDifferencesSequence<Old: Sequence, New: Sequence, Key: Comparable>: IteratorProtocol, Sequence {
    enum Element {
        /// An element only found in the new sequence:
        case inserted(New.Element)
        /// Old and new elements share the same key:
        case updated(Old.Element, New.Element)
        /// An element only found in the old sequence:
        case deleted(Old.Element)
    }
    
    var oldIter: Old.Iterator
    var newIter: New.Iterator
    var oldElem: Old.Element?
    var newElem: New.Element?
    let oldKey: (Old.Element) -> Key
    let newKey: (New.Element) -> Key

    /// Creates a SetDifferencesSequence.
    ///
    /// - parameters:
    ///     - old: The old sequence.
    ///     - new: The new sequence.
    ///     - oldKey: A function that returns the key of an old element.
    ///     - newKey: A function that returns the key of a new element.
    init(
        old: Old,
        new: New,
        oldKey: @escaping (Old.Element) -> Key,
        newKey: @escaping (New.Element) -> Key)
    {
        self.oldIter = old.makeIterator()
        self.newIter = new.makeIterator()
        self.oldElem = oldIter.next()
        self.newElem = newIter.next()
        self.oldKey = oldKey
        self.newKey = newKey
    }
    
    mutating func next() -> Element? {
        switch (oldElem, newElem) {
        case (let old?, let new?):
            let oldKey = self.oldKey(old)
            let newKey = self.newKey(new)
            if oldKey > newKey {
                self.newElem = newIter.next()
                return .inserted(new)
            } else if oldKey == newKey {
                self.oldElem = oldIter.next()
                self.newElem = newIter.next()
                return .updated(old, new)
            } else {
                self.oldElem = oldIter.next()
                return .deleted(old)
            }
        case (nil, let new?):
            self.newElem = newIter.next()
            return .inserted(new)
        case (let old?, nil):
            self.oldElem = oldIter.next()
            return .deleted(old)
        case (nil, nil):
            return nil
        }
    }
}
