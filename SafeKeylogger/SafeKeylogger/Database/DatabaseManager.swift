import Foundation
import GRDB

final class DatabaseManager {
    static let shared = DatabaseManager()

    private var dbQueue: DatabaseQueue?
    private let queue = DispatchQueue(label: "com.safekeylogger.database", qos: .userInitiated)
    private static let dayStringFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()

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

            // Hourly counts table
            try db.create(table: "hourly_counts", ifNotExists: true) { t in
                t.column("timestamp", .datetime).primaryKey()
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

    func recordHourlyCount() {
        queue.async { [weak self] in
            // Get start of current hour in UTC
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(abbreviation: "UTC")!
            let components = calendar.dateComponents([.year, .month, .day, .hour], from: Date())
            guard let startOfHour = calendar.date(from: components) else { return }

            try? self?.dbQueue?.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO hourly_counts (timestamp, count) VALUES (?, 1)
                        ON CONFLICT(timestamp) DO UPDATE SET count = count + 1
                        """,
                    arguments: [startOfHour]
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

    /// Returns keystroke counts per day for the last 7 days (in local timezone), ordered oldest to newest.
    func dailyCountsForLastWeek() -> [(date: Date, count: Int)] {
        do {
            return try dbQueue?.read { db in
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = .current
                let todayStart = calendar.startOfDay(for: Date())
                guard let weekAgo = calendar.date(byAdding: .day, value: -6, to: todayStart) else { return [] }

                // hourly_counts timestamps are stored in UTC.
                // We aggregate by local date using SQLite's localtime modifier.
                let rows = try Row.fetchAll(db, sql: """
                    SELECT date(timestamp, 'localtime') AS day, SUM(count) AS total
                    FROM hourly_counts
                    WHERE timestamp >= ?
                    GROUP BY day
                    ORDER BY day
                    """, arguments: [weekAgo])

                // Build lookup from query results
                var lookup: [String: Int] = [:]
                for row in rows {
                    if let day = row["day"] as? String, let total = row["total"] as? Int {
                        lookup[day] = total
                    }
                }

                // Build a full 7-day array, filling in zeros for missing days
                var result: [(date: Date, count: Int)] = []
                for offset in 0..<7 {
                    guard let day = calendar.date(byAdding: .day, value: offset, to: weekAgo) else { continue }
                    let dayString = Self.dayStringFormatter.string(from: day)
                    let count = lookup[dayString] ?? 0
                    result.append((date: day, count: count))
                }
                return result
            } ?? []
        } catch {
            return []
        }
    }

    // MARK: - Clear Statistics

    func clearAllStatistics() {
        queue.async { [weak self] in
            try? self?.dbQueue?.write { db in
                try db.execute(sql: "DELETE FROM characters")
                try db.execute(sql: "DELETE FROM bigrams")
                try db.execute(sql: "DELETE FROM trigrams")
                try db.execute(sql: "DELETE FROM hourly_counts")
            }
        }
    }
}
