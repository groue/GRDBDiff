import GRDB

public protocol _RequestValueReducer {
    associatedtype _Request: FetchRequest
    var request: _Request { get }
}

extension FetchableRecordsReducer: _RequestValueReducer { }
extension RowsReducer: _RequestValueReducer { }

extension ValueObservation where
    Reducer: _RequestValueReducer,
    Reducer._Request.RowDecoder: FetchableRecord & TableRecord
{
    func setDifferencesFromRows(
        updateElementFromRow: @escaping (Reducer._Request.RowDecoder, Row) -> Reducer._Request.RowDecoder = { Reducer._Request.RowDecoder(row: $1) })
        -> ValueObservation<RecordSetDifferencesReducer<Reducer>>
    {
        return mapReducer { db, reducer in
            try RecordSetDifferencesReducer(
                reducer: reducer,
                key: reducer.request.primaryKey(db),
                initialElements: [], // TODO: use
                updateElement: updateElementFromRow)
        }
    }
}

public struct RecordSetDifferencesReducer<Reducer>: ValueReducer where
    Reducer: _RequestValueReducer,
    Reducer._Request.RowDecoder: FetchableRecord & TableRecord
{
    var reducer: Reducer
    var differenciator: RecordSetDifferenciator<Reducer._Request.RowDecoder>
    
    fileprivate init(
        reducer: Reducer,
        key: @escaping (Row) -> RowValue,
        initialElements: [(Row, Reducer._Request.RowDecoder)],
        updateElement: @escaping (Reducer._Request.RowDecoder, Row) -> Reducer._Request.RowDecoder)
    {
        self.reducer = reducer
        self.differenciator = RecordSetDifferenciator(
            key: key,
            initialElements: initialElements,
            updateElement: updateElement)
    }
    
    /// :nodoc:
    public func fetch(_ db: Database) throws -> [Row] {
        return try Row.fetchAll(db, reducer.request)
    }
    
    /// :nodoc:
    public mutating func value(_ rows: [Row]) -> SetDifferences<Reducer._Request.RowDecoder>? {
        let diff = differenciator.diff(rows)
        if diff.isEmpty {
            return nil
        } else {
            return diff
        }
    }
}
