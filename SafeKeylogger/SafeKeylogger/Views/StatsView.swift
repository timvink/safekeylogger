import SwiftUI

struct StatsView: View {
    @State private var characters: [CharacterCount] = []
    @State private var bigrams: [BigramCount] = []
    @State private var trigrams: [TrigramCount] = []
    @State private var totalKeystrokes: Int = 0

    let refreshTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with total count
            HStack {
                Text("Keystroke Statistics")
                    .font(.headline)
                Spacer()
                Text("\(totalKeystrokes) total")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Three columns for stats
            HStack(alignment: .top, spacing: 16) {
                // Characters
                VStack(alignment: .leading, spacing: 4) {
                    Text("Characters")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    ForEach(characters.prefix(10), id: \.char) { item in
                        HStack {
                            Text(displayChar(item.char))
                                .font(.system(.body, design: .monospaced))
                                .frame(width: 24, alignment: .center)
                            Spacer()
                            Text("\(item.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if characters.isEmpty {
                        Text("No data")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)

                // Bigrams
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bigrams")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    ForEach(bigrams.prefix(10), id: \.bigram) { item in
                        HStack {
                            Text(displayChar(item.bigram))
                                .font(.system(.body, design: .monospaced))
                                .frame(width: 36, alignment: .leading)
                            Spacer()
                            Text("\(item.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if bigrams.isEmpty {
                        Text("No data")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)

                // Trigrams
                VStack(alignment: .leading, spacing: 4) {
                    Text("Trigrams")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    ForEach(trigrams.prefix(10), id: \.trigram) { item in
                        HStack {
                            Text(displayChar(item.trigram))
                                .font(.system(.body, design: .monospaced))
                                .frame(width: 48, alignment: .leading)
                            Spacer()
                            Text("\(item.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if trigrams.isEmpty {
                        Text("No data")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .onAppear(perform: loadStats)
        .onReceive(refreshTimer) { _ in
            loadStats()
        }
    }

    private func loadStats() {
        let db = DatabaseManager.shared
        characters = db.topCharacters(limit: 10)
        bigrams = db.topBigrams(limit: 10)
        trigrams = db.topTrigrams(limit: 10)
        totalKeystrokes = db.totalCharacterCount()
    }

    private func displayChar(_ str: String) -> String {
        // Make special characters more visible
        str.replacingOccurrences(of: " ", with: "␣")
    }
}
