/// Given two sorted sequences (left and right), this function emits
/// "diff elements" which tell whether elements are only found on the left, on
/// the right, or on both sides.
///
/// Both sequences do not have to share the same element type. Yet elements must
/// share a common comparable *key*.
///
/// Both sequences must be sorted by this key.
///
/// Keys must be unique in both sequences.
///
/// The example below compare two sequences sorted by integer representation,
/// and prints:
///
/// - Left: 1
/// - Common: 2, 2
/// - Common: 3, 3
/// - Right: 4
///
///     for item in DiffSequence(
///         left: [1,2,3],
///         right: ["2", "3", "4"],
///         leftKey: { $0 },
///         rightKey: { Int($0)! })
///     {
///         switch item {
///         case .left(let left):
///             print("- Left: \(left)")
///         case .right(let right):
///             print("- Right: \(right)")
///         case .common(let left, let right):
///             print("- Common: \(left), \(right)")
///         }
///     }
///
/// - parameters:
///     - left: The left sequence.
///     - right: The right sequence.
///     - leftKey: A function that returns the key of a left element.
///     - rightKey: A function that returns the key of a right element.
/// - returns: A sequence of diff items
struct DiffSequence<Left: Sequence, Right: Sequence, Key: Comparable>: IteratorProtocol, Sequence {
    enum Element {
        /// An element only found in the left sequence:
        case left(Left.Element)
        /// An element only found in the right sequence:
        case right(Right.Element)
        /// Left and right elements share a common key:
        case common(Left.Element, Right.Element)
    }
    
    var lIter: Left.Iterator
    var rIter: Right.Iterator
    var lElem: Left.Element?
    var rElem: Right.Element?
    let lKey: (Left.Element) -> Key
    let rKey: (Right.Element) -> Key
    
    init(
        left: Left,
        right: Right,
        leftKey: @escaping (Left.Element) -> Key,
        rightKey: @escaping (Right.Element) -> Key)
    {
        lIter = left.makeIterator()
        rIter = right.makeIterator()
        lElem = lIter.next()
        rElem = rIter.next()
        lKey = leftKey
        rKey = rightKey
    }
    
    mutating func next() -> Element? {
        switch (lElem, rElem) {
        case (let lElem?, let rElem?):
            let (lKey, rKey) = (self.lKey(lElem), self.rKey(rElem))
            if lKey > rKey {
                self.rElem = rIter.next()
                return .right(rElem)
            } else if lKey == rKey {
                self.lElem = lIter.next()
                self.rElem = rIter.next()
                return .common(lElem, rElem)
            } else {
                self.lElem = lIter.next()
                return .left(lElem)
            }
        case (nil, let rElem?):
            self.rElem = rIter.next()
            return .right(rElem)
        case (let lElem?, nil):
            self.lElem = lIter.next()
            return .left(lElem)
        case (nil, nil):
            return nil
        }
    }
}
