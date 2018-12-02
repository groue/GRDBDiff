import GRDB

extension ValueObservation where
    Reducer: ValueReducer,
    Reducer.Value: Sequence,
    Reducer.Value.Element: Equatable & Identifiable,
    Reducer.Value.Element.Identity: Comparable
{
    public func setDifferences(
        initialElements: [Reducer.Value.Element] = [],
        updateElement: @escaping (Reducer.Value.Element, Reducer.Value.Element) -> Reducer.Value.Element = { $1 })
        -> ValueObservation<IdentifiableSetDifferencesReducer<Reducer>>
    {
        return mapReducer { db, reducer in
            IdentifiableSetDifferencesReducer(
                reducer: reducer,
                initialElements: initialElements,
                updateElement: updateElement)
        }
    }
}

public struct IdentifiableSetDifferencesReducer<Reducer>: ValueReducer where
    Reducer: ValueReducer,
    Reducer.Value: Sequence,
    Reducer.Value.Element: Equatable & Identifiable,
    Reducer.Value.Element.Identity: Comparable
{
    private var reducer: Reducer
    private var differ: IdentifiableSetDiffer<Reducer.Value.Element>
    
    init(
        reducer: Reducer,
        initialElements: [Reducer.Value.Element],
        updateElement: @escaping (Reducer.Value.Element, Reducer.Value.Element) -> Reducer.Value.Element)
    {
        self.reducer = reducer
        self.differ = IdentifiableSetDiffer<Reducer.Value.Element>(updateElement: updateElement)
        _ = differ.diff(initialElements)
    }
    
    public func fetch(_ db: Database) throws -> Reducer.Fetched {
        return try reducer.fetch(db)
    }
    
    public mutating func value(_ fetched: Reducer.Fetched) -> SetDifferences<Reducer.Value.Element>? {
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
