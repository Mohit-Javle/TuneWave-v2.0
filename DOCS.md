# 🎵 TuneWave v2.0 - Complete Documentation

**TuneWave** is a feature-rich, cross-platform music streaming application built using Flutter. It provides a premium music experience with advanced features like queue management, smart shuffle, offline playback, and personalized playlists.

---

## 📑 Table of Contents

1. [Features](#-features)
2. [Getting Started](#-getting-started)
3. [Installation](#-installation)
4. [Building the App](#-building-the-app)
5. [Project Architecture](#-project-architecture)
6. [Optimization Guide](#-optimization-guide)
7. [Troubleshooting](#-troubleshooting)
8. [Customization](#-customization)
9. [Contributing](#-contributing)

---

## ✨ Features

### 🎧 Core Features
- **Music Streaming** - Stream high-quality music from JioSaavn API
- **Smart Search** - Search for songs, artists, and albums with debounced searching
- **Lyrics Display** - View song lyrics in real-time
- **Queue Management** - Full control over your playback queue
- **Smart Shuffle** - Intelligent randomization without repeats
- **Recently Played** - Track your listening history

### 🎨 User Experience
- **Beautiful UI** - Modern, gradient-based design
- **Dark/Light Themes** - Switch between themes seamlessly
- **Smooth Animations** - Premium feel with micro-interactions
- **Double-tap Skip** - Tap left/right on album art to skip
- **Swipe Gestures** - Swipe to add to queue or remove songs

### 📱 Playlist Management
- **Create Playlists** - Organize your favorite songs
- **Liked Songs** - Quick access to your favorites
- **Drag & Drop** - Reorder songs in queue
- **Playlist Sharing** - Share your playlists
- **User Isolation** - Multiple accounts with isolated data

### 🎛️ Playback Controls
- **Background Playback** - Music continues when app is minimized
- **Lock Screen Controls** - Control playback from lock screen
- **Smart Previous** - Restart song or go to previous based on position
- **Repeat Mode** - Loop your favorite tracks

---

## 🚀 Getting Started

### Prerequisites

1. **Flutter SDK** (3.0 or higher)
   - Download: https://flutter.dev/docs/get-started/install
   - Verify: `flutter doctor`

2. **Android Studio** or **VS Code**
   - Android Studio: https://developer.android.com/studio
   - VS Code with Flutter extension

3. **Android SDK** (for Android builds)
   - Minimum SDK: 21 (Android 5.0)

4. **Git** (for version control)
   - Download: https://git-scm.com/

---

## 📦 Installation

### Step 1: Clone the Repository
```bash
git clone https://github.com/yourusername/TuneWave-v2.0.git
cd TuneWave-v2.0-main
```

### Step 2: Install Dependencies
```bash
flutter pub get
```

### Step 3: Run the App

#### Development Mode (Debug)
```bash
flutter run
```

#### For Specific Device
```bash
# List available devices
flutter devices

# Run on specific device
flutter run -d <device-id>
```

---

## 📱 Building the App

### Quick Build Commands Reference

| Task | Command |
|------|---------|
| Run app | `flutter run` |
| Debug APK | `flutter build apk --debug` |
| Release APK | `flutter build apk --release` |
| Split APKs | `flutter build apk --split-per-abi --release` |
| App Bundle | `flutter build appbundle --release` |
| Install APK | `adb install <path-to-apk>` |
| Clean project | `flutter clean` |
| Get dependencies | `flutter pub get` |
| Check setup | `flutter doctor` |

### Debug APK (For Testing)

```bash
flutter build apk --debug
```

**Output:** `build/app/outputs/flutter-apk/app-debug.apk`

### Release APK (For Distribution)

#### Option 1: Single APK (Universal)
```bash
flutter build apk --release
```
**Output:** `build/app/outputs/flutter-apk/app-release.apk`
**Size:** ~20-25 MB

#### Option 2: Split APKs (Smaller file size - Recommended)
```bash
flutter build apk --split-per-abi --release
```

**Outputs:**
- `app-arm64-v8a-release.apk` (64-bit ARM - **Recommended for most devices**) - ~15-18 MB
- `app-armeabi-v7a-release.apk` (32-bit ARM - Older devices) - ~14-16 MB
- `app-x86_64-release.apk` (64-bit x86 - Emulators) - ~16-18 MB

### App Bundle (For Google Play Store)

```bash
flutter build appbundle --release
```

**Output:** `build/app/outputs/bundle/release/app-release.aab`

### Maximum Optimization Build

```bash
flutter build apk --release --split-per-abi --shrink --obfuscate
```

---

## 🏗️ Project Architecture

### Technology Stack

- **Framework:** Flutter (Dart)
- **State Management:** Provider (for reactive UI updates)
- **Audio Engine:** audioplayers + audio_service (background playback)
- **Local Database:** SharedPreferences (sessions, playlists, settings)
- **Networking:** http (API calls)
- **URL Decryption:** dart_des

### Architecture Pattern (MVCS)

The app follows **Model-View-Controller-Service** architecture:

- **Models:** Define data structures (`SongModel`, `UserModel`, `ArtistModel`)
- **Views (Screens):** UI components users interact with
- **Services:** Business logic and data fetching
- **Providers:** Bridge between Services and Views with reactive updates

### Directory Structure

```
TuneWave-v2.0-main/
├── android/                 # Android platform files
├── ios/                     # iOS platform files
├── lib/
│   ├── main.dart           # App entry point
│   ├── models/             # Data models (Song, User, Artist)
│   ├── screen/             # UI screens
│   ├── services/           # Business logic & API
│   │   ├── api_service.dart      # JioSaavn API integration
│   │   ├── auth_service.dart     # User authentication
│   │   ├── music_service.dart    # Music playback logic
│   │   └── playlist_service.dart # Playlist management
│   └── widgets/            # Reusable components
├── assets/                 # Images, fonts, etc.
├── test/                   # Unit and widget tests
└── pubspec.yaml           # Dependencies
```

### Key Services

#### 1. 🎵 MusicService
- Manages global audio state
- Play, Pause, Seek, Next, Previous, Shuffle, Repeat
- Background playback support
- Listening history persistence

#### 2. 🔐 AuthService
- User login, registration, sessions
- Secure local credential storage
- Multi-user support with data isolation

#### 3. 📂 PlaylistService
- User-specific playlists and liked songs
- Create, rename, delete playlists
- Add/remove songs from playlists

#### 4. 🔍 ApiService
- JioSaavn API integration
- Search songs, albums, artists
- Fetch song details, lyrics, high-quality URLs
- Debounced search for efficiency

---

## 🚀 Optimization Guide

### Optimizations Applied

✅ **Code Shrinking (R8)** - Removes unused code  
✅ **Resource Shrinking** - Removes unused resources  
✅ **Code Obfuscation** - Security against reverse engineering  
✅ **ProGuard Rules** - Protects Flutter & audio libraries  
✅ **Split APKs** - Smaller app sizes per architecture

**Result:** 30-40% smaller APK size

### Size Comparison

| Build Type | Before | After | Savings |
|------------|--------|-------|---------|
| Universal APK | 52.5 MB | ~35-40 MB | ~30% |
| ARM64 APK | 20.6 MB | ~14-16 MB | ~30% |

### Additional Optimizations

#### 1. Image Caching (Recommended)

Add to `pubspec.yaml`:
```yaml
dependencies:
  cached_network_image: ^3.3.0
```

Replace `Image.network()` with:
```dart
CachedNetworkImage(
  imageUrl: song.imageUrl,
  placeholder: (context, url) => CircularProgressIndicator(),
  errorWidget: (context, url, error) => Icon(Icons.error),
)
```

#### 2. Lazy Loading

Use `AutomaticKeepAliveClientMixin` for tabs:
```dart
class _HomeScreenState extends State<HomeScreen> 
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
}
```

#### 3. Reduce App Size

```bash
# Analyze bundle size
flutter build apk --analyze-size

# Check dependencies
flutter pub deps
```

### Performance Monitoring

```bash
# Run in profile mode
flutter run --profile

# Trace startup time
flutter run --trace-startup

# Check memory usage (press 'M' in terminal)
flutter run --profile
```

---

## 🔧 Configuration

### App Signing (Required for Release)

1. **Generate keystore:**
```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

2. **Create `android/key.properties`:**
```properties
storePassword=<your-store-password>
keyPassword=<your-key-password>
keyAlias=upload
storeFile=<path-to-keystore>/upload-keystore.jks
```

3. **Update `android/app/build.gradle`:**
```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

---

## 🐛 Troubleshooting

### Build Fails
```bash
flutter clean
flutter pub get
flutter build apk --release
```

### Gradle Issues
```bash
cd android
./gradlew clean
cd ..
flutter build apk --release
```

### Dependencies Issues
```bash
flutter pub cache repair
flutter pub get
```

### Optimized Build Issues

If the optimized build has problems:

1. **Check ProGuard rules:**
   - Edit `android/app/proguard-rules.pro`
   - Add keep rules for problematic classes

2. **Disable obfuscation temporarily:**
   ```bash
   flutter build apk --release --no-shrink
   ```

3. **Check logs:**
   ```bash
   adb logcat | grep flutter
   ```

---

## 📱 Installing APK on Device

### Method 1: ADB (Android Debug Bridge)
```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Method 2: Manual Transfer
1. Copy APK to your phone (USB, email, cloud)
2. Open file manager on phone
3. Tap the APK file
4. Allow "Install from unknown sources" if prompted
5. Tap "Install"

---

## 🎨 Customization

### Change App Name

Edit `android/app/src/main/AndroidManifest.xml`:
```xml
<application
    android:label="Your App Name"
    ...>
```

### Change App Icon

Replace files in `android/app/src/main/res/mipmap-*/`

Or use Flutter launcher icons:
```bash
flutter pub add flutter_launcher_icons
```

### Change Package Name

```bash
flutter pub add change_app_package_name
flutter pub run change_app_package_name:main com.yourcompany.tunewave
```

---

## 🚀 Deployment

### Google Play Store
1. Build app bundle: `flutter build appbundle --release`
2. Create Google Play Console account
3. Upload `app-release.aab`
4. Fill in store listing details
5. Submit for review

### Direct Distribution
1. Build APK: `flutter build apk --release`
2. Share `app-release.apk` file
3. Users install manually

---

## 📊 Performance Tips

### 1. Reduce Rebuilds
```dart
// Bad
child: Text(someValue)

// Good
child: ValueListenableBuilder(
  valueListenable: someNotifier,
  builder: (context, value, child) => Text(value),
)
```

### 2. Use Const Constructors
```dart
// Bad
Icon(Icons.play_arrow)

// Good
const Icon(Icons.play_arrow)
```

### 3. Lazy Load Screens
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => const LazyLoadedScreen(),
  ),
);
```

---

## 🔑 Key Dependencies

- **audio_service:** Background audio playback
- **audioplayers:** Audio player engine
- **provider:** State management
- **shared_preferences:** Local storage
- **http:** API requests
- **dart_des:** URL decryption for JioSaavn

---

## 🎯 Data Flow

### 1. App Launch (SplashScreen)
- Checks `AuthService` for active session
- If logged in → Loads user data → Home
- If not logged in → Login/Signup

### 2. Playing a Song
- User taps song in SearchScreen
- `MusicService` stops current track
- Adds song to queue & listening history
- Calls `audioPlayer.play(url)`
- Updates mini player UI

### 3. Liking a Song
- User taps heart icon
- `PlaylistService` toggles status
- Updates local "Liked Songs" for current user
- UI updates via `Consumer<PlaylistService>`

---

## ⚠️ Legal Disclaimer

> **Important:** This project uses an unofficial JioSaavn API for educational/portfolio purposes. If you plan to publish this app to the Play Store/App Store, you must secure official licensing rights or switch to an official API like Spotify/Apple Music SDKs.

---

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

## 🙏 Acknowledgments

- JioSaavn for music data
- Flutter team for the amazing framework
- All contributors and testers

---

## 📞 Support

For issues and questions:
- Open an issue on GitHub
- Email: support@tunewave.app

---

## 🎉 Enjoy TuneWave!

Happy listening! 🎵
