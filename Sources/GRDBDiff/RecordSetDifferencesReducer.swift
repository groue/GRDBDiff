import GRDB

public protocol _RequestValueReducer {
    associatedtype _Request: FetchRequest
    var request: _Request { get }
}

extension FetchableRecordsReducer: _RequestValueReducer { }
extension RowsReducer: _RequestValueReducer { } // TODO: test

extension ValueObservation where
    Reducer: _RequestValueReducer,
    Reducer._Request.RowDecoder: FetchableRecord & TableRecord
{
    public func setDifferencesFromRows(
        updateElementFromRow: @escaping (Reducer._Request.RowDecoder, Row) -> Reducer._Request.RowDecoder = { Reducer._Request.RowDecoder(row: $1) })
        -> ValueObservation<RecordSetDifferencesReducer<Reducer>>
    {
        return mapReducer { db, reducer in
            let databaseTableName = Reducer._Request.RowDecoder.databaseTableName
            let primaryKeyColumns = try db.primaryKey(databaseTableName).columns
            return RecordSetDifferencesReducer(
                reducer: reducer,
                identityColumns: primaryKeyColumns,
                updateElement: updateElementFromRow)
        }
    }
}

extension ValueObservation where
    Reducer: _RequestValueReducer,
    Reducer._Request.RowDecoder: FetchableRecord & MutablePersistableRecord
{
    public func setDifferencesFromRows(
        initialElements: [Reducer._Request.RowDecoder] = [], // TODO: test
        updateElementFromRow: @escaping (Reducer._Request.RowDecoder, Row) -> Reducer._Request.RowDecoder = { Reducer._Request.RowDecoder(row: $1) })
        -> ValueObservation<RecordSetDifferencesReducer<Reducer>>
    {
        return mapReducer { db, reducer in
            let databaseTableName = Reducer._Request.RowDecoder.databaseTableName
            let primaryKeyColumns = try db.primaryKey(databaseTableName).columns
            return RecordSetDifferencesReducer(
                reducer: reducer,
                identityColumns: primaryKeyColumns,
                initialElements: initialElements,
                updateElement: updateElementFromRow)
        }
    }
}

/// :nodoc:
public struct RecordSetDifferencesReducer<Reducer>: ValueReducer where
    Reducer: _RequestValueReducer,
    Reducer._Request.RowDecoder: FetchableRecord
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
            // FIXME: initial items may not have the same column ordering :-(
            return lhs.row == rhs.row
        }
    }
    
    private var reducer: Reducer
    private var differ: IdentifiableSetDiffer<Item>
    private let identityColumns: [String]

    private init(
        reducer: Reducer,
        identityColumns: [String],
        initialItems: [Item],
        updateElement: @escaping (Reducer._Request.RowDecoder, Row) -> Reducer._Request.RowDecoder)
    {
        self.reducer = reducer
        self.identityColumns = identityColumns
        self.differ = IdentifiableSetDiffer(updateElement: { oldItem, newItem in
            newItem.element = updateElement(oldItem.element, newItem.row)
            return newItem
        })
        _ = differ.diff(initialItems)
    }

    fileprivate init(
        reducer: Reducer,
        identityColumns: [String],
        updateElement: @escaping (Reducer._Request.RowDecoder, Row) -> Reducer._Request.RowDecoder)
    {
        self.init(
            reducer: reducer,
            identityColumns: identityColumns,
            initialItems: [],
            updateElement: updateElement)
    }

    public func fetch(_ db: Database) throws -> [Row] {
        return try Row.fetchAll(db, reducer.request)
    }
    
    public mutating func value(_ rows: [Row]) -> SetDifferences<Reducer._Request.RowDecoder>? {
        let items: [Item] = rows.map { row in
            let identity = RowValue(dbValues: identityColumns.map { row[$0] })
            return Item(identity: identity, row: row)
        }
        let diff = differ.diff(items)
        if diff.isEmpty {
            return nil
        } else {
            return SetDifferences(
                inserted: diff.inserted.map { $0.element },
                updated: diff.updated.map { $0.element },
                deleted: diff.deleted.map { $0.element })
        }
    }
}

extension RecordSetDifferencesReducer where Reducer._Request.RowDecoder: MutablePersistableRecord {
    fileprivate init(
        reducer: Reducer,
        identityColumns: [String],
        initialElements: [Reducer._Request.RowDecoder],
        updateElement: @escaping (Reducer._Request.RowDecoder, Row) -> Reducer._Request.RowDecoder)
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
            updateElement: updateElement)
    }
}
