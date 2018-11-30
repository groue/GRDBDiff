import GRDB

/// A type responsible for initializing the application database.
///
/// See AppDelegate.setupDatabase()
struct AppDatabase {
    
    /// Creates a fully initialized database at path
    static func openDatabase(atPath path: String) throws -> DatabasePool {
        // Connect to the database
        // See https://github.com/groue/GRDB.swift/blob/master/README.md#database-connections
        let dbPool = try DatabasePool(path: path)
        
        // Define the database schema
        try migrator.migrate(dbPool)
        
        return dbPool
    }
    
    /// The DatabaseMigrator that defines the database schema.
    ///
    /// See https://github.com/groue/GRDB.swift/blob/master/README.md#migrations
    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        
        migrator.registerMigration("v1.0") { db in
            // Create a table
            // See https://github.com/groue/GRDB.swift#create-tables
            try db.create(table: "place") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("latitude", .double).notNull()
                t.column("longitude", .double).notNull()
            }
        }
        
        migrator.registerMigration("fixtures") { db in
            // Populate the places table with random data
            for _ in 0..<10 {
                var place = Place(id: nil, coordinate: Place.randomCoordinate())
                try place.insert(db)
            }
        }
        
//        // Migrations for future application versions will be inserted here:
//        migrator.registerMigration(...) { db in
//            ...
//        }
        
        return migrator
    }
}
