// main.dart
// ignore_for_file: deprecated_member_use, unused_element

import 'package:clone_mp/widgets/global_mini_player.dart';

import 'package:clone_mp/services/music_service.dart';
import 'package:clone_mp/services/theme_notifier.dart';
import 'package:flutter/material.dart';
import 'package:clone_mp/screen/home_screen.dart';
import 'package:clone_mp/screen/library_screen.dart';
import 'package:clone_mp/screen/login_screen.dart';
import 'package:clone_mp/screen/music_screen.dart';
import 'package:clone_mp/screen/search_screen.dart';
import 'package:provider/provider.dart';
import 'package:clone_mp/screen/change_password_screen.dart';
import 'package:clone_mp/screen/about_screen.dart';
import 'package:clone_mp/screen/artist_detail_screen.dart';
import 'package:clone_mp/screen/album_detail_screen.dart';
import 'package:clone_mp/models/album_model.dart';
import 'package:clone_mp/screen/invite_friends_screen.dart';
import 'package:clone_mp/screen/splash_screen.dart';

import 'package:clone_mp/screen/profile_screen.dart';
import 'package:clone_mp/screen/liked_songs_screen.dart';
import 'package:clone_mp/screen/notification_screen.dart';
import 'package:clone_mp/screen/setting_screen.dart';
import 'package:clone_mp/services/playlist_service.dart';
import 'package:clone_mp/services/ui_state_service.dart';
import 'package:clone_mp/services/follow_service.dart';
import 'package:clone_mp/services/auth_service.dart';
import 'package:audio_service/audio_service.dart';
import 'package:clone_mp/services/audio_handler.dart';
import 'package:clone_mp/screen/queue_screen.dart';
import 'package:clone_mp/screen/recently_played_screen.dart';
import 'package:clone_mp/services/download_service.dart';
import 'package:clone_mp/screen/downloads_page.dart';


void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppBootstrapper());
}

class AppBootstrapper extends StatefulWidget {
  const AppBootstrapper({super.key});

  @override
  State<AppBootstrapper> createState() => _AppBootstrapperState();
}

class _AppBootstrapperState extends State<AppBootstrapper> {
  late Future<AudioHandler> _audioHandlerFuture;

  @override
  void initState() {
    super.initState();
    _audioHandlerFuture = _initAudioService();
  }

  Future<AudioHandler> _initAudioService() async {
    debugPrint("Initializing AudioService...");
    try {
      final handler = await AudioService.init(
        builder: () => AudioPlayerHandler(),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.ryanheise.myapp.channel.audio',
          androidNotificationChannelName: 'Audio playback',
          androidNotificationOngoing: true,
          androidNotificationIcon: 'mipmap/app_icon',
        ),
      );
      debugPrint("AudioService initialized successfully.");
      return handler;
    } catch (e) {
      debugPrint("Error initializing AudioService: $e");
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AudioHandler>(
      future: _audioHandlerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        
        if (snapshot.hasError) {
           return MaterialApp(
             debugShowCheckedModeBanner: false,
             home: Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text("Error initializing audio service:\n${snapshot.error}", textAlign: TextAlign.center),
                ),
              ),
            ),
          );
        }

        final audioHandler = snapshot.data!;
        
        final dlService = DownloadService();
        
        return MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => ThemeNotifier()),
              ChangeNotifierProvider(create: (_) => dlService..init()),
              ChangeNotifierProvider(create: (_) => MusicService(audioHandler, dlService)),
              ChangeNotifierProvider(create: (_) => PlaylistService()),
              ChangeNotifierProvider(create: (_) => AuthService()),
              ChangeNotifierProvider(create: (_) => FollowService()),
              ChangeNotifierProvider(create: (_) => UiStateService()),
            ],
            child: const MyApp(),
        );
      },
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryOrange = Color(0xFFFF6600);

    final lightTheme = ThemeData(
      brightness: Brightness.light,
      primaryColor: primaryOrange,
      colorScheme: ColorScheme.fromSwatch().copyWith(
        primary: primaryOrange,
        secondary: const Color(0xFFFF781F),
        background: Colors.white,
        surface: Colors.white,
        onBackground: Colors.black87,
        onSurface: Colors.black87,
      ),
      scaffoldBackgroundColor: Colors.white,
      fontFamily: 'Roboto',
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );

    final darkTheme = ThemeData(
      brightness: Brightness.dark,
      primaryColor: primaryOrange,
      colorScheme: ColorScheme.fromSwatch(brightness: Brightness.dark).copyWith(
        primary: primaryOrange,
        secondary: const Color(0xFFFF781F),
        background: const Color(0xFF121212),
        surface: const Color(0xFF1E1E1E),
        onBackground: Colors.white,
        onSurface: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
      fontFamily: 'Roboto',
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );

    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Music App',
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeNotifier.getThemeMode,
          home: const OnboardingPager(),
          initialRoute: '/splash',
          builder: (context, child) {
            return GlobalMiniPlayer(child: child ?? const SizedBox.shrink());
          },
          routes: {
            '/splash': (context) => const SplashScreen(),
            '/main': (context) => const MainScreen(),
            '/login': (context) => const OnboardingPager(),
            '/profile': (context) => const ProfileScreen(),
            '/liked_songs': (context) => const LikedSongsScreen(),
            '/settings': (context) => const SettingsScreen(),
            '/notifications': (context) => const NotificationScreen(),
            '/change_password': (context) => const ChangePasswordScreen(),
            '/about': (context) => const AboutScreen(),
            '/invite_friends': (context) => const InviteFriendsScreen(),
            '/queue': (context) => const QueueScreen(),
            '/recently_played': (context) => const RecentlyPlayedScreen(),
            '/downloads': (context) => const DownloadsPage(),
            '/artist': (context) => ArtistDetailScreen(
              artist: ModalRoute.of(context)!.settings.arguments as Map<String, String>,
            ),
            '/album': (context) => AlbumDetailScreen(
              album: ModalRoute.of(context)!.settings.arguments as AlbumModel,
            ),
          },
        );
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late final MusicService _musicService;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _musicService = context.read<MusicService>();
    _musicService.init();

    _musicService.currentSongNotifier.addListener(() => setState(() {}));
    _musicService.isPlayingNotifier.addListener(() => setState(() {}));
    _musicService.currentDurationNotifier.addListener(() => setState(() {}));
    _musicService.totalDurationNotifier.addListener(() => setState(() {}));

    // Listen for Playback Errors
    _musicService.errorMessageNotifier.addListener(() {
      final error = _musicService.errorMessageNotifier.value;
      if (error != null) {
        // Show error snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () {
                _musicService.play();
              },
            ),
          ),
        );
      }
    });

    _pages = [
      HomeScreen(
        onPlaySong: _playNewSong,
        currentSong: _musicService.currentSongNotifier.value,
        isPlaying: _musicService.isPlayingNotifier.value,
        onTogglePlayPause: _togglePlayPause,
      ),
      SearchScreen(onPlaySong: (song, playlist, index) {
        _playNewSong(song, playlist, index);
      }),
      const LibraryScreen(),
    ];

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      setState(() {
        _selectedIndex = index;
      });
      _animationController.reset();
      _animationController.forward();
    }
  }

  void _playNewSong(SongModel song, List<SongModel> playlist, int index) {
    // Load the full playlist so next/previous buttons work
    _musicService.loadPlaylist(playlist, index);
  }

  void _togglePlayPause() {
    if (_musicService.isPlayingNotifier.value) {
      _musicService.pause();
    } else {
      _musicService.play();
    }
  }



  @override
  Widget build(BuildContext context) {
    final uiStateService = Provider.of<UiStateService>(context);

    // Rebuild HomeScreen with current state
    _pages[0] = HomeScreen(
      onPlaySong: _playNewSong,
      onTogglePlayPause: _togglePlayPause,
      currentSong: _musicService.currentSongNotifier.value,
      isPlaying: _musicService.isPlayingNotifier.value,
    );

    return WillPopScope(
      onWillPop: () async {
        if (_selectedIndex != 0) {
          setState(() {
            _selectedIndex = 0;
          });
          return false;
        }
        return true;
      },
      child: Scaffold(
        key: _scaffoldKey,
        onDrawerChanged: (isOpened) {
          if (isOpened) {
            uiStateService.hideMiniPlayer();
          } else {
            uiStateService.showMiniPlayer();
          }
        },
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: _pages[_selectedIndex],
        ),
        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 10,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFFFF6600),
          unselectedItemColor: Theme.of(context).unselectedWidgetColor,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_filled),
              label: "Home",
            ),
            BottomNavigationBarItem(icon: Icon(Icons.search), label: "Search"),
            BottomNavigationBarItem(
              icon: Icon(Icons.library_music_sharp),
              label: "Library",
            ),
          ],
        ),
      ),
    );
  }

}
