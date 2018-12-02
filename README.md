:construction: IN DEVELOPMENT - DON'T USE IN PRODUCTION :construction:

GRDBDiff
========

### Various diff algorithms for SQLite, based on [GRDB].

Since it is possible to [track database changes](https://github.com/groue/GRDB.swift/blob/master/README.md#valueobservation), it is a natural desire to compute diffs between two consecutive values.

**There are many diff algorithms**, which perform various kinds of comparisons. GRDBDiff ships with a few of them. Make sure you pick one that suits your needs.

- [Set Differences]


## Set Differences

What are the elements that were inserted, updated, deleted?

This is the question that **Set Differences** can answer.

Set Differences do not care about the ordering of elements. They are well suited, for example, for synchronizing the annotations in a map view with the content of the database.

On the other side, they can not animate the cells in a table view or a collection view.

You track Set Differences with one of those three methods:

- [ValueObservation.setDifferencesFromRequest(updateRecord:)]
- ValueObservation.setDifferencesFromRequest(initialRecords:updateRecord:)
- ValueObservation.setDifferences(initialElements:updateElement:)

Each one of them builds a [ValueObservation] which notifies `SetDiff` values whenever the database changes:

```swift
struct SetDiff<Element> {
    var inserted: [Element]
    var updated: [Element]
    var deleted: [Element]
}
```


### ValueObservation.setDifferencesFromRequest(updateRecord:)

#### Usage

```swift
// 1.
struct Place: FetchableRecord, TableRecord { ... }

// 2.
let request = Place.orderedByPrimaryKey()

// 3.
let placesObservation = ValueObservation.trackingAll(request)

// 4.
let diffObservation = placesObservation.setDifferencesFromRequest()

// 5.
let observer = diffObservation.start(in: dbQueue) { diff: SetDiff<Place> in
    print(diff.inserted) // [Place]
    print(diff.updated)  // [Place]
    print(diff.deleted)  // [Place]
}
```

1. Define a **[Record]** type that conforms to both [FetchableRecord] and [TableRecord] protocols.

    > FetchableRecord makes it possible to fetch places from the database.
    > TableRecord provides the database primary key for places, which allows to identity places, and decide if they were inserted, updated, or deleted.

2. Define a database [request] of the records you are interested in. Make sure the request is ordered by primary key. You'll get wrong results if the request is not properly ordered.

    > Ordering records by primary key provides an efficient O(N) computation of diffs.

3. Define a [ValueObservation] from the request, with the `ValueObservation.trackingAll` method.

4. Derive a Set Differences observation with the `setDifferencesFromRequest` method.

5. Start the observation and enjoy your diffs!


#### The `updateRecord` Parameter

By default, the records notified in the `diff.updated` array are newly created values.

When you need to customize handling of record updated, provide a `updateRecord` closure. Its first parameter is an old record. The second one is a new database row. And the result is the record that should be notified in `diff.updated`.

For example, this observation prints changes:

```swift
let diffObservation = placesObservation
    .setDifferencesFromRequest(updateRecord: { (place: Place, row: Row) in
        let newPlace = Place(row: row)
        print("changes: \(newPlace.databaseChanges(from: place))")
        return newPlace
    })
```

And this other one reuses record instances:

```swift
let diffObservation = placesObservation
    .setDifferencesFromRequest(updateRecord: { (place: Place, row: Row) in
        place.update(from: row)
        return place
    })
```


[GRDB]: https://github.com/groue/GRDB.swift
[Set Differences]: #set-differences
[Record]: https://github.com/groue/GRDB.swift/blob/master/README.md#records
[FetchableRecord]: https://github.com/groue/GRDB.swift/blob/master/README.md#fetchablerecord-protocol
[TableRecord]: https://github.com/groue/GRDB.swift/blob/master/README.md#tablerecord-protocol
[request]: https://github.com/groue/GRDB.swift/blob/master/README.md#requests
[ValueObservation]: https://github.com/groue/GRDB.swift/blob/master/README.md#valueobservation
[ValueObservation.setDifferencesFromRequest(updateRecord:)]: #valueobservationsetdifferencesfromrequestupdaterecord
