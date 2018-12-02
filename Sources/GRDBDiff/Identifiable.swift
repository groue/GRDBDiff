/// A protocol for "identifiable" values, which have an identity.
///
/// When an identifiable type also adopts the Equatable protocol, two values
/// that are equal must have the same identity. It is a programmer error to
/// break this rule.
///
/// However, two values that share the same identity may not be equal.
/// In GRDBDiff, a value has been "updated" if two versions share the
/// same identity, but are not equal.
public protocol Identifiable {
    associatedtype Identity: Equatable
    var identity: Identity { get }
}
