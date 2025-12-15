import Foundation
import Cocoa
import Carbon.HIToolbox

final class KeyMonitor: ObservableObject {
    static let shared = KeyMonitor()

    @Published var isMonitoring = false
    @Published var hasAccessibilityPermission = false

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // Privacy-focused: Only store last 3 characters, never more
    private var buffer: [String] = []
    private let bufferSize = 3

    private init() {
        checkAccessibilityPermission()
    }

    // MARK: - Permission Handling

    func checkAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        hasAccessibilityPermission = AXIsProcessTrustedWithOptions(options)
    }

    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)

        // Open System Settings to Accessibility
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Monitoring Control

    func startMonitoring() {
        guard !isMonitoring else { return }
        guard hasAccessibilityPermission else {
            requestAccessibilityPermission()
            return
        }

        let eventMask = (1 << CGEventType.keyDown.rawValue)

        // Create event tap
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else {
                    return Unmanaged.passRetained(event)
                }
                let monitor = Unmanaged<KeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
                monitor.handleKeyEvent(event)
                return Unmanaged.passRetained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("Failed to create event tap. Check accessibility permissions.")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            isMonitoring = true
        }
    }

    func stopMonitoring() {
        guard isMonitoring else { return }

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil
        isMonitoring = false

        // Clear buffer on stop for privacy
        buffer.removeAll()
    }

    // MARK: - Key Event Processing

    private func handleKeyEvent(_ event: CGEvent) {
        guard let char = extractCharacter(from: event) else { return }

        // Update buffer: keep only last 3 characters
        buffer.append(char)
        if buffer.count > bufferSize {
            buffer.removeFirst()
        }

        // Record to database immediately
        recordNgrams()
    }

    private func extractCharacter(from event: CGEvent) -> String? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        // Handle special keys
        if let specialChar = specialKeyMapping(Int(keyCode)) {
            return specialChar
        }

        // Get character from event
        var actualStringLength = 0
        var chars = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(
            maxStringLength: 4,
            actualStringLength: &actualStringLength,
            unicodeString: &chars
        )

        guard actualStringLength > 0 else { return nil }

        let char = String(utf16CodeUnits: chars, count: actualStringLength)

        // Filter out empty or control characters (except mapped ones)
        guard !char.isEmpty, char.unicodeScalars.first?.value ?? 0 >= 32 else {
            return nil
        }

        return char
    }

    private func specialKeyMapping(_ keyCode: Int) -> String? {
        switch keyCode {
        case kVK_Space: return "␣"           // Space
        case kVK_Return: return "↵"          // Return/Enter
        case kVK_Tab: return "⇥"             // Tab
        case kVK_Delete: return "⌫"          // Backspace
        case kVK_Escape: return "⎋"          // Escape
        case kVK_ForwardDelete: return "⌦"   // Forward Delete
        default: return nil
        }
    }

    private func recordNgrams() {
        let db = DatabaseManager.shared

        // Always record the most recent character (unigram)
        if let char = buffer.last {
            db.recordCharacter(char)
        }

        // Record bigram if we have at least 2 characters
        if buffer.count >= 2 {
            let bigram = buffer.suffix(2).joined()
            db.recordBigram(bigram)
        }

        // Record trigram if we have 3 characters
        if buffer.count >= 3 {
            let trigram = buffer.joined()
            db.recordTrigram(trigram)
        }
    }
}
