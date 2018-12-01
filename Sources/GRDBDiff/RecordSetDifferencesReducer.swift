import GRDB

extension ValueObservation where Reducer == Void {
    static func setDifferences<Request>(
        in request: Request,
        updateElement: @escaping (Request.RowDecoder, Row) -> Request.RowDecoder = { Request.RowDecoder(row: $1) })
        -> ValueObservation<RecordSetDifferencesReducer<Request.RowDecoder>>
        where
        Request: FetchRequest,
        Request.RowDecoder: FetchableRecord & TableRecord
    {
        return setDifferencesObservation(
            in: request,
            updateElement: updateElement)
    }
}

/// Support for ValueObservation<Void>.setDifferences(in:updateElement:)
///
/// This function workarounds a compiler bug which prevents us to define it as a
/// static method in an extension of ValueObservation.
private func setDifferencesObservation<Request>(
    in request: Request,
    updateElement: @escaping (Request.RowDecoder, Row) -> Request.RowDecoder)
    -> ValueObservation<RecordSetDifferencesReducer<Request.RowDecoder>>
    where
    Request: FetchRequest,
    Request.RowDecoder: FetchableRecord & TableRecord
{
    return ValueObservation.tracking(request, reducer: { db in
        try RecordSetDifferencesReducer(
            fetch: { try Row.fetchAll($0, request) },
            key: request.primaryKey(db),
            initialElements: [],
            updateElement: updateElement)
    })
}

public struct RecordSetDifferencesReducer<Record>: ValueReducer where Record: FetchableRecord {
    private let _fetch: (Database) throws -> [Row]
    private var _reducer: RecordSetDifferenciator<Record>
    
    fileprivate init(
        fetch: @escaping (Database) throws -> [Row],
        key: @escaping (Row) -> RowValue,
        initialElements: [(Row, Record)],
        updateElement: @escaping (Record, Row) -> Record)
    {
        self._fetch = fetch
        
        // Create a RowSetDifferenciator where:
        // - Element: Element
        // - Raw: Row
        // - Key: RowValue
        self._reducer = RecordSetDifferenciator(
            key: key,
            initialElements: initialElements,
            updateElement: updateElement)
    }
    
    /// :nodoc:
    public func fetch(_ db: Database) throws -> [Row] {
        return try _fetch(db)
    }
    
    /// :nodoc:
    public mutating func value(_ rows: [Row]) -> SetDifferences<Record>? {
        let diff = _reducer.diff(rows)
        if diff.isEmpty {
            return nil
        } else {
            return diff
        }
    }
}
