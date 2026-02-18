
import 'package:clone_mp/services/music_service.dart';
import 'package:clone_mp/services/ui_state_service.dart';
import 'package:clone_mp/screen/music_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:clone_mp/route_names.dart';
import 'package:clone_mp/route_observer.dart';

/// A globally visible mini player that overlays on top of routes.
/// Uses a simple approach: show when there's a song and we're not on player screen.
class GlobalMiniPlayer extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;
  final MusicService musicService;

  const GlobalMiniPlayer({
    super.key, 
    required this.child,
    required this.navigatorKey,
    required this.musicService,
  });

  @override
  State<GlobalMiniPlayer> createState() => _GlobalMiniPlayerState();
}

class _GlobalMiniPlayerState extends State<GlobalMiniPlayer> {
  bool _shouldHideMiniPlayer(String? route) {
    const hiddenRoutes = [
      AppRoutes.settings,
      AppRoutes.profile,
      AppRoutes.about,
      AppRoutes.inviteFriends,
      AppRoutes.changePassword,
      AppRoutes.personalization,
    ];
    return hiddenRoutes.contains(route);
  }

  @override
  Widget build(BuildContext context) {
    // Get UiStateService for drawer state
    final uiStateService = context.watch<UiStateService>();
    
    return ValueListenableBuilder<SongModel?>(
      valueListenable: widget.musicService.currentSongNotifier,
      builder: (context, currentSong, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: widget.musicService.isPlayingNotifier,
          builder: (context, isPlaying, _) {
            return ValueListenableBuilder<String?>(
              valueListenable: appRouteObserver.currentRouteNotifier,
              builder: (context, currentRoute, _) {
                // Check if we're on the player screen
                final isOnPlayerScreen = currentRoute == AppRoutes.player;
                
                // Show mini player when:
                // 1. There's a song playing
                // 2. We're not on the player screen
                // 3. The drawer is not open (uiStateService.isMiniPlayerVisible)
                // 4. Not on drawer preference screens
                final showMiniPlayer = currentSong != null && 
                                       !isOnPlayerScreen && 
                                       !_shouldHideMiniPlayer(currentRoute) &&
                                       uiStateService.isMiniPlayerVisible;
                
                // Determine bottom padding based on current route
                // Also add keyboard height so it sits above keyboard
                final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
                final bottomPadding = _getBottomPadding(context, currentRoute) + keyboardHeight;
    
                return Stack(
                  children: [
                    // App content (Navigator)
                    widget.child,
                    
                    // Mini Player
                    if (showMiniPlayer)
                      Positioned(
                        bottom: bottomPadding,
                        left: 0,
                        right: 0,
                        child: SafeArea(
                          top: false,
                          bottom: bottomPadding == 0,
                          child: _MiniPlayerBar(
                            song: currentSong,
                            isPlaying: isPlaying,
                            musicService: widget.musicService,
                            navigatorKey: widget.navigatorKey,
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
  
  double _getBottomPadding(BuildContext context, String? route) {
    // If keyboard is open, we don't need the extra 80px padding
    // because the keyboard itself pushes the content up.
    // We add keyboard height in the build method, so here we return 0.
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    if (keyboardOpen) {
      return 0.0;
    }

    if (route == AppRoutes.main || route == AppRoutes.root) {
      return 80.0;
    }
    return 0.0;
  }
}

class _MiniPlayerBar extends StatelessWidget {
  final SongModel song;
  final bool isPlaying;
  final MusicService musicService;
  final GlobalKey<NavigatorState> navigatorKey;

  const _MiniPlayerBar({
    required this.song,
    required this.isPlaying,
    required this.musicService,
    required this.navigatorKey,
  });

  void _togglePlayPause() {
    if (isPlaying) {
      musicService.pause();
    } else {
      musicService.play();
    }
  }

  void _navigateToMusicPlayer() {
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => const MusicPlayerScreen(),
        settings: const RouteSettings(name: AppRoutes.player),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ValueListenableBuilder<Duration>(
      valueListenable: musicService.totalDurationNotifier,
      builder: (context, totalDuration, _) {
        return ValueListenableBuilder<Duration>(
          valueListenable: musicService.currentDurationNotifier,
          builder: (context, currentPosition, _) {
            return GestureDetector(
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity < -500) {
                  musicService.playNext();
                } else if (velocity > 500) {
                  musicService.playPrevious();
                }
              },
              child: Container(
                margin: const EdgeInsets.fromLTRB(8.0, 0.0, 8.0, 8.0),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: _navigateToMusicPlayer,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  song.imageUrl,
                                  width: 45,
                                  height: 45,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    width: 45,
                                    height: 45,
                                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                                    child: Icon(
                                      Icons.music_note,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      song.name,
                                      style: TextStyle(
                                        color: theme.colorScheme.onSurface,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      song.artist,
                                      style: TextStyle(
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: _togglePlayPause,
                                icon: Icon(
                                  isPlaying
                                      ? Icons.pause_circle_filled
                                      : Icons.play_circle_filled,
                                  color: const Color(0xFFFF6600),
                                  size: 32,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          LinearProgressIndicator(
                            value: (totalDuration.inMilliseconds > 0)
                                ? currentPosition.inMilliseconds / totalDuration.inMilliseconds
                                : 0.0,
                            backgroundColor: theme.unselectedWidgetColor.withValues(alpha: 0.2),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF6600)),
                            minHeight: 3,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
