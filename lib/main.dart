// main.dart
// ignore_for_file: deprecated_member_use, unused_element

import 'package:clone_mp/widgets/global_mini_player.dart';
import 'package:clone_mp/route_names.dart';
import 'package:clone_mp/route_observer.dart';

import 'package:clone_mp/services/music_service.dart';
import 'package:clone_mp/services/theme_notifier.dart';
import 'package:flutter/material.dart';
import 'package:clone_mp/screen/home_screen.dart';
import 'package:clone_mp/screen/library_screen.dart';
import 'package:clone_mp/screen/login_screen.dart';

import 'package:clone_mp/screen/search_screen.dart';
import 'package:clone_mp/screen/playlist_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:clone_mp/screen/change_password_screen.dart';
import 'package:clone_mp/screen/about_screen.dart';
import 'package:clone_mp/screen/artist_detail_screen.dart';
import 'package:clone_mp/screen/album_detail_screen.dart';
import 'package:clone_mp/models/album_model.dart';
import 'package:clone_mp/screen/invite_friends_screen.dart';
import 'package:clone_mp/screen/splash_screen.dart';

import 'package:clone_mp/screen/profile_screen.dart';
import 'package:clone_mp/screen/following_artists_screen.dart';
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
import 'package:clone_mp/services/personalization_service.dart';
import 'package:clone_mp/services/spotify_import_service.dart';
import 'package:clone_mp/services/api_service.dart';
import 'package:flutter/services.dart';
import 'package:clone_mp/screens/personalization/personalization_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Global Key for Navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  // Enable offline persistence
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);
  
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
      debugPrint("⚠️ CRITICAL: AudioService initialization failed: $e");
      debugPrint(
        "Background audio notifications may not work. Check MainActivity extends AudioServiceFragmentActivity.",
      );
      // Return fallback handler to allow app to launch
      return AudioPlayerHandler();
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
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }

        // FALLBACK: If error, use local handler to allow app launch
        final AudioHandler audioHandler;
        if (snapshot.hasError || snapshot.data == null) {
          debugPrint(
            "AudioService Init Failed: ${snapshot.error} - Using Fallback",
          );
          audioHandler = AudioPlayerHandler();
        } else {
          audioHandler = snapshot.data!;
        }

        final dlService = DownloadService();

        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeNotifier()),
            ChangeNotifierProvider(create: (_) => dlService..init()),
            ChangeNotifierProvider(
              create: (_) => MusicService(audioHandler, dlService, ApiService())..init(),
            ),
            ChangeNotifierProvider(create: (_) => PlaylistService()),
            ChangeNotifierProvider(create: (_) => AuthService()),
            ChangeNotifierProvider(create: (_) => FollowService()),
            ChangeNotifierProvider(create: (_) => UiStateService()),
            ChangeNotifierProvider(create: (_) => PersonalizationService()),
            ChangeNotifierProvider(
              create: (context) => SpotifyImportService(
                Provider.of<PlaylistService>(context, listen: false),
              ),
            ),
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
        // Capture services BEFORE MaterialApp to use in builder
        final musicService = context.read<MusicService>();

        return MaterialApp(
          navigatorKey: navigatorKey,
          navigatorObservers: [appRouteObserver],
          debugShowCheckedModeBanner: false,
          title: 'Music App',
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeNotifier.getThemeMode,
          home: const OnboardingPager(),
          initialRoute: AppRoutes.splash,
          builder: (context, child) {
            return ValueListenableBuilder<String?>(
              valueListenable: appRouteObserver.currentRouteNotifier,
              builder: (context, currentRoute, _) {
                // Determine if we should show the global mini player wrapper.
                // We hide it on splash, root (/), login, and personalization screens.
                final isStartupRoute = currentRoute == null || 
                                      currentRoute == AppRoutes.splash || 
                                      currentRoute == AppRoutes.root ||
                                      currentRoute == AppRoutes.login ||
                                      currentRoute == AppRoutes.personalization;

                if (isStartupRoute) {
                  return child ?? const SizedBox.shrink();
                }

                return GlobalMiniPlayer(
                  navigatorKey: navigatorKey,
                  musicService: musicService,
                  child: child ?? const SizedBox.shrink(),
                );
              },
            );
          },
          routes: {
            AppRoutes.splash: (context) => const SplashScreen(),
            AppRoutes.main: (context) => const MainScreen(),
            AppRoutes.login: (context) => const OnboardingPager(),
            AppRoutes.profile: (context) => const ProfileScreen(),
            AppRoutes.likedSongs: (context) => const LikedSongsScreen(),
            AppRoutes.settings: (context) => const SettingsScreen(),
            AppRoutes.notifications: (context) => const NotificationScreen(),
            AppRoutes.changePassword: (context) => const ChangePasswordScreen(),
            AppRoutes.about: (context) => const AboutScreen(),
            AppRoutes.inviteFriends: (context) => const InviteFriendsScreen(),
            AppRoutes.queue: (context) => const QueueScreen(),
            AppRoutes.recentlyPlayed: (context) => const RecentlyPlayedScreen(),
            AppRoutes.downloads: (context) => const DownloadsPage(),
            AppRoutes.personalization: (context) => const PersonalizationScreen(),
            AppRoutes.artist: (context) => ArtistDetailScreen(
              artist:
                  ModalRoute.of(context)!.settings.arguments
                      as Map<String, String>,
            ),
            AppRoutes.followingArtists: (context) => const FollowingArtistsScreen(),
            AppRoutes.album: (context) => AlbumDetailScreen(
              album: ModalRoute.of(context)!.settings.arguments as AlbumModel,
            ),
            AppRoutes.playlist: (context) => PlaylistDetailScreen(
              playlist: ModalRoute.of(context)!.settings.arguments as Playlist,
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
  final List<int> _navigationHistory = [0]; // Added to track tab visits
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Pages for bottom navigation tabs
  late List<Widget> _pages;

  late final MusicService _musicService;

  @override
  void initState() {
    super.initState();
    _musicService = Provider.of<MusicService>(context, listen: false);

    // Mark app as initialized and show the mini player
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uiStateService = Provider.of<UiStateService>(context, listen: false);
      final playlistService = Provider.of<PlaylistService>(context, listen: false);
      
      uiStateService.unlockMiniPlayer();
      uiStateService.setAppInitialized(true);

      // AUTO-SYNC SESSION:
      // Ensure user data is loaded if they are already logged in
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null && firebaseUser.email != null) {
        playlistService.loadUserData(firebaseUser.email!);
      }
    });

    _pages = [
      const SizedBox.shrink(),
      SearchScreen(onPlaySong: _playNewSong),
      const LibraryScreen(),
    ];

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
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
      Provider.of<UiStateService>(context, listen: false).setTabIndex(index);
      
      setState(() {
        _selectedIndex = index;
        
        // Update history: avoid consecutive duplicates
        if (_navigationHistory.isEmpty || _navigationHistory.last != index) {
          _navigationHistory.add(index);
        }
      });
      _animationController.reset();
      _animationController.forward();
    }
  }

  void _playNewSong(SongModel song, List<SongModel> playlist, int index) {
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
    
    // Sync local selected index with service
    if (_selectedIndex != uiStateService.currentTabIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
           _selectedIndex = uiStateService.currentTabIndex;
           if (_navigationHistory.isEmpty || _navigationHistory.last != _selectedIndex) {
             _navigationHistory.add(_selectedIndex);
           }
        });
        _animationController.reset();
        _animationController.forward();
      });
    }

    // Rebuild HomeScreen with current state
    _pages[0] = HomeScreen(
      onPlaySong: _playNewSong,
      onTogglePlayPause: _togglePlayPause,
    );

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        // If drawer is open, close it
        if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
          _scaffoldKey.currentState?.closeDrawer();
          return;
        }

        if (_navigationHistory.length > 1) {
          // Navigating back through the tab history
          setState(() {
            _navigationHistory.removeLast(); // Remove current
            _selectedIndex = _navigationHistory.last; // Go to previous
            // Sync service so Snap-Back doesn't trigger
            uiStateService.setTabIndex(_selectedIndex);
          });
          _animationController.reset();
          _animationController.forward();
          return;
        } 
        
        // If we are at the root (Home), minimize app to background (Spotify-like)
        try {
          // Standard system pop (usually backgrounds on modern Android)
          await SystemNavigator.pop();
        } catch (e) {
          // Fail-safe native method
          const MethodChannel('com.tunewave.app/apk_share').invokeMethod('moveTaskToBack');
        }
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
