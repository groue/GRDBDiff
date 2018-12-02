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
        -> ValueObservation<SetDiffReducer<Reducer>>
    {
        return mapReducer { db, reducer in
            SetDiffReducer(
                reducer: reducer,
                initialElements: initialElements,
                updateElement: updateElement)
        }
    }
}

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
        initialElements: [Reducer.Value.Element],
        updateElement: @escaping (Reducer.Value.Element, Reducer.Value.Element) -> Reducer.Value.Element)
    {
        self.reducer = reducer
        self.differ = SetDiffer<Reducer.Value.Element>(updateElement: updateElement)
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
