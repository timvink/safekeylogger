# Contributing to SafeKeylogger

## Overview

SafeKeylogger is a privacy-focused macOS menu bar app that tracks keystroke statistics without storing raw input. It records only aggregate counts of characters, bigrams (2-character sequences), and trigrams (3-character sequences).

## Architecture

```
SafeKeylogger/
├── Package.swift                    # Swift Package Manager config
├── SafeKeylogger/
│   ├── SafeKeyloggerApp.swift      # App entry point (@main)
│   ├── AppDelegate.swift           # Menu bar setup, lifecycle
│   ├── KeyMonitor.swift            # Core keystroke capture logic
│   ├── Database/
│   │   ├── Models.swift            # GRDB record types
│   │   └── DatabaseManager.swift   # SQLite operations
│   ├── Views/
│   │   ├── MenuBarView.swift       # Main popover container
│   │   ├── StatsView.swift         # Statistics display
│   │   └── SettingsView.swift      # Configuration UI
│   └── Info.plist                  # App configuration
├── scripts/
│   └── create-dmg.sh               # DMG packaging script
└── CONTRIBUTING.md
```

## Key Components

### KeyMonitor (`KeyMonitor.swift`)

The core component responsible for capturing keystrokes globally.

**How it works:**
1. Uses `CGEvent.tapCreate()` to create a system-wide event tap
2. Maintains a **3-character circular buffer** - this is the privacy guarantee
3. On each keypress:
   - Extracts the character from the CGEvent
   - Updates buffer: `[c1, c2, c3]` → `[c2, c3, new_char]`
   - Records unigram, bigram (if 2+ chars), trigram (if 3 chars)
4. Writes to database **immediately** (no batching)

**Privacy Design:**
- Buffer is exactly 3 characters maximum
- Buffer is cleared when monitoring stops
- No raw keystroke sequences are ever stored
- Only aggregate counts persist

**Permissions:**
- Requires macOS Accessibility permission
- App prompts user and opens System Settings on first launch

### DatabaseManager (`Database/DatabaseManager.swift`)

SQLite persistence layer using GRDB.swift.

**Schema:**
```sql
CREATE TABLE characters (char TEXT PRIMARY KEY, count INTEGER);
CREATE TABLE bigrams (bigram TEXT PRIMARY KEY, count INTEGER);
CREATE TABLE trigrams (trigram TEXT PRIMARY KEY, count INTEGER);
```

**Key behaviors:**
- Uses `INSERT ... ON CONFLICT DO UPDATE` for upserts
- Writes happen on a dedicated serial queue
- Each keystroke triggers an immediate write (crash-safe)
- Database path configurable, defaults to `~/.safekeylogger/keystrokes.db`

### UI Components

- **MenuBarView**: Container with tabs for Stats/Settings
- **StatsView**: Displays top 10 characters/bigrams/trigrams, auto-refreshes every 2 seconds
- **SettingsView**: Toggle monitoring, change database path, clear data

## Building

### Development Setup

To maintain Accessibility permissions across rebuilds, set up a local development certificate:

```bash
./scripts/setup-dev-cert.sh
```

This creates a self-signed "SafeKeylogger Development" certificate in your keychain.

### Prerequisites

- macOS 13.0 (Ventura) or later
- Xcode 15+ or Swift 5.9+
- **Recommended**: `create-dmg` for prettier DMG packaging:
  ```bash
  brew install create-dmg
  ```

### Development Build

```bash
cd SafeKeylogger
swift build
```

### Release Build

```bash
cd SafeKeylogger
swift build -c release
```

### Run During Development

```bash
cd SafeKeylogger
swift run
```

**Note:** You'll need to grant Accessibility permission in System Settings → Privacy & Security → Accessibility.

### Create DMG for Distribution

```bash
./scripts/create-dmg.sh
```

This creates `build/SafeKeylogger-1.0.0.dmg`.

## Testing the App

1. Build and run the app
2. Grant Accessibility permission when prompted
3. Click the keyboard icon in menu bar
4. Type anywhere on your system
5. Check the Stats tab - you should see counts updating

## Code Style

- Use Swift's standard naming conventions
- Keep files focused and single-purpose
- Add comments for non-obvious logic
- Privacy-first: never store more than 3 characters

## Database Inspection

To inspect the SQLite database directly:

```bash
sqlite3 ~/.safekeylogger/keystrokes.db
sqlite> SELECT * FROM characters ORDER BY count DESC LIMIT 10;
sqlite> SELECT * FROM bigrams ORDER BY count DESC LIMIT 10;
sqlite> SELECT * FROM trigrams ORDER BY count DESC LIMIT 10;
```

## Common Issues

### "Not permitted to capture keystrokes"
Grant Accessibility permission: System Settings → Privacy & Security → Accessibility → Enable SafeKeylogger

### App doesn't appear in menu bar
- Check that `LSUIElement` is `true` in Info.plist (no dock icon, menu bar only)
- The app might already be running - check Activity Monitor

### Database not updating
- Ensure monitoring is enabled (green dot in popover)
- Check file permissions on `~/.safekeylogger/`

## Notarization (for distribution)

To distribute outside the App Store, notarize the DMG:

```bash
xcrun notarytool submit build/SafeKeylogger-1.0.0.dmg \
    --apple-id YOUR_APPLE_ID \
    --team-id YOUR_TEAM_ID \
    --password YOUR_APP_SPECIFIC_PASSWORD
```

## License

[Add your license here]
