import GRDB

extension ValueObservation where Reducer == Void {
    static func setDifferences<Request>(
        in request: Request,
        updateElement: @escaping (Request.RowDecoder, Row) -> Request.RowDecoder = { Request.RowDecoder(row: $1) })
        -> ValueObservation<RowsSetDifferencesReducer<Request.RowDecoder>>
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
    -> ValueObservation<RowsSetDifferencesReducer<Request.RowDecoder>>
    where
    Request: FetchRequest,
    Request.RowDecoder: FetchableRecord & TableRecord
{
    return ValueObservation.tracking(request, reducer: { db in
        try RowsSetDifferencesReducer(
            fetch: { try Row.fetchAll($0, request) },
            key: request.primaryKey(db),
            initialElements: [],
            makeElement: Request.RowDecoder.init(row:),
            updateElement: updateElement)
    })
}

public struct RowsSetDifferencesReducer<Element>: ValueReducer {
    private let _fetch: (Database) throws -> [Row]
    private var _reducer: RowsSetDifferenciator<Element, Row, RowValue>
    
    fileprivate init(
        fetch: @escaping (Database) throws -> [Row],
        key: @escaping (Row) -> RowValue,
        initialElements: [(Row, Element)],
        makeElement: @escaping (Row) -> Element,
        updateElement: @escaping (Element, Row) -> Element)
    {
        self._fetch = fetch
        
        // Create a RowSetDifferenciator where:
        // - Element: Element
        // - Raw: Row
        // - Key: RowValue
        self._reducer = RowsSetDifferenciator(
            key: key,
            initialElements: initialElements,
            makeElement: makeElement,
            updateElement: updateElement)
    }
    
    /// :nodoc:
    public func fetch(_ db: Database) throws -> [Row] {
        return try _fetch(db)
    }
    
    /// :nodoc:
    public mutating func value(_ rows: [Row]) -> SetDifferences<Element>? {
        let diff = _reducer.diff(rows)
        if diff.isEmpty {
            return nil
        } else {
            return diff
        }
    }
}
