import 'package:clone_mp/services/music_service.dart';
import 'package:clone_mp/services/ui_state_service.dart';
import 'package:clone_mp/screen/music_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// A globally visible mini player that overlays on top of all routes.
/// This widget is placed in the MaterialApp builder so it persists
/// across all Navigator route transitions.
class GlobalMiniPlayer extends StatelessWidget {
  final Widget child;

  const GlobalMiniPlayer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final musicService = context.watch<MusicService>();
    final uiStateService = context.watch<UiStateService>();

    final currentSong = musicService.currentSongNotifier.value;
    final isPlaying = musicService.isPlayingNotifier.value;
    final showMiniPlayer = uiStateService.isMiniPlayerVisible && currentSong != null;

    return Stack(
      children: [
        child,
        if (showMiniPlayer)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _MiniPlayerBar(
              song: currentSong!,
              isPlaying: isPlaying,
              musicService: musicService,
            ),
          ),
      ],
    );
  }
}

class _MiniPlayerBar extends StatelessWidget {
  final SongModel song;
  final bool isPlaying;
  final MusicService musicService;

  const _MiniPlayerBar({
    required this.song,
    required this.isPlaying,
    required this.musicService,
  });

  void _togglePlayPause() {
    if (isPlaying) {
      musicService.pause();
    } else {
      musicService.play();
    }
  }

  void _navigateToMusicPlayer(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MusicPlayerScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalDuration = musicService.totalDurationNotifier.value;
    final currentPosition = musicService.currentDurationNotifier.value;

    return GestureDetector(
      onTap: () => _navigateToMusicPlayer(context),
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity!;
        if (velocity < -500) {
          musicService.playNext();
        } else if (velocity > 500) {
          musicService.playPrevious();
        }
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 8.0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
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
                      color: theme.colorScheme.primary.withOpacity(0.2),
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
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
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
              backgroundColor: theme.unselectedWidgetColor.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF6600)),
              minHeight: 3,
            ),
          ],
        ),
      ),
    );
  }
}
