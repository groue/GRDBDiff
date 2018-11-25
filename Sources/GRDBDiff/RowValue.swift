import GRDB

/// A "row value" https://www.sqlite.org/rowvalue.html
///
/// WARNING: the Comparable conformance does not handle database collations.
/// FIXME: collation is available through https://www.sqlite.org/c3ref/table_column_metadata.html
struct RowValue {
    let dbValues: [DatabaseValue]
}

extension RowValue : Comparable {
    static func < (lhs: RowValue, rhs: RowValue) -> Bool {
        return lhs.dbValues.lexicographicallyPrecedes(rhs.dbValues, by: <)
    }
    
    static func == (lhs: RowValue, rhs: RowValue) -> Bool {
        return lhs.dbValues == rhs.dbValues
    }
}

/// Compares DatabaseValue like SQLite
///
/// WARNING: this comparison does not handle database collations.
func < (lhs: DatabaseValue, rhs: DatabaseValue) -> Bool {
    switch (lhs.storage, rhs.storage) {
    case (.int64(let lhs), .int64(let rhs)):
        return lhs < rhs
    case (.double(let lhs), .double(let rhs)):
        return lhs < rhs
    case (.int64(let lhs), .double(let rhs)):
        return Double(lhs) < rhs
    case (.double(let lhs), .int64(let rhs)):
        return lhs < Double(rhs)
    case (.string(let lhs), .string(let rhs)):
        return lhs.utf8.lexicographicallyPrecedes(rhs.utf8)
    case (.blob(let lhs), .blob(let rhs)):
        return lhs.lexicographicallyPrecedes(rhs, by: <)
    case (.blob, _):
        return false
    case (_, .blob):
        return true
    case (.string, _):
        return false
    case (_, .string):
        return true
    case (.int64, _), (.double, _):
        return false
    case (_, .int64), (_, .double):
        return true
    case (.null, _):
        return false
    case (_, .null):
        return true
    }
}
