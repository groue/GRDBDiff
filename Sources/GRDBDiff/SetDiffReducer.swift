import GRDB

public protocol _RequestValueReducer {
    associatedtype _Request: FetchRequest
    var request: _Request { get }
}

extension FetchableRecordsReducer: _RequestValueReducer { }

extension ValueObservation where
    Reducer: ValueReducer,
    Reducer.Value: Sequence,
    Reducer.Value.Element: Equatable & Identifiable,
    Reducer.Value.Element.Identity: Comparable
{
    public func setDifferences(
        startingFrom initialElements: [Reducer.Value.Element] = [],
        onUpdate onUpdate: @escaping (Reducer.Value.Element, Reducer.Value.Element) -> Reducer.Value.Element = { $1 })
        -> ValueObservation<SetDiffReducer<Reducer>>
    {
        return mapReducer { db, reducer in
            SetDiffReducer(
                reducer: reducer,
                startingFrom: initialElements,
                onUpdate: onUpdate)
        }
    }
}

extension ValueObservation where
    Reducer: ValueReducer & _RequestValueReducer,
    Reducer.Value: Sequence,
    Reducer._Request.RowDecoder: FetchableRecord & TableRecord
{
    public func setDifferencesFromRequest(
        onUpdate: @escaping (Reducer._Request.RowDecoder, Row) -> Reducer._Request.RowDecoder = { Reducer._Request.RowDecoder(row: $1) })
        -> ValueObservation<RequestSetDiffReducer<Reducer>>
    {
        return mapReducer { db, reducer in
            let databaseTableName = Reducer._Request.RowDecoder.databaseTableName
            let primaryKeyColumns = try db.primaryKey(databaseTableName).columns
            return RequestSetDiffReducer(
                reducer: reducer,
                identityColumns: primaryKeyColumns,
                onUpdate: onUpdate)
        }
    }
}

extension ValueObservation where
    Reducer: ValueReducer & _RequestValueReducer,
    Reducer.Value: Sequence,
    Reducer._Request.RowDecoder: FetchableRecord & MutablePersistableRecord
{
    public func setDifferencesFromRequest(
        startingFrom initialRecords: [Reducer._Request.RowDecoder], // TODO: test
        onUpdate: @escaping (Reducer._Request.RowDecoder, Row) -> Reducer._Request.RowDecoder = { Reducer._Request.RowDecoder(row: $1) })
        -> ValueObservation<RequestSetDiffReducer<Reducer>>
    {
        return mapReducer { db, reducer in
            let databaseTableName = Reducer._Request.RowDecoder.databaseTableName
            let primaryKeyColumns = try db.primaryKey(databaseTableName).columns
            return RequestSetDiffReducer(
                reducer: reducer,
                identityColumns: primaryKeyColumns,
                startingFrom: initialRecords,
                onUpdate: onUpdate)
        }
    }
}

/// :nodoc:
public struct SetDiffReducer<Reducer>: ValueReducer where
    Reducer: ValueReducer,
    Reducer.Value: Sequence,
    Reducer.Value.Element: Equatable & Identifiable,
    Reducer.Value.Element.Identity: Comparable
{
    private var reducer: Reducer
    private var differ: SetDiffer<Reducer.Value.Element>
    
    init(
        reducer: Reducer,
        startingFrom initialElements: [Reducer.Value.Element],
        onUpdate: @escaping (Reducer.Value.Element, Reducer.Value.Element) -> Reducer.Value.Element)
    {
        self.reducer = reducer
        self.differ = SetDiffer<Reducer.Value.Element>(onUpdate: onUpdate)
        _ = differ.diff(initialElements)
    }
    
    public func fetch(_ db: Database) throws -> Reducer.Fetched {
        return try reducer.fetch(db)
    }
    
    public mutating func value(_ fetched: Reducer.Fetched) -> SetDiff<Reducer.Value.Element>? {
        guard let elements = reducer.value(fetched) else {
            return nil
        }
        let diff = differ.diff(elements)
        if diff.isEmpty {
            return nil
        } else {
            return diff
        }
    }
}

/// :nodoc:
public struct RequestSetDiffReducer<Reducer>: ValueReducer where
    Reducer: ValueReducer & _RequestValueReducer,
    Reducer.Value: Sequence,
    Reducer._Request.RowDecoder: FetchableRecord & TableRecord
{
    private class Item: Identifiable, Equatable {
        var identity: RowValue
        var row: Row
        lazy var element: Reducer._Request.RowDecoder = { Reducer._Request.RowDecoder(row: row) }()
        
        init(identity: RowValue, row: Row, element: Reducer._Request.RowDecoder? = nil) {
            self.identity = identity
            self.row = row
            if let element = element {
                self.element = element
            }
        }
        
        static func == (lhs: Item, rhs: Item) -> Bool {
            // Ignore ordering of columns when comparing rows, because
            // initialItems have no way to reproduce the row they were
            // built from.
            //
            // This row comparison is only valid because diffed records adopt
            // TableRecord: we are not dealing with compound records build from
            // hierarchical row scopes, here.
            return lhs.row.hasSameColumnsAndValues(rhs.row)
        }
    }
    
    private var reducer: Reducer
    private var differ: SetDiffer<Item>
    private let identityColumns: [String]
    
    private init(
        reducer: Reducer,
        identityColumns: [String],
        initialItems: [Item],
        onUpdate: @escaping (Reducer._Request.RowDecoder, Row) -> Reducer._Request.RowDecoder)
    {
        self.reducer = reducer
        self.identityColumns = identityColumns
        self.differ = SetDiffer(onUpdate: { oldItem, newItem in
            newItem.element = onUpdate(oldItem.element, newItem.row)
            return newItem
        })
        _ = differ.diff(initialItems)
    }
    
    fileprivate init(
        reducer: Reducer,
        identityColumns: [String],
        onUpdate: @escaping (Reducer._Request.RowDecoder, Row) -> Reducer._Request.RowDecoder)
    {
        self.init(
            reducer: reducer,
            identityColumns: identityColumns,
            initialItems: [],
            onUpdate: onUpdate)
    }
    
    public func fetch(_ db: Database) throws -> [Row] {
        return try Row.fetchAll(db, reducer.request)
    }
    
    public mutating func value(_ rows: [Row]) -> SetDiff<Reducer._Request.RowDecoder>? {
        let items: [Item] = rows.map { row in
            let identity = RowValue(dbValues: identityColumns.map { row[$0] })
            return Item(identity: identity, row: row)
        }
        let diff = differ.diff(items)
        if diff.isEmpty {
            return nil
        } else {
            return SetDiff(
                inserted: diff.inserted.map { $0.element },
                updated: diff.updated.map { $0.element },
                deleted: diff.deleted.map { $0.element })
        }
    }
}

extension RequestSetDiffReducer where Reducer._Request.RowDecoder: MutablePersistableRecord {
    fileprivate init(
        reducer: Reducer,
        identityColumns: [String],
        startingFrom initialElements: [Reducer._Request.RowDecoder],
        onUpdate: @escaping (Reducer._Request.RowDecoder, Row) -> Reducer._Request.RowDecoder)
    {
        let initialItems: [Item] = initialElements.map { element in
            let row = Row(element.databaseDictionary)
            let identity = RowValue(dbValues: identityColumns.map { row[$0] })
            return Item(identity: identity, row: row, element: element)
        }
        self.init(
            reducer: reducer,
            identityColumns: identityColumns,
            initialItems: initialItems,
            onUpdate: onUpdate)
    }
}

extension Row {
    /// True if other row has the same columns and values.
    /// Order of columns is irrelevant.
    /// Row scopes are ignored.
    func hasSameColumnsAndValues(_ other: Row) -> Bool {
        if count != other.count {
            return false
        }
        for (column, dbValue) in self {
            if other.hasColumn(column) == false {
                return false
            }
            if other[column] != dbValue {
                return false
            }
        }
        return true
    }
}
