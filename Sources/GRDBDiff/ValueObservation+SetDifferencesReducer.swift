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
            primaryKey: { try request.primaryKey($0) },
            makeElement: Request.RowDecoder.init(row:),
            updateElement: updateElement)
    }
}

// This function workarounds a compiler bug
private func setDifferencesObservation<Request>(
    in request: Request,
    primaryKey: @escaping (Database) throws -> (Row) -> [DatabaseValue],
    makeElement: @escaping (Row) -> Request.RowDecoder,
    updateElement: @escaping (Request.RowDecoder, Row) -> Request.RowDecoder)
    -> ValueObservation<SetDifferencesReducer<Request.RowDecoder>>
    where Request: FetchRequest
{
    let request = AnyFetchRequest<Row>(request)
    return ValueObservation.tracking(request, reducer: { db in
        let primaryKeyValues = try primaryKey(db)
        return SetDifferencesReducer<Request.RowDecoder>(
            fetch: request.fetchAll,
            primaryKey: { RowValue(dbValues: primaryKeyValues($0)) },
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
        let primaryKey: RowValue
        let row: Row
        let element: Element
    }
    
    private let primaryKey: (Row) -> RowValue
    private let _fetch: (Database) throws -> [Row]
    private let makeElement: (Row) -> Element
    private let updateElement: (Element, Row) -> Element
    private var previousItems: [Item]
    
    fileprivate init(
        fetch: @escaping (Database) throws -> [Row],
        primaryKey: @escaping (Row) -> RowValue,
        makeElement: @escaping (Row) -> Element,
        updateElement: @escaping (Element, Row) -> Element)
    {
        self.primaryKey = primaryKey
        self._fetch = fetch
        self.makeElement = makeElement
        self.updateElement = updateElement
        self.previousItems = []
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
            right: rows.map { (primaryKey: primaryKey($0), row: $0) },
            leftKey: { $0.primaryKey },
            rightKey: { $0.primaryKey })
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
                    nextItems.append(Item(primaryKey: prev.primaryKey, row: new.row, element: newRecord))
                }
            case .right(let new):
                // Insertion
                let record = makeElement(new.row)
                diff.inserted.append(record)
                nextItems.append(Item(primaryKey: new.primaryKey, row: new.row, element: record))
            }
        }
        
        if diff.isEmpty {
            return nil
        } else {
            return diff
        }
    }
}
