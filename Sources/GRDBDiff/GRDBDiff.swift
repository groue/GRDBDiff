import GRDB

struct GRDBDiff {
    var sqliteVersion = try! DatabaseQueue().read {
        try String.fetchOne($0, "SELECT sqlite_version()")
    }
}
