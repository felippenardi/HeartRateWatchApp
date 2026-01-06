# Heart Rate Watch App

Apple Watch app that monitors heart rate and sends it to an API in real-time.

## Files

| File | Purpose |
|------|---------|
| `ContentView.swift` | Main UI - heart rate display and start/stop button |
| `WorkoutManager.swift` | HealthKit workout session for continuous heart rate |
| `APIService.swift` | Sends heart rate data to your API |
| `HeartRateData.swift` | JSON data model |

## API

Sends POST requests to: `https://applewatchtest.free.beeceptor.com/heartrate`

```json
{
  "heart_rate": 72,
  "timestamp": "2024-01-15T10:30:00Z",
  "device_id": "uuid",
  "session_type": "monitoring",
  "app_state": "foreground",
  "session_id": "uuid"
}
```

---

## Setup (5 minutes)

### 1. Create Xcode Project

1. Open Xcode
2. **File → New → Project**
3. Select **watchOS** tab
4. Select **App** → Next
5. Fill in:
   - Product Name: `HeartRateTracker`
   - Team: Your team
   - Organization Identifier: `com.yourname`
   - **Watch-only App**: ✓ (checked)
6. Click **Next** → Choose location → **Create**

### 2. Add Capabilities

1. Click the project (blue icon) in left sidebar
2. Select **"HeartRateTracker Watch App"** target
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability** → Add **HealthKit**
5. Click **+ Capability** → Add **Background Modes** → Check **"Workout processing"**

### 3. Add Source Files

1. In Finder, select all 4 `.swift` files from this repo
2. Drag them into the **"HeartRateTracker Watch App"** folder in Xcode
3. In the dialog:
   - ✓ Copy items if needed
   - ✓ HeartRateTracker Watch App (target)
4. Click **Finish**
5. **Delete** the default `ContentView.swift` that Xcode created (keep mine)

### 4. Run

1. Select a Watch Simulator from the dropdown (e.g., Apple Watch Series 9)
2. Press **⌘R** to build and run
3. Tap **Start** to begin monitoring

---

## Change API Endpoint

Edit `APIService.swift` line 4:

```swift
private let baseURL = "https://your-api.com"
```

---

## Requirements

- Xcode 15+
- watchOS 10+
- Apple Developer account (for physical device)
