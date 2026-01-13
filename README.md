# Mighty

A SwiftUI iOS app for tracking kids' activities, schedules, and media consumption.

## Features

- **Activity Tracking** - Create custom sections for each child to track their activities
- **Calendar & Weekly Views** - Visualize schedules in monthly calendar or weekly timeline
- **Recurring Activities** - Set up repeating events (daily, weekly, biweekly, monthly)
- **Time Conflict Detection** - Get warnings when activities overlap across children
- **Media Tracking** - Log movies and books with poster images from TMDB/Google Books
- **Push Notifications** - Reminders 1 hour before scheduled activities
- **Cloud Sync** - Data synced via InstantDB with magic link authentication

## Screenshots

*Coming soon*

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/kezsmeister/MightyXcode.git
   cd MightyXcode
   ```

2. Create your secrets file:
   ```bash
   cp Mighty/Secrets.swift.example Mighty/Secrets.swift
   ```

3. Edit `Mighty/Secrets.swift` and add your InstantDB App ID:
   ```swift
   enum Secrets {
       static let instantDBAppId = "YOUR_INSTANTDB_APP_ID"
   }
   ```

4. Open `Mighty.xcodeproj` in Xcode

5. Build and run

## Architecture

- **SwiftUI** - Declarative UI framework
- **SwiftData** - Local persistence with CloudKit sync
- **InstantDB** - Backend authentication and real-time data
- **Cloudflare Workers** - Auth proxy for secure token handling

## Project Structure

```
Mighty/
├── MightyApp.swift          # App entry point
├── Models.swift             # SwiftData models
├── ContentView.swift        # Main tab view
├── CalendarView.swift       # Monthly calendar
├── WeeklyScheduleView.swift # Weekly timeline
├── Secrets.swift            # API keys (gitignored)
└── Services/
    ├── AuthenticationService.swift
    ├── RecurrenceService.swift
    ├── ConflictDetectionService.swift
    └── NotificationManager.swift

mighty-auth-proxy/           # Cloudflare Worker for auth
├── src/index.ts
└── wrangler.toml
```

## License

MIT
