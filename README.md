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

### Prerequisites
- Flutter SDK `3.8.0+`
- Android SDK (API 21+)

### Quick Install
```bash
# Clone the repository
git clone https://github.com/Mohit-Javle/TuneWave-v2.0.git
cd TuneWave-v2.0

# Install dependencies
flutter pub get

# Launch on connected device
flutter run
```

---

## 🛠️ Project Architecture
```
lib/
├── main.dart             # App entry point & initialization
├── models/               # Data structures (Song, Album, etc.)
├── screen/               # High-fidelity UI screens
├── services/             # Core logic (MusicService, Atomic Sync, Migration)
└── widgets/              # Reusable premium components & animations
```

---

## 🔑 Technologies
- **Provider**: Robust state management.
- **Audio Service**: Flagship-grade background playback.
- **Palette Generator**: Real-time color extraction.
- **Firebase Auth & Firestore**: Atomic backend synchronization.
- **LRCLIB**: Dynamic synced lyrics integration.
- **SharedPreferences**: Persistent user customization.

---

## ⚖️ Legal Note
This project is for educational purposes. It utilizes an unofficial JioSaavn API. For commercial release, please acquire proper licensing.

---

**Made with ❤️ using Flutter**
🎵 **TuneWave - Your music, redefined.** 🎵
