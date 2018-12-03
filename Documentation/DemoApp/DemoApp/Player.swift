import GRDB

/// A player
struct Player: Codable {
    var id: Int64?
    var name: String
    var score: Int
    
    /// Customize coding keys so that they can be used as GRDB columns
    enum CodingKeys: String, CodingKey, ColumnExpression {
        case id, name, score
    }
}

/// Adopt Equatable so that we can leverage the Differ algorithm.
extension Player: Equatable { }

/// Adopt RowConvertible so that we can fetch players from the database.
/// Implementation is fully derived from Codable adoption.
extension Player: FetchableRecord { }

/// Adopt MutablePersistable so that we can create/update/delete players
/// in the database. Implementation is partially derived from Codable adoption.
extension Player: MutablePersistableRecord {
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

extension Player {
    /// A request that sorts players by name.
    static func orderedByName() -> QueryInterfaceRequest<Player> {
        return Player.order(CodingKeys.name, CodingKeys.score.desc)
    }
    
    /// A request that sorts players by score.
    static func orderedByScore() -> QueryInterfaceRequest<Player> {
        return Player.order(CodingKeys.score.desc, CodingKeys.name)
    }
}

extension Player {
    private static let names = ["Arthur", "Anita", "Barbara", "Bernard", "Craig", "Chiara", "David", "Dean", "Éric", "Elena", "Fatima", "Frederik", "Gilbert", "Georgette", "Henriette", "Hassan", "Ignacio", "Irene", "Julie", "Jack", "Karl", "Kristel", "Louis", "Liz", "Masashi", "Mary", "Noam", "Nicole", "Ophelie", "Oleg", "Pascal", "Patricia", "Quentin", "Quinn", "Raoul", "Rachel", "Stephan", "Susie", "Tristan", "Tatiana", "Ursule", "Urbain", "Victor", "Violette", "Wilfried", "Wilhelmina", "Yvon", "Yann", "Zazie", "Zoé"]
    
    /// Returns a random player
    static func random() -> Player {
        return Player(id: nil, name: names.randomElement()!, score: randomScore())
    }
    
    /// Returns a random score
    static func randomScore() -> Int {
        return 10 * Int.random(in: 0...100)
    }
}
