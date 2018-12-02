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

You can track Set Differences with one of those three methods:

- ValueObservation.setDifferencesFromRequest(updateElement:)
- ValueObservation.setDifferencesFromRequest(initialElements:updateElement:)
- ValueObservation.setDifferences(initialElements:updateElement:)


#### ValueObservation.setDifferencesFromRequest(updateElement:)

Usage:

```swift
// 1.
struct Place: FetchableRecord, TableRecord { ... }

// 2.
let request = Place.orderedByPrimaryKey()

// 3.
let elementsObservation = ValueObservation.trackingAll(request)

// 4.
let diffObservation = elementsObservation.setDifferencesFromRequest()

// 5.
let observer = diffObservation.start(in: dbQueue) { diff: SetDiff<Place> in
    print(diff.inserted) // [Place]
    print(diff.updated)  // [Place]
    print(diff.deleted)  // [Place]
}
```




[GRDB]: https://github.com/groue/GRDB.swift
[Set Differences]: #set-differences
