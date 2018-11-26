import GRDB

extension ValueObservation where Reducer == Void {
    public func trackingSetDifferences<Request>(
        in request: Request,
        updateElement: @escaping (Request.RowDecoder, Row) -> Request.RowDecoder = { Request.RowDecoder(row: $1) })
        -> ValueObservation<SetDifferencesRowReducer<Request.RowDecoder>>
        where
        Request: FetchRequest,
        Request.RowDecoder: FetchableRecord & TableRecord
    {
        return makeValueObservationTrackingSetDifferences(
            in: request,
            updateElement: updateElement)
    }
    
    public func trackingSetDifferences<Element, Key>(
        in regions: [DatabaseRegionConvertible],
        fetch: @escaping (Database) throws -> [Element],
        key: @escaping (Element) -> Key,
        updateElement: @escaping (Element, Element) -> Element = { $1 })
        -> ValueObservation<SetDifferencesReducer<Element, Key>>
        where Element: Equatable, Key: Comparable
    {
        return makeValueObservationTrackingSetDifferences(
            in: regions,
            fetch: fetch,
            key: key,
            updateElement: updateElement)
    }
    
    public func trackingSetDifferences<Element, Key>(
        in regions: DatabaseRegionConvertible...,
        fetch: @escaping (Database) throws -> [Element],
        key: @escaping (Element) -> Key,
        updateElement: @escaping (Element, Element) -> Element = { $1 })
        -> ValueObservation<SetDifferencesReducer<Element, Key>>
        where Element: Equatable, Key: Comparable
    {
        return makeValueObservationTrackingSetDifferences(
            in: regions,
            fetch: fetch,
            key: key,
            updateElement: updateElement)
    }
}

// This function workarounds a compiler bug which prevents us to define it as a
// static method in an extension of ValueObservation.
private func makeValueObservationTrackingSetDifferences<Request>(
    in request: Request,
    updateElement: @escaping (Request.RowDecoder, Row) -> Request.RowDecoder)
    -> ValueObservation<SetDifferencesRowReducer<Request.RowDecoder>>
    where
    Request: FetchRequest,
    Request.RowDecoder: FetchableRecord & TableRecord
{
    return ValueObservation.tracking(request, reducer: { db in
        try SetDifferencesRowReducer(
            fetch: { try Row.fetchAll($0, request) },
            key: request.primaryKey(db),
            makeElement: Request.RowDecoder.init(row:),
            updateElement: updateElement)
    })
}

// This function workarounds a compiler bug which prevents us to define it as a
// static method in an extension of ValueObservation.
private func makeValueObservationTrackingSetDifferences<Element, Key>(
    in regions: [DatabaseRegionConvertible],
    fetch: @escaping (Database) throws -> [Element],
    key: @escaping (Element) -> Key,
    updateElement: @escaping (Element, Element) -> Element)
    -> ValueObservation<SetDifferencesReducer<Element, Key>>
    where Element: Equatable, Key: Comparable
{
    return ValueObservation.tracking(regions, reducer: { _ in
        SetDifferencesReducer(
            fetch: fetch,
            key: key,
            updateElement: updateElement)
    })
}

public struct SetDifferences<Element> {
    public var inserted: [Element]
    public var updated: [Element]
    public var deleted: [Element]
    
    // Internal for testability
    /* private */ var isEmpty: Bool {
        return inserted.isEmpty && updated.isEmpty && deleted.isEmpty
    }
}

public struct SetDifferencesRowReducer<Element>: ValueReducer {
    private let _fetch: (Database) throws -> [Row]
    private var _reducer: _SetDifferencesReducer<Element, Row, RowValue>
    
    fileprivate init(
        fetch: @escaping (Database) throws -> [Row],
        key: @escaping (Row) -> RowValue,
        makeElement: @escaping (Row) -> Element,
        updateElement: @escaping (Element, Row) -> Element)
    {
        self._fetch = fetch
        
        // Create a _SetDifferencesReducer where:
        // - Element: Element
        // - Raw: Row
        // - Key: RowValue
        self._reducer = _SetDifferencesReducer(key: key, makeElement: makeElement, updateElement: updateElement)
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

public struct SetDifferencesReducer<Element: Equatable, Key: Comparable>: ValueReducer {
    private let _fetch: (Database) throws -> [Element]
    private var _reducer: _SetDifferencesReducer<Element, Element, Key>
    
    fileprivate init(
        fetch: @escaping (Database) throws -> [Element],
        key: @escaping (Element) -> Key,
        updateElement: @escaping (Element, Element) -> Element)
    {
        self._fetch = fetch
        
        // Create a _SetDifferencesReducer where:
        // - Element: Element
        // - Raw: Element
        // - Key: Key
        self._reducer = _SetDifferencesReducer(key: key, makeElement: { $0 }, updateElement: updateElement)
    }
    
    /// :nodoc:
    public func fetch(_ db: Database) throws -> [Element] {
        return try _fetch(db)
    }
    
    /// :nodoc:
    public mutating func value(_ elements: [Element]) -> SetDifferences<Element>? {
        let diff = _reducer.diff(elements)
        if diff.isEmpty {
            return nil
        } else {
            return diff
        }
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
    private var oldItems: [Item] = []
    
    init(
        key: @escaping (Raw) -> Key,
        makeElement: @escaping (Raw) -> Element,
        updateElement: @escaping (Element, Raw) -> Element)
    {
        self.key = key
        self.makeElement = makeElement
        self.updateElement = updateElement
    }
    
    mutating func diff(_ raws: [Raw]) -> SetDifferences<Element> {
        var diff = SetDifferences<Element>(inserted: [], updated: [], deleted: [])
        var newItems: [Item] = []
        defer { self.oldItems = newItems }

        let diffElements = DiffSequence(
            old: oldItems,
            new: raws.map { (key: key($0), raw: $0) },
            oldKey: { $0.key },
            newKey: { $0.key })

        for diffElement in diffElements {
            switch diffElement {
            case .deleted(let old):
                diff.deleted.append(old.element)

            case .updated(let old, let new):
                if new.raw == old.raw {
                    // unchanged
                    newItems.append(old)
                } else {
                    let newElement = updateElement(old.element, new.raw)
                    diff.updated.append(newElement)
                    newItems.append(Item(key: old.key, raw: new.raw, element: newElement))
                }

            case .inserted(let new):
                let element = makeElement(new.raw)
                diff.inserted.append(element)
                newItems.append(Item(key: new.key, raw: new.raw, element: element))
            }
        }

        return diff
    }
}
