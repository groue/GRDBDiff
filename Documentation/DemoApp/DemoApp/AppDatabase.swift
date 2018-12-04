import GRDB
import CoreLocation

/// A type responsible for initializing the application database, and performing
/// database changes.
///
/// See AppDelegate.setupDatabase()
enum AppDatabase {
    
    // MARK: - Database Definition
    
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
        
        #if DEBUG
        // Speed up development by nuking the database when migrations change
        //
        // See https://github.com/groue/GRDB.swift/blob/master/README.md#the-erasedatabaseonschemachange-option
        migrator.eraseDatabaseOnSchemaChange = true
        #endif
        
        migrator.registerMigration("v1.0") { db in
            // Create database tables
            // See https://github.com/groue/GRDB.swift#create-tables
            
            try db.create(table: "place") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("latitude", .double).notNull()
                t.column("longitude", .double).notNull()
                t.column("isFavorite", .boolean).notNull()
            }
            
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull().collate(.localizedCaseInsensitiveCompare)
                t.column("score", .integer).notNull()
            }
        }
        
        migrator.registerMigration("fixtures") { db in
            // Populate tables with random data
            for _ in 0..<5 {
                var place = Place.random()
                try place.insert(db)
            }
            for _ in 0..<10 {
                var player = Player.random()
                try player.insert(db)
            }
        }
        
//        // Migrations for future application versions will be inserted here:
//        migrator.registerMigration(...) { db in
//            ...
//        }
        
        return migrator
    }
    
    // MARK: - Place Modifications
    
    static func deletePlaces() throws {
        try dbPool.write { db in
            _ = try Place.deleteAll(db)
        }
    }
    
    static func refreshPlaces() throws {
        try dbPool.write { db in
            if try Place.fetchCount(db) == 0 {
                // Insert places
                for _ in 0..<5 {
                    var place = Place.random()
                    try place.insert(db)
                }
            } else {
                // Insert a place
                if Bool.random() {
                    var place = Place.random()
                    try place.insert(db)
                }
                // Delete a random place
                if Bool.random() {
                    try Place.order(sql: "RANDOM()").limit(1).deleteAll(db)
                }
                // Update some places
                for var place in try Place.fetchAll(db) where Bool.random() {
                    place.coordinate = CLLocationCoordinate2D.random(withinDistance: 300, from: place.coordinate)
                    place.isFavorite = Bool.random()
                    try place.update(db)
                }
            }
        }
    }

    // MARK: - Player Modifications
    
    static func deletePlayers() throws {
        try dbPool.write { db in
            try Player.deleteAll(db)
        }
    }
    
    static func refreshPlayers() throws {
        try dbPool.write { db in
            if try Player.fetchCount(db) == 0 {
                // Insert players
                for _ in 0..<8 {
                    var player = Player.random()
                    try player.insert(db)
                }
            } else {
                // Insert a player
                if Bool.random() {
                    var player = Player.random()
                    try player.insert(db)
                }
                // Delete a random player
                if Bool.random() {
                    try Player.order(sql: "RANDOM()").limit(1).deleteAll(db)
                }
                // Update some players
                for var player in try Player.fetchAll(db) where Bool.random() {
                    player.score = Player.randomScore()
                    try player.update(db)
                }
            }
        }
    }
}
