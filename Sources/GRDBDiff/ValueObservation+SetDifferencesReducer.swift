import GRDB

extension ValueObservation where Reducer == Void {
    func trackingSetDifferences<Request>(
        in request: Request,
        updateElement: @escaping (Request.RowDecoder, Row) -> Request.RowDecoder = { Request.RowDecoder(row: $1) })
        -> ValueObservation<SetDifferencesReducer<Request.RowDecoder>>
        where
        Request: FetchRequest,
        Request.RowDecoder: FetchableRecord & TableRecord
    {
        return setDifferencesObservation(
            in: request,
            fetch: { try Row.fetchAll($0, request) },
            key: request.primaryKey,
            makeElement: Request.RowDecoder.init(row:),
            updateElement: updateElement)
    }
}

// This function workarounds a compiler bug which prevents us to define it as a
// static method in an extension of ValueObservation.
private func setDifferencesObservation<Element>(
    in region: DatabaseRegionConvertible,
    fetch: @escaping (Database) throws -> [Row],
    key: @escaping (Database) throws -> (Row) -> RowValue,
    makeElement: @escaping (Row) -> Element,
    updateElement: @escaping (Element, Row) -> Element)
    -> ValueObservation<SetDifferencesReducer<Element>>
{
    return ValueObservation.tracking(region, reducer: { db in
        let key = try key(db)
        return SetDifferencesReducer<Element>(
            fetch: fetch,
            key: key,
            makeElement: makeElement,
            updateElement: updateElement)
        
    })
}

public struct SetDifferences<Element> {
    public var inserted: [Element]
    public var updated: [Element]
    public var deleted: [Element]
    public var isEmpty: Bool {
        return inserted.isEmpty && updated.isEmpty && deleted.isEmpty
    }
}

public struct SetDifferencesReducer<Element>: ValueReducer {
    private let _fetch: (Database) throws -> [Row]
    private var scanner: _SetDifferencesReducer<Element, Row, RowValue>
    
    fileprivate init(
        fetch: @escaping (Database) throws -> [Row],
        key: @escaping (Row) -> RowValue,
        makeElement: @escaping (Row) -> Element,
        updateElement: @escaping (Element, Row) -> Element)
    {
        self._fetch = fetch
        self.scanner = _SetDifferencesReducer(key: key, makeElement: makeElement, updateElement: updateElement)
    }
    
    /// :nodoc:
    public func fetch(_ db: Database) throws -> [Row] {
        return try _fetch(db)
    }
    
    /// :nodoc:
    public mutating func value(_ rows: [Row]) -> SetDifferences<Element>? {
        return scanner.value(rows)
    }
}

// Internal for testability
/* private */ struct _SetDifferencesReducer<Element, Raw: Equatable, Key: Comparable> {
    private struct Item {
        let key: Key
        let raw: Raw
        let element: Element
    }
    
    private let key: (Raw) -> Key
    private let makeElement: (Raw) -> Element
    private let updateElement: (Element, Raw) -> Element
    private var previousItems: [Item] = []
    
    fileprivate init(
        key: @escaping (Raw) -> Key,
        makeElement: @escaping (Raw) -> Element,
        updateElement: @escaping (Element, Raw) -> Element)
    {
        self.key = key
        self.makeElement = makeElement
        self.updateElement = updateElement
    }
    
    /// :nodoc:
    public mutating func value(_ raws: [Raw]) -> SetDifferences<Element>? {
        var diff = SetDifferences<Element>(inserted: [], updated: [], deleted: [])
        var nextItems: [Item] = []
        defer { self.previousItems = nextItems }
        
        for diffElement in DiffSequence(
            left: previousItems,
            right: raws.map { (key: key($0), raw: $0) },
            leftKey: { $0.key },
            rightKey: { $0.key })
        {
            switch diffElement {
            case .left(let prev):
                // Deletion
                diff.deleted.append(prev.element)
            case .common(let prev, let new):
                // Update
                if new.raw == prev.raw {
                    nextItems.append(prev)
                } else {
                    let newElement = updateElement(prev.element, new.raw)
                    diff.updated.append(newElement)
                    nextItems.append(Item(key: prev.key, raw: new.raw, element: newElement))
                }
            case .right(let new):
                // Insertion
                let element = makeElement(new.raw)
                diff.inserted.append(element)
                nextItems.append(Item(key: new.key, raw: new.raw, element: element))
            }
        }
        
        if diff.isEmpty {
            return nil
        } else {
            return diff
        }
    }
}
