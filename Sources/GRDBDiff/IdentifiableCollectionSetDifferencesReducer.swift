import GRDB

extension ValueObservation where
    Reducer: ValueReducer,
    Reducer.Value: Collection,
    Reducer.Value.Element: Equatable & Identifiable,
    Reducer.Value.Element.Identity: Comparable
{
    public func setDifferences(
        initialElements: [Reducer.Value.Element] = [],
        updateElement: @escaping (Reducer.Value.Element, Reducer.Value.Element) -> Reducer.Value.Element = { $1 })
        -> ValueObservation<IdentifiableCollectionSetDifferencesReducer<Reducer>>
    {
        return mapReducer { db, reducer in
            IdentifiableCollectionSetDifferencesReducer(
                reducer: reducer,
                initialElements: initialElements,
                updateElement: updateElement)
        }
    }
}

public struct IdentifiableCollectionSetDifferencesReducer<Reducer>: ValueReducer where
    Reducer: ValueReducer,
    Reducer.Value: Collection,
    Reducer.Value.Element: Equatable & Identifiable,
    Reducer.Value.Element.Identity: Comparable
{
    var reducer: Reducer
    var diffReducer: IdentifiableCollectionSetDifferenciator<Reducer.Value.Element>
    
    init(reducer: Reducer,
         initialElements: [Reducer.Value.Element],
         updateElement: @escaping (Reducer.Value.Element, Reducer.Value.Element) -> Reducer.Value.Element)
    {
        self.reducer = reducer
        self.diffReducer = IdentifiableCollectionSetDifferenciator<Reducer.Value.Element>(
            initialElements: initialElements,
            updateElement: updateElement)
    }
    
    public func fetch(_ db: Database) throws -> Reducer.Fetched {
        return try reducer.fetch(db)
    }
    
    public mutating func value(_ fetched: Reducer.Fetched) -> SetDifferences<Reducer.Value.Element>? {
        guard let elements = reducer.value(fetched) else {
            return nil
        }
        let diff = diffReducer.diff(elements)
        if diff.isEmpty {
            return nil
        } else {
            return diff
        }
    }
}
