# 🎵 TuneWave v2.1 (The Atomic Era)

TuneWave is a premium, feature-rich music streaming application built with Flutter, designed to provide a flagship-level audio experience with immersive visuals and flagship-grade data reliability.

![Flutter](https://img.shields.io/badge/Flutter-3.0+-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2?logo=dart&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-Powered-FFCA28?logo=firebase&logoColor=black)
![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-FDC22A)

---

## 🚀 NEW in v2.1: The Atomic Era

### ⚡ Atomic Firestore Sync
We’ve moved beyond fragile local state. TuneWave now features **Atomic Sync**, ensuring 100% data fidelity by connecting directly to the **FirebaseAuth** layer for all library writes. No more silent failures—your "Like" is a cloud-guaranteed action.

### 🧩 Vibe Engine (Smart Autoplay)
Our discovery engine is now mood-aware. Autoplay now suggests songs based on **Genre** and **Mood** similarity, providing an infinite stream of music that matches your current listening "Vibe."

### 🎨 Player Customizer (Choice of Aesthetic)
Personalize your playback. Choose between our signature **Rotating Vinyl Disc** and a modern **Spotify-Style Square** artwork directly from the settings. Your choice is persisted across app restarts.

### 📱 Universal Responsive Engine
Hardcoded sizes are a thing of the past. Version 2.1 features a resolution-independent layout that scales perfectly across ultrawide phones, foldables, and compact devices.

---

## ✨ Flagship Experience

### 🎨 Adaptive Dynamic Theming
Experience music like never before. TuneWave extracts dominant colors from album art in real-time, morphing the entire app's UI to match the aesthetic of the song you're listening to.

### 🍎 "Crazy" Falling Animations
A high-fidelity physics-based animation system. When you dismiss items from your library or queue, they physically drop off the screen with gravity and rotation, making interactions feel alive.

### ⚡ Global State Synchronization
Seamless playback control and active song highlighting across all screens. Whether you're in Search, Home, or your Liked Songs, the UI stays perfectly synced.

---

## 🎧 Powerful Features
- 🎼 **Infinite Streaming** - High-quality music powered by JioSaavn API.
- 💾 **Offline Downloads** - Take your music anywhere with full offline support.
- 📝 **Synced Lyrics (LRCLIB)** - Beautiful, auto-scrolling lyrics display with tap-to-seek functionality.
- 📂 **Forced Mega Sync** - Legacy data recovery engine that moves your local library to the cloud.
- 🔍 **Smart Discovery** - Instant search for songs, albums, and artists.
- 🔔 **MusicToast** - Branded, unified notification system for a premium notification experience.

---

## 🚀 Getting Started

### 📋 Prerequisites
- **Flutter SDK**: 3.0.0 or higher
- **Android Studio / VS Code**: Latest version recommended
- **Java**: JDK 17 (for Android Gradle builds)

### 🛠️ Setup & Installation

1. **Clone the Repository**
   ```bash
   git clone https://github.com/Mohit-Javle/TuneWave-v2.0.git
   cd TuneWave-v2.0
   ```

2. **Install Dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Configuration**
   - Place your `google-services.json` in `android/app/src/dev/` and `android/app/src/prod/`.
   - Ensure SHA-1 and SHA-256 fingerprints are added to your Firebase project for Google Sign-In.

4. **Run the Application**
   ```bash
   # Development Mode
   flutter run --flavor dev
   
   # Production Mode
   flutter run --flavor prod
   ```

---

## 📦 Building for Release

To build a production-ready signed APK:

1. Create a `key.properties` file in the `android/` directory:
   ```properties
   storePassword=<your-password>
   keyPassword=<your-password>
   keyAlias=<your-alias>
   storeFile=<path-to-keystore>
   ```

2. Run the build command:
   ```bash
   flutter build apk --flavor prod --release
   ```

---

## 📂 Project Architecture

```text
lib/
├── main.dart           # Application entry point with flavor configuration
├── models/             # Immutable data models (User, Song, Playlist)
├── screen/             # UI layer (Search, Home, Player, Profile, Auth)
├── services/           # Business logic (Auth, Audio, Firestore, Download)
├── widgets/            # Reusable UI components & Design System tokens
└── theme/              # Centralized theme management (ThemeNotifier)
```

---

## 🔑 Technologies & Core Packages
- **Provider**: Robust state management.
- **Audio Service**: Flagship-grade background playback.
- **Palette Generator**: Real-time color extraction.
- **Firebase Auth & Firestore**: Atomic backend synchronization.
- **LRCLIB**: Dynamic synced lyrics integration.
- **SharedPreferences**: Persistent user customization.

---

## 🛡️ Stability & Security
TuneWave is built with stability in mind:
- **Null-Safe Network Images**: Robust validation for all remote assets to prevent URI host errors.
- **Secure Error Handling**: Technical Firebase exceptions are mapped to user-friendly messages.
- **Memory Optimization**: Efficient audio buffering and image caching.

---

## 🤝 Contributing
We welcome contributions! Please fork the repo and submit a PR for any features or bug fixes.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📄 License
Distributed under the **MIT License**. See `LICENSE` for more information.

---

## ⚖️ Legal Note
This project is for educational purposes. It utilizes an unofficial JioSaavn API. For commercial release, please acquire proper licensing.

---

**Made with ❤️ using Flutter**

🎵 **TuneWave - Your music, redefined.** 🎵
