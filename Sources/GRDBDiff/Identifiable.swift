public protocol Identifiable {
    associatedtype Identity: Equatable
    var identity: Identity { get }
}
