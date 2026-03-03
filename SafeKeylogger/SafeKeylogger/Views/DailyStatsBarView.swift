import Cocoa

/// A mini vertical bar chart showing daily keystroke counts for the last 7 days.
final class DailyStatsBarView: NSView {
    struct DayEntry {
        let dayLabel: String   // e.g. "Thu"
        let count: Int
        let isToday: Bool
    }

    private var entries: [DayEntry] = []

    private let chartWidth: CGFloat = 220
    private let chartHeight: CGFloat = 80
    private let barMaxHeight: CGFloat = 40
    private let barWidth: CGFloat = 16
    private let barSpacing: CGFloat = 16  // space between bars
    private let topPadding: CGFloat = 6
    private let labelHeight: CGFloat = 14
    private let countHeight: CGFloat = 12

    override var intrinsicContentSize: NSSize {
        NSSize(width: chartWidth, height: chartHeight)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: NSRect(x: 0, y: 0, width: chartWidth, height: chartHeight))
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    func update(data: [(date: Date, count: Int)]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE"

        entries = data.map { entry in
            DayEntry(
                dayLabel: dayFormatter.string(from: entry.date),
                count: entry.count,
                isToday: calendar.isDate(entry.date, inSameDayAs: today)
            )
        }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard !entries.isEmpty else { return }

        let maxCount = entries.map(\.count).max() ?? 0

        // Total width of all bars + spacing
        let totalBarsWidth = CGFloat(entries.count) * barWidth + CGFloat(entries.count - 1) * barSpacing
        let startX = (bounds.width - totalBarsWidth) / 2

        let dayLabelAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]
        let countAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 8, weight: .regular),
            .foregroundColor: NSColor.tertiaryLabelColor,
        ]
        let todayDayAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9, weight: .bold),
            .foregroundColor: NSColor.labelColor,
        ]

        for (i, entry) in entries.enumerated() {
            let x = startX + CGFloat(i) * (barWidth + barSpacing)

            // Bar
            let barHeight: CGFloat
            if maxCount > 0 && entry.count > 0 {
                barHeight = max(3, CGFloat(entry.count) / CGFloat(maxCount) * barMaxHeight)
            } else {
                barHeight = 0
            }
            let barY = topPadding + barMaxHeight - barHeight + countHeight + labelHeight
            let barRect = NSRect(x: x, y: barY, width: barWidth, height: barHeight)
            let barPath = NSBezierPath(roundedRect: barRect, xRadius: 3, yRadius: 3)

            let barColor = entry.isToday ? NSColor.controlAccentColor : NSColor.controlAccentColor.withAlphaComponent(0.5)
            barColor.setFill()
            barPath.fill()

            // Draw a thin baseline for days with zero count
            if entry.count == 0 {
                let baselineRect = NSRect(x: x + 2, y: barY, width: barWidth - 4, height: 1)
                NSColor.separatorColor.setFill()
                NSBezierPath(rect: baselineRect).fill()
            }

            // Day label below bar
            let dayStr = NSAttributedString(string: entry.dayLabel, attributes: entry.isToday ? todayDayAttrs : dayLabelAttrs)
            let daySize = dayStr.size()
            let dayX = x + (barWidth - daySize.width) / 2
            let dayY = topPadding + countHeight
            dayStr.draw(at: NSPoint(x: dayX, y: dayY))

            // Count below day label
            let countStr: String
            if entry.count >= 1000 {
                countStr = String(format: "%.1fk", Double(entry.count) / 1000.0)
            } else {
                countStr = "\(entry.count)"
            }
            let countAttrStr = NSAttributedString(string: countStr, attributes: countAttrs)
            let countSize = countAttrStr.size()
            let countX = x + (barWidth - countSize.width) / 2
            let countY = topPadding
            countAttrStr.draw(at: NSPoint(x: countX, y: countY))
        }
    }
}
