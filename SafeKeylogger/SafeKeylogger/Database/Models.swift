import Foundation
import GRDB

// MARK: - Database Records

struct CharacterCount: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "characters"

    var char: String
    var count: Int

    enum Columns {
        static let char = Column(CodingKeys.char)
        static let count = Column(CodingKeys.count)
    }
}

struct BigramCount: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "bigrams"

    var bigram: String
    var count: Int

    enum Columns {
        static let bigram = Column(CodingKeys.bigram)
        static let count = Column(CodingKeys.count)
    }
}

struct TrigramCount: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "trigrams"

    var trigram: String
    var count: Int

    enum Columns {
        static let trigram = Column(CodingKeys.trigram)
        static let count = Column(CodingKeys.count)
    }
}
