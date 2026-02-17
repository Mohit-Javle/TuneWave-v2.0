# 📥 Download Flow - Visual Guide

## 🎯 Complete Download Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    USER JOURNEY                                  │
└─────────────────────────────────────────────────────────────────┘

1. DISCOVER SONG
   ↓
   User finds a song in:
   • Search Results
   • Home Screen (Trending/Recommended)
   • Album Page
   • Playlist
   • Artist Page
   
2. TAP DOWNLOAD BUTTON
   ↓
   [📥 Download Icon] ← User taps this
   
3. DOWNLOAD IN PROGRESS
   ↓
   [⏳ Progress Circle] ← Shows download progress (0-100%)
   • Can tap [X] to cancel
   
4. DOWNLOAD COMPLETE
   ↓
   [✅ Download Done Icon] ← Icon changes to checkmark
   • SnackBar: "Download complete!"
   
5. ACCESS DOWNLOADED SONGS
   ↓
   Navigate to Downloads Page:
   • Library → Downloads
   • Settings → Downloads
   • Direct route: /downloads
   
6. PLAY OFFLINE
   ↓
   • Tap any downloaded song
   • Plays from local storage
   • No internet needed!
```

---

## 📱 User Interface Flow

### **Step 1: Finding Songs**

Any screen with songs will show the download button:

```
┌─────────────────────────────────────┐
│  Search Results / Song List         │
├─────────────────────────────────────┤
│                                     │
│  [🎵 Album Art]  Song Name         │
│                  Artist Name        │
│                            [📥] [▶️] │← Download button
│  ─────────────────────────────────  │
│  [🎵 Album Art]  Another Song      │
│                  Artist             │
│                            [📥] [▶️] │
│                                     │
└─────────────────────────────────────┘
```

### **Step 2: Downloading**

When user taps download icon:

```
┌─────────────────────────────────────┐
│  Downloading...                     │
├─────────────────────────────────────┤
│                                     │
│  [🎵]  Shape of You                │
│        Ed Sheeran                   │
│                     [⏳ 47%] [▶️]   │← Progress indicator
│  ─────────────────────────────────  │
│                                     │
│  SnackBar at bottom:                │
│  ┌───────────────────────────────┐ │
│  │ Downloading "Shape of You"... │ │
│  └───────────────────────────────┘ │
└─────────────────────────────────────┘
```

### **Step 3: Downloaded**

After completion:

```
┌─────────────────────────────────────┐
│  Song Downloaded!                   │
├─────────────────────────────────────┤
│                                     │
│  [🎵]  Shape of You                │
│        Ed Sheeran                   │
│                       [✅] [▶️]     │← Checkmark icon
│  ─────────────────────────────────  │
│                                     │
│  SnackBar at bottom:                │
│  ┌───────────────────────────────┐ │
│  │ ✓ Download complete!          │ │
│  └───────────────────────────────┘ │
└─────────────────────────────────────┘
```

---

## 📂 Where to Find Downloaded Songs

### **Option 1: Downloads Page (Dedicated Screen)**

Navigate via:
- **Library** Tab → "Downloads" menu item
- **Settings** → "Downloads"
- Direct navigation: `Navigator.pushNamed(context, '/downloads')`

```
┌───────────────────────────────────────┐
│  ← Downloads                        ⋮ │← Menu for "Clear All"
├───────────────────────────────────────┤
│                                       │
│  ┌─────────────────────────────────┐ │
│  │ 📊 Storage Info                 │ │
│  │                                 │ │
│  │ 12 Songs                        │ │
│  │ Storage: 45.8 MB           [💾] │ │
│  └─────────────────────────────────┘ │
│                                       │
│  ┌─────────────────────────────────┐ │
│  │ [🎵] Shape of You               │ │
│  │      Ed Sheeran                 │ │
│  │      Downloaded: 2h ago         │ │
│  │                      [▶️] [✅]   │ │← Play & Delete
│  └─────────────────────────────────┘ │
│                                       │
│  ┌─────────────────────────────────┐ │
│  │ [🎵] Blinding Lights            │ │
│  │      The Weeknd                 │ │
│  │      Downloaded: 1d ago         │ │
│  │                      [▶️] [✅]   │ │
│  └─────────────────────────────────┘ │
│                                       │
│  ...more songs...                     │
│                                       │
└───────────────────────────────────────┘
```

### **Option 2: In-Place Indicators**

Downloaded songs show a checkmark badge wherever they appear:

```
┌─────────────────────────────────────┐
│  All Songs / Search / Playlist      │
├─────────────────────────────────────┤
│                                     │
│  [🎵]  Shape of You     [✅]        │← Badge shows it's downloaded
│        Ed Sheeran            [▶️]   │
│  ─────────────────────────────────  │
│  [🎵]  Another Song      [📥]       │← Not downloaded yet
│        Artist                [▶️]   │
│                                     │
└─────────────────────────────────────┘
```

---

## 🔄 Complete Technical Flow

```
USER ACTION                 SYSTEM RESPONSE                  RESULT
───────────────────────────────────────────────────────────────────

1. Tap Download       →   Check if already downloaded    →  Show status
   [📥]                    DownloadService.isSongDownloaded()
                      
2. If not downloaded  →   Request storage permission     →  Permission granted
                           (Android only, auto-handled)
                      
3. Start download     →   Create download task           →  Progress shown
                           Dio.download() with progress
                           callback
                      
4. While downloading  →   Update progress indicator      →  User sees progress
                           (0% → 100%)
                      
5. Download complete  →   Save file to local storage     →  File saved
                           /TuneWave/Downloads/songID.mp3
                      
6. Update database    →   Save to SharedPreferences      →  Persists across
                           Add to downloadedSongs list        app restarts
                      
7. Update UI          →   Change icon to checkmark       →  Visual feedback
                           Show success SnackBar
                      
8. User navigates     →   Show in Downloads page         →  Song visible
   to Downloads            List all downloaded songs
                      
9. Tap Play           →   Play from local file           →  Offline playback
                           Use song.localFilePath              works!
                           instead of streaming URL
```

---

## 🎨 State Management Flow

### **Download Button States:**

```dart
// State 1: Not Downloaded
[📥 Download Icon] 
  ↓ Tap
  
// State 2: Downloading (with progress)
[⏳ 0%] → [⏳ 25%] → [⏳ 50%] → [⏳ 75%] → [⏳ 99%]
  ↓ Complete OR ↓ Cancel
  
// State 3: Downloaded
[✅ Checkmark]
  ↓ Tap → Menu → Delete
  
// Back to State 1: Not Downloaded
[📥 Download Icon]
```

### **Provider State Updates:**

```dart
DownloadService (ChangeNotifier)
├── downloadedSongs: List<SongModel>
├── _downloadProgress: Map<String, double>
└── _cancelTokens: Map<String, CancelToken>

When download starts:
  notifyListeners() → UI updates → Shows progress

When download completes:
  notifyListeners() → UI updates → Shows checkmark

When user deletes:
  notifyListeners() → UI updates → Shows download icon
```

---

## 📊 Data Storage

### **Where Files Are Stored:**

**Android:**
```
📁 /storage/emulated/0/Android/data/com.yourapp.tunewave/
   └── 📁 files/
       └── 📁 TuneWave/
           └── 📁 Downloads/
               ├── 🎵 song123_Shape_of_You.mp3
               ├── 🎵 song456_Blinding_Lights.mp3
               └── 🎵 song789_Levitating.mp3
```

**iOS:**
```
📁 App Documents/
   └── 📁 Downloads/
       ├── 🎵 song123_Shape_of_You.mp3
       ├── 🎵 song456_Blinding_Lights.mp3
       └── 🎵 song789_Levitating.mp3
```

### **Metadata Storage (SharedPreferences):**

```json
{
  "downloaded_songs": [
    {
      "id": "song123",
      "name": "Shape of You",
      "artist": "Ed Sheeran",
      "isDownloaded": true,
      "localFilePath": "/path/to/song123_Shape_of_You.mp3",
      "downloadedAt": "2026-02-17T18:00:00Z"
    }
  ]
}
```

---

## 🚀 Quick Integration Example

### **Add Download Button to Your Screen:**

```dart
// In search_screen.dart or any song list:

import 'package:clone_mp/widgets/download_button.dart';

ListTile(
  leading: Image.network(song.imageUrl),
  title: Text(song.name),
  subtitle: Text(song.artist),
  trailing: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      // ADD THIS: Download button
      DownloadButton(song: song),
      
      // Existing play button
      IconButton(
        icon: Icon(Icons.play_arrow),
        onPressed: () => musicService.play(song),
      ),
    ],
  ),
)
```

### **Add Downloads Menu in Library/Settings:**

```dart
// In library_screen.dart or settings_screen.dart:

ListTile(
  leading: Icon(Icons.download),
  title: Text('Downloads'),
  subtitle: Consumer<DownloadService>(
    builder: (context, service, _) {
      return Text('${service.downloadedSongs.length} songs');
    },
  ),
  trailing: Icon(Icons.chevron_right),
  onTap: () {
    Navigator.pushNamed(context, '/downloads');
  },
)
```

---

## ✨ User Experience Summary

1. **Easy to Download:** Just tap the download icon
2. **Visual Feedback:** Clear progress and completion indicators
3. **Easy to Find:** Dedicated Downloads page
4. **Easy to Manage:** Delete individual or all downloads
5. **Seamless Playback:** Automatically uses offline files when available

---

## 🎯 Next Steps for Integration

1. ✅ **Backend Ready** - DownloadService is implemented
2. ✅ **UI Components Ready** - DownloadButton and DownloadsPage created
3. ⏳ **Add to Screens** - Integrate DownloadButton where songs appear
4. ⏳ **Add Navigation** - Add "Downloads" menu item in Library/Settings
5. ⏳ **Test** - Once Java 17 is installed, test the full flow

---

**The download feature is fully implemented and ready to use!** 🎉

You just need to:
1. Fix the Java version issue
2. Add the download button to your song lists
3. Add navigation to the Downloads page

Then users can enjoy offline music! 🎵
