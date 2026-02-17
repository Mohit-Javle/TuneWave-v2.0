# 🎵 TuneWave v2.0

A feature-rich, cross-platform music streaming application built with Flutter.

![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue.svg)
![Dart](https://img.shields.io/badge/Dart-3.0+-blue.svg)
![Platform](https://img.shields.io/badge/Platform-Android-green.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

---

## ✨ Features

🎧 **Stream Music** - High-quality music from JioSaavn API  
🔍 **Smart Search** - Find songs, artists, and albums instantly  
🎼 **Lyrics Display** - Real-time synchronized lyrics  
📱 **Queue Management** - Full control over playback queue  
🎲 **Smart Shuffle** - Intelligent randomization  
⏱️ **Recently Played** - Track your listening history  
💾 **Offline Downloads** - Download songs for offline listening  
🎨 **Beautiful UI** - Modern design with dark/light themes  
📋 **Playlists** - Create and manage your collections  
🔒 **Background Playback** - Music continues when app is minimized  
🎛️ **Lock Screen Controls** - Control playback from anywhere  

---

## 🚀 Quick Start

### Prerequisites
- Flutter SDK 3.0+
- Android Studio or VS Code
- Android SDK (API 21+)

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/TuneWave-v2.0.git
cd TuneWave-v2.0-main

# Install dependencies
flutter pub get

# Run the app
flutter run
```

### Build APK

```bash
# Debug APK
flutter build apk --debug

# Release APK (recommended)
flutter build apk --split-per-abi --release

# App Bundle for Play Store
flutter build appbundle --release
```

---

## 📖 Documentation

For complete documentation including:
- Detailed setup instructions
- Project architecture
- Optimization guide
- Troubleshooting
- Customization options
- Deployment guide

**👉 See [DOCS.md](DOCS.md)**

---

## 📂 Project Structure

```
TuneWave-v2.0-main/
├── android/          # Android platform files
├── lib/
│   ├── main.dart     # App entry point
│   ├── models/       # Data models
│   ├── screen/       # UI screens
│   ├── services/     # Business logic
│   └── widgets/      # Reusable components
├── assets/           # Images, fonts
├── test/             # Tests
└── pubspec.yaml      # Dependencies
```

---

## 🔑 Key Technologies

- **Flutter & Dart** - Cross-platform framework
- **Provider** - State management
- **audio_service** - Background audio playback
- **audioplayers** - Audio playback engine
- **SharedPreferences** - Local storage
- **JioSaavn API** - Music data source

---

## ⚠️ Legal Notice

This project uses an unofficial JioSaavn API for educational purposes. For commercial use, obtain proper licensing or use official APIs.

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the project
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License.

---

## 📞 Support

- 🐛 Report bugs: [GitHub Issues](https://github.com/yourusername/TuneWave-v2.0/issues)
- 📧 Email: support@tunewave.app

---

## 🙏 Acknowledgments

- JioSaavn for music data
- Flutter community
- All contributors

---

**Made with ❤️ using Flutter**

🎵 **Happy Listening!** 🎵
