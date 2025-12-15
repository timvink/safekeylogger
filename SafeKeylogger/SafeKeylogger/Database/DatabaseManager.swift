import Foundation
import GRDB

final class DatabaseManager {
    static let shared = DatabaseManager()

    private var dbQueue: DatabaseQueue?
    private let queue = DispatchQueue(label: "com.safekeylogger.database", qos: .userInitiated)

    var databasePath: String {
        get {
            UserDefaults.standard.string(forKey: "databasePath") ?? defaultDatabasePath
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "databasePath")
            // Reconnect to new database
            queue.async { [weak self] in
                try? self?.connect()
            }
        }
    }

    var defaultDatabasePath: String {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(homeDir)/.safekeylogger/keystrokes.db"
    }

    private init() {
        queue.async { [weak self] in
            try? self?.connect()
        }
    }

    private func connect() throws {
        let path = databasePath
        let directory = (path as NSString).deletingLastPathComponent

        // Create directory if needed
        try FileManager.default.createDirectory(
            atPath: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        dbQueue = try DatabaseQueue(path: path)
        try createTables()
    }

    private func createTables() throws {
        try dbQueue?.write { db in
            // Characters table
            try db.create(table: "characters", ifNotExists: true) { t in
                t.column("char", .text).primaryKey()
                t.column("count", .integer).notNull().defaults(to: 1)
            }

            // Bigrams table
            try db.create(table: "bigrams", ifNotExists: true) { t in
                t.column("bigram", .text).primaryKey()
                t.column("count", .integer).notNull().defaults(to: 1)
            }

            // Trigrams table
            try db.create(table: "trigrams", ifNotExists: true) { t in
                t.column("trigram", .text).primaryKey()
                t.column("count", .integer).notNull().defaults(to: 1)
            }
        }
    }

    // MARK: - Write Operations (immediate, synchronous on background queue)

    func recordCharacter(_ char: String) {
        queue.async { [weak self] in
            try? self?.dbQueue?.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO characters (char, count) VALUES (?, 1)
                        ON CONFLICT(char) DO UPDATE SET count = count + 1
                        """,
                    arguments: [char]
                )
            }
        }
    }

    func recordBigram(_ bigram: String) {
        queue.async { [weak self] in
            try? self?.dbQueue?.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO bigrams (bigram, count) VALUES (?, 1)
                        ON CONFLICT(bigram) DO UPDATE SET count = count + 1
                        """,
                    arguments: [bigram]
                )
            }
        }
    }

    func recordTrigram(_ trigram: String) {
        queue.async { [weak self] in
            try? self?.dbQueue?.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO trigrams (trigram, count) VALUES (?, 1)
                        ON CONFLICT(trigram) DO UPDATE SET count = count + 1
                        """,
                    arguments: [trigram]
                )
            }
        }
    }

    // MARK: - Read Operations

    func topCharacters(limit: Int = 10) -> [CharacterCount] {
        do {
            return try dbQueue?.read { db in
                try CharacterCount
                    .order(CharacterCount.Columns.count.desc)
                    .limit(limit)
                    .fetchAll(db)
            } ?? []
        } catch {
            return []
        }
    }

    func topBigrams(limit: Int = 10) -> [BigramCount] {
        do {
            return try dbQueue?.read { db in
                try BigramCount
                    .order(BigramCount.Columns.count.desc)
                    .limit(limit)
                    .fetchAll(db)
            } ?? []
        } catch {
            return []
        }
    }

    func topTrigrams(limit: Int = 10) -> [TrigramCount] {
        do {
            return try dbQueue?.read { db in
                try TrigramCount
                    .order(TrigramCount.Columns.count.desc)
                    .limit(limit)
                    .fetchAll(db)
            } ?? []
        } catch {
            return []
        }
    }

    func totalCharacterCount() -> Int {
        do {
            return try dbQueue?.read { db in
                try Int.fetchOne(db, sql: "SELECT SUM(count) FROM characters") ?? 0
            } ?? 0
        } catch {
            return 0
        }
    }

    // MARK: - Clear Statistics

    func clearAllStatistics() {
        queue.async { [weak self] in
            try? self?.dbQueue?.write { db in
                try db.execute(sql: "DELETE FROM characters")
                try db.execute(sql: "DELETE FROM bigrams")
                try db.execute(sql: "DELETE FROM trigrams")
            }
        }
    }
}
