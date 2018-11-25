import GRDB

extension ValueObservation where Reducer == Void {
    public func trackingSetDifferences<Request>(
        in request: Request,
        updateElement: @escaping (Request.RowDecoder, Row) -> Request.RowDecoder = { Request.RowDecoder(row: $1) })
        -> ValueObservation<SetDifferencesReducer<Request.RowDecoder>>
        where
        Request: FetchRequest,
        Request.RowDecoder: FetchableRecord & TableRecord
    {
        return setDifferencesObservation(
            in: request,
            key: request.primaryKey,
            makeElement: Request.RowDecoder.init(row:),
            updateElement: updateElement)
    }
}

// This function workarounds a compiler bug which prevents us to define it as a
// static method in an extension of ValueObservation.
private func setDifferencesObservation<Request>(
    in request: Request,
    key: @escaping (Database) throws -> (Row) -> RowValue,
    makeElement: @escaping (Row) -> Request.RowDecoder,
    updateElement: @escaping (Request.RowDecoder, Row) -> Request.RowDecoder)
    -> ValueObservation<SetDifferencesReducer<Request.RowDecoder>>
    where Request: FetchRequest
{
    return ValueObservation.tracking(request, reducer: { db in
        let key = try key(db)
        return SetDifferencesReducer<Request.RowDecoder>(
            fetch: { try Row.fetchAll($0, request) },
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
    private struct Item {
        let key: RowValue
        let row: Row
        let element: Element
    }
    
    private let _fetch: (Database) throws -> [Row]
    private let key: (Row) -> RowValue
    private let makeElement: (Row) -> Element
    private let updateElement: (Element, Row) -> Element
    private var previousItems: [Item] = []
    
    fileprivate init(
        fetch: @escaping (Database) throws -> [Row],
        key: @escaping (Row) -> RowValue,
        makeElement: @escaping (Row) -> Element,
        updateElement: @escaping (Element, Row) -> Element)
    {
        self._fetch = fetch
        self.key = key
        self.makeElement = makeElement
        self.updateElement = updateElement
    }
    
    /// :nodoc:
    public func fetch(_ db: Database) throws -> [Row] {
        return try _fetch(db)
    }
    
    /// :nodoc:
    public mutating func value(_ rows: [Row]) -> SetDifferences<Element>? {
        var diff = SetDifferences<Element>(inserted: [], updated: [], deleted: [])
        var nextItems: [Item] = []
        defer { self.previousItems = nextItems }
        
        for diffElement in DiffSequence(
            left: previousItems,
            right: rows.map { (key: key($0), row: $0) },
            leftKey: { $0.key },
            rightKey: { $0.key })
        {
            switch diffElement {
            case .left(let prev):
                // Deletion
                diff.deleted.append(prev.element)
            case .common(let prev, let new):
                // Update
                if new.row == prev.row {
                    nextItems.append(prev)
                } else {
                    let newRecord = updateElement(prev.element, new.row)
                    diff.updated.append(newRecord)
                    nextItems.append(Item(key: prev.key, row: new.row, element: newRecord))
                }
            case .right(let new):
                // Insertion
                let record = makeElement(new.row)
                diff.inserted.append(record)
                nextItems.append(Item(key: new.key, row: new.row, element: record))
            }
        }
        
        if diff.isEmpty {
            return nil
        } else {
            return diff
        }
    }
}
