import GRDB

extension FetchRequest where RowDecoder: TableRecord {
    /// Creates a function that extracts the primary key from a row
    ///
    ///     let request = Player.all()
    ///     let primaryKey = try request.primaryKey(db)
    ///     if let row = try Row.fetchOne(db, request) {
    ///         print(row) // <Row id:1, name:"arthur", score:1000>
    ///         primaryKey(row) // [1]
    ///     }
    func primaryKey(_ db: Database) throws -> (Row) -> [DatabaseValue] {
        // Extract primary key columns
        let columns = try db.primaryKey(RowDecoder.databaseTableName).columns
        
        // Turn column names into statement indexes
        let (statement, rowAdapter) = try prepare(db)
        let rowLayout: RowLayout = try rowAdapter?.layoutedAdapter(from: statement).mapping ?? statement
        let indexes = columns.map { column -> Int in
            guard let index = rowLayout.layoutIndex(ofColumn: column) else {
                fatalError("Primary key column \(String(reflecting: column)) is not selected")
            }
            return index
        }
        
        // Turn statement indexes into values
        return { row in indexes.map { row[$0] } }
    }
}
