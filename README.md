# 🎵 TuneWave v2.0

A premium, feature-rich music streaming application built with Flutter, designed for a seamless and immersive listening experience.

![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue.svg?style=for-the-badge&logo=flutter)
![Firebase](https://img.shields.io/badge/Firebase-v11.0+-orange.svg?style=for-the-badge&logo=firebase)
![Platform](https://img.shields.io/badge/Platform-Android-green.svg?style=for-the-badge&logo=android)
![License](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)

---

## ✨ Features

*   🎧 **High-Fidelity Streaming** - Access millions of tracks via JioSaavn API integrations.
*   🔍 **Advanced Search** - Instant results for songs, artists, and albums.
*   🔐 **Secure Authentication** - robust login/signup via **Email** and **Google Sign-In**.
*   💾 **Smart Offline Mode** - High-speed downloads with background processing for offline listening.
*   🎼 **Dynamic Lyrics** - Real-time synchronized lyrics for your favorite tracks.
*   🎨 **Premium UI/UX** - Modern, glassmorphic design with support for vibrant Dark and Light modes.
*   📋 **Personalized Collections** - Create, manage, and share your own playlists.
*   🔒 **Background Mastery** - Full background playback with lock screen controls and media notifications.
*   🎲 **Intelligent Shuffle** - Advanced randomization algorithm for a fresh experience every time.

---

## 🚀 Quick Start

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

## 🛡️ Stability & Security

TuneWave v2.0 is built with stability in mind:
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

**Made with ❤️ using Flutter**

🎵 **TuneWave - Your Music, Your Way** 🎵
