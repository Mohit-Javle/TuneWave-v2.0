# 💾 Offline Downloads Feature Guide

## Overview
The offline downloads feature allows users to download their favorite songs for playback without an internet connection. This is perfect for:
- Saving on mobile data
- Listening in areas with poor connectivity  
- Creating a personal offline music library

---

## How to Use

### 📥 Downloading Songs

1. **From Search/Home/Library:**
   - Find the song you want to download
   - Tap the **download icon** (⬇️) next to the song
   - Wait for the download to complete (progress will be shown)
   - A success message will appear when done

2. **During Download:**
   - You'll see a circular progress indicator
   - Tap the **X button** to cancel the download if needed

3. **Downloaded Songs:**
   - The download icon changes to a **checkmark** (✓) when complete
   - The song is now available offline!

### 🎵 Playing Offline Songs

1. **Access Downloads Page:**
   - Navigate to **Settings** → **Downloads**
   - Or use the route: `/downloads`

2. **View Your Library:**
   - See all downloaded songs with album art
   - Check total storage used
   - View download dates

3. **Play Music:**
   - Tap the **play button** on any downloaded song
   - Works exactly like streaming, but uses local files
   - No internet required!

### 🗑️ Managing Downloads

**Delete Individual Songs:**
- Tap the checkmark icon on a downloaded song
- Select "Delete Download" from the menu
- Confirm deletion

**Clear All Downloads:**
- Go to Downloads page
- Tap the **menu icon** (⋮) in the top-right
- Select "Clear All"
- Confirm to delete all downloaded songs

---

## Technical Details

### Storage Location
- **Android:** `/Android/data/com.yourapp/files/TuneWave/Downloads/`
- **iOS:** App Documents directory `/Downloads/`

### Permissions
- Android 10+ uses scoped storage (no permission needed)
- Android 9 and below requires storage permission (auto-requested)

### File Format
- Songs are downloaded as **MP3 files**
- Filenames are sanitized for compatibility
- Original quality is preserved

### Storage Management
The Downloads page shows:
- Total number of downloaded songs
- Total storage space used
- Individual song download dates

---

## Implementation for Developers

### Using DownloadButton Widget

```dart
import 'package:clone_mp/widgets/download_button.dart';

// In your song list/card:
DownloadButton(
  song: songModel,
  size: 24.0,  // Optional, default is 24
  color: Colors.blue,  // Optional
)
```

### Accessing DownloadService

```dart
import 'package:provider/provider.dart';
import 'package:clone_mp/services/download_service.dart';

// In your widget:
final downloadService = Provider.of<DownloadService>(context);

// Check if downloaded
bool isDownloaded = downloadService.isSongDownloaded(songId);

// Get downloaded version
SongModel? song = downloadService.getDownloadedSong(songId);

// Download a song
await downloadService.downloadSong(song);

// Delete a song
await downloadService.deleteSong(songId);

// Get storage info
int totalBytes = await downloadService.getTotalStorageUsed();
List<SongModel> downloads = downloadService.downloadedSongs;
```

### Audio Playback Integration

The MusicService automatically detects when a song has a local file:
- If `song.isDownloaded == true` and `song.localFilePath` exists
- Plays from local storage instead of streaming
- Seamless transition between online and offline playback

---

## Features

✅ **Progressive Download** - See real-time download progress  
✅ **Cancel Anytime** - Stop downloads mid-way  
✅ **Smart Storage** - Uses app-specific directories (no extra permissions on modern Android)  
✅ **Persistent Library** - Downloads survive app restarts  
✅ **Storage Tracking** - Monitor space usage  
✅ **Batch Management** - Clear all downloads at once  
✅ **Error Handling** - Graceful failures with user notifications  

---

## Roadmap / Future Enhancements

- [ ] Background downloads
- [ ] WiFi-only download option
- [ ] Automatic cache management
- [ ] Download quality selection
- [ ] Playlist batch downloads
- [ ] Export/Import downloads

---

## Troubleshooting

**Downloads not starting?**
- Check internet connection
- Verify storage permission (Android 9 and below)
- Ensure sufficient storage space

**Can't find downloaded songs?**
- Go to Downloads page (`/downloads` route)
- Check if the app has been uninstalled (downloads are in app directory)

**Playback issues with offline songs?**
- Verify file exists in Downloads page
- Try re-downloading the song
- Check file isn't corrupted

---

**Happy Offline Listening! 🎵**
