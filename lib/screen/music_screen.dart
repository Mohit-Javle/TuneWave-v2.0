// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:clone_mp/services/api_service.dart';
import 'package:clone_mp/services/music_service.dart';
import 'package:clone_mp/services/playlist_service.dart';
import 'package:clone_mp/services/ui_state_service.dart';
import 'package:clone_mp/widgets/create_playlist_sheet.dart';
import 'package:clone_mp/widgets/download_button.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';

// Define a custom PopupMenuEntry for better styling
class _CustomPopupMenuItem<T> extends PopupMenuEntry<T> {
  const _CustomPopupMenuItem({
    required this.value,
    required this.icon,
    required this.text,
    this.onTap,
    super.key,
  });

  final T value;
  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  @override
  double get height => 48.0;

  @override
  bool represents(T? value) => this.value == value;

  @override
  State<_CustomPopupMenuItem<T>> createState() =>
      _CustomPopupMenuItemState<T>();
}

class _CustomPopupMenuItemState<T> extends State<_CustomPopupMenuItem<T>> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryTextColor = theme.colorScheme.onSurface;
    const Color primaryOrange = Color(0xFFFF6600);

    return InkWell(
      onTap: () {
        if (widget.onTap != null) {
          widget.onTap!();
        }
        Navigator.pop(context, widget.value);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
            Icon(widget.icon, color: primaryOrange),
            const SizedBox(width: 16),
            Text(
              widget.text,
              style: TextStyle(
                color: primaryTextColor,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MusicPlayerScreen extends StatefulWidget {
  const MusicPlayerScreen({super.key});

  @override
  State<MusicPlayerScreen> createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends State<MusicPlayerScreen>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  Future<String?>? _lyricsFuture;

  late final MusicService _musicService;
  final ApiService _apiService = ApiService();

  static const Color primaryOrange = Color(0xFFFF6600);
  static const Color lightestOrange = Color(0xFFFFAF7A);
  static const Color veryLightOrange = Color(0xFFFF9D5C);

  @override
  void initState() {
    super.initState();
    _musicService = context.read<MusicService>();

    _rotationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    );

    _musicService.isPlayingNotifier.addListener(_handlePlayerStateChange);
    _musicService.currentSongNotifier.addListener(_handleSongChange);

    if (_musicService.isPlayingNotifier.value) {
      _rotationController.repeat();
    }

    final currentSong = _musicService.currentSongNotifier.value;
    if (currentSong != null) {
      _fetchLyrics(currentSong);
    }
    
    // Hide global mini player logic moved to MiniPlayerObserver

  }

  void _fetchLyrics(SongModel song) {
    if (mounted) {
      setState(() {
        _lyricsFuture = _apiService.getLyrics(song.id);
      });
    }
  }

  void _handleSongChange() {
    final newSong = _musicService.currentSongNotifier.value;
    if (newSong != null) {
      _fetchLyrics(newSong);
    }
    if (mounted) setState(() {});
  }

  void _handlePlayerStateChange() {
    if (mounted) {
      final isPlaying = _musicService.isPlayingNotifier.value;
      if (isPlaying) {
        _rotationController.repeat();
      } else {
        _rotationController.stop();
      }
    }
  }

  @override
  void dispose() {
    _musicService.isPlayingNotifier.removeListener(_handlePlayerStateChange);
    _musicService.currentSongNotifier.removeListener(_handleSongChange);
    _rotationController.dispose();
    
    // Show global mini player logic moved to MiniPlayerObserver

    
    super.dispose();
  }

  Widget _buildTopBar(
    BuildContext context,
    Color textDark,
    Color iconColor,
    SongModel currentSong,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.keyboard_arrow_down, color: iconColor, size: 30),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Now Playing",
                  style: TextStyle(
                    color: textDark,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.queue_music, color: iconColor, size: 24),
                  onPressed: () {
                    Navigator.pushNamed(context, '/queue');
                  },
                  tooltip: 'View Queue',
                ),
              ],
            ),
          ),
          Theme(
            data: Theme.of(context).copyWith(
              cardColor: Theme.of(context).colorScheme.surface,
              popupMenuTheme: PopupMenuThemeData(
                color: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 8,
                textStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            child: PopupMenuButton<String>(
              onSelected: (String result) {
                if (result == 'about_artist') {
                  // Simplified artist interaction for now
                   ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Artist details coming soon!')),
                   );
                } else if (result == 'about_song') {
                  _showSongDetailsDialog(context, currentSong);
                } else if (result == 'add_to_playlist') {
                  _showAddToPlaylistOptions(context, currentSong);
                } else if (result == 'report') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Thank you for your report! We will investigate.',
                      ),
                      backgroundColor: primaryOrange,
                    ),
                  );
                }
              },
              icon: Icon(Icons.more_horiz, color: iconColor, size: 30),
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                _CustomPopupMenuItem<String>(
                  value: 'add_to_playlist',
                  icon: Icons.playlist_add,
                  text: 'Add to a Playlist',
                ),
                _CustomPopupMenuItem<String>(
                  value: 'about_artist',
                  icon: Icons.person_outline,
                  text: 'About Artist',
                ),
                _CustomPopupMenuItem<String>(
                  value: 'about_song',
                  icon: Icons.info_outline,
                  text: 'About Song',
                ),
                const PopupMenuDivider(color: Colors.black),
                _CustomPopupMenuItem<String>(
                  value: 'report',
                  icon: Icons.flag_outlined,
                  text: 'Report Something',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final musicService = context.watch<MusicService>();
    final playlistService = context.watch<PlaylistService>();

    final theme = Theme.of(context);
    final textDark = theme.colorScheme.onSurface;
    final textLight = theme.colorScheme.onSurface.withOpacity(0.7);
    final iconColor = theme.unselectedWidgetColor;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: theme.brightness == Brightness.light
                ? [Colors.white, const Color.fromARGB(100, 255, 218, 192)]
                : [theme.colorScheme.surface, theme.colorScheme.background],
            stops: const [0.3, 0.7],
          ),
        ),
        child: (() {
          final currentSong = musicService.currentSongNotifier.value;
          if (currentSong == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final isLiked = playlistService.isLiked(currentSong);

          return SafeArea(
            child: Column(
              children: [
                _buildTopBar(context, textDark, iconColor, currentSong),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        const SizedBox(height: 20),
                        AnimatedBuilder(
                          animation: _rotationController,
                          builder: (context, child) {
                            return GestureDetector(
                              onDoubleTapDown: (details) {
                                // Determine if tap is on left or right side
                                final RenderBox box = context.findRenderObject() as RenderBox;
                                final localPosition = box.globalToLocal(details.globalPosition);
                                final width = box.size.width;
                                
                                if (localPosition.dx < width / 2) {
                                  // Left side - previous
                                  _showSkipFeedback(context, false);
                                  musicService.playPrevious();
                                } else {
                                  // Right side - next
                                  _showSkipFeedback(context, true);
                                  musicService.playNext();
                                }
                              },
                              child: Transform.rotate(
                                angle: _rotationController.value * 2 * math.pi,
                                child: Container(
                                  width: 280,
                                  height: 280,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: theme.shadowColor.withOpacity(
                                          0.15,
                                        ),
                                        blurRadius: 20,
                                        spreadRadius: 5,
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: Image.network(
                                      currentSong.imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Container(color: Colors.grey),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 40),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      currentSong.name,
                                      style: TextStyle(
                                        color: textDark,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      currentSong.artist,
                                      style: TextStyle(
                                        color: textLight,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  playlistService.toggleLike(currentSong);
                                },
                                icon: Icon(
                                  isLiked
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: isLiked ? Colors.red : iconColor,
                                  size: 28,
                                ),
                              ),
                              DownloadButton(
                                song: currentSong,
                                size: 28,
                                color: iconColor,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildControls(
                          context,
                          theme,
                          textDark,
                          textLight,
                          iconColor,
                          musicService,
                        ),
                        const SizedBox(height: 40),
                        _buildLyricsSection(theme),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        })(),
      ),
    );
  }

  Widget _buildControls(
    BuildContext context,
    ThemeData theme,
    Color textDark,
    Color textLight,
    Color iconColor,
    MusicService musicService,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              ValueListenableBuilder<Duration>(
                valueListenable: musicService.totalDurationNotifier,
                builder: (context, totalDuration, _) {
                  return ValueListenableBuilder<Duration>(
                    valueListenable: musicService.currentDurationNotifier,
                    builder: (context, currentDuration, _) {
                      double sliderValue = (totalDuration.inMilliseconds > 0)
                          ? (currentDuration.inMilliseconds /
                                totalDuration.inMilliseconds)
                          : 0.0;
                      return Column(
                        children: [
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: primaryOrange,
                              inactiveTrackColor:
                                  theme.brightness == Brightness.light
                                  ? lightestOrange
                                  : Colors.white30,
                              thumbColor: primaryOrange,
                              overlayColor: primaryOrange.withOpacity(0.2),
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6,
                              ),
                            ),
                            child: Slider(
                              value: sliderValue.clamp(0.0, 1.0),
                              onChanged: (value) {
                                final newPosition = Duration(
                                  seconds: (totalDuration.inSeconds * value)
                                      .round(),
                                );
                                musicService.seek(newPosition);
                              },
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(currentDuration),
                                style: TextStyle(
                                  color: textLight,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                _formatDuration(totalDuration),
                                style: TextStyle(
                                  color: textLight,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: musicService.isShuffleNotifier,
                builder: (context, isShuffle, _) {
                  return IconButton(
                    onPressed: musicService.toggleShuffle,
                    icon: Icon(
                      Icons.shuffle,
                      color: isShuffle ? primaryOrange : iconColor,
                      size: 30,
                    ),
                  );
                },
              ),
              IconButton(
                onPressed: musicService.playPrevious,
                icon: Icon(Icons.skip_previous, color: textDark, size: 40),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: musicService.isPlayingNotifier,
                builder: (context, isPlaying, _) {
                  return Container(
                    width: 70,
                    height: 70,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: primaryOrange,
                    ),
                    child: IconButton(
                      onPressed: () {
                        if (isPlaying) {
                          musicService.pause();
                        } else {
                          musicService.play();
                        }
                      },
                      icon: Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                onPressed: musicService.playNext,
                icon: Icon(Icons.skip_next, color: textDark, size: 40),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: musicService.isRepeatNotifier,
                builder: (context, isRepeat, _) {
                  return IconButton(
                    onPressed: musicService.toggleRepeat,
                    icon: Icon(
                      Icons.repeat,
                      color: isRepeat ? primaryOrange : iconColor,
                      size: 30,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLyricsSection(ThemeData theme) {
    Widget centeredMessage(String message) {
      return Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Lyrics",
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 400,
            child: FutureBuilder<String?>(
              future: _lyricsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: primaryOrange),
                  );
                }

                if (snapshot.hasError) {
                  return centeredMessage("Error loading lyrics.");
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty || snapshot.data == 'No lyrics found.') {
                  return centeredMessage("Lyrics not found for this song.");
                }

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 16.0,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      snapshot.data!,
                      textAlign: TextAlign.start,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.8),
                        fontSize: 16,
                        height: 1.6,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  void _showSongDetailsDialog(BuildContext context, SongModel song) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Text(
            "About This Song",
            style: TextStyle(color: primaryOrange, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  "Title: ${song.name}",
                  style: TextStyle(color: theme.colorScheme.onSurface),
                ),
                const SizedBox(height: 8),
                Text(
                  "Artist: ${song.artist}",
                  style: TextStyle(color: theme.colorScheme.onSurface),
                ),
                const SizedBox(height: 8),
                Text(
                  "Album: ${song.album}",
                  style: TextStyle(color: theme.colorScheme.onSurface),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                "Close",
                style: TextStyle(color: primaryOrange),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAddToPlaylistOptions(BuildContext context, SongModel song) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Consumer<PlaylistService>(
          builder: (context, playlistService, child) {
            final playlists = playlistService.playlists;
            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    'Add to Playlist',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: veryLightOrange.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.add, color: primaryOrange),
                    ),
                    title: const Text('Create New Playlist'),
                    onTap: () {
                      Navigator.pop(context);
                      CreatePlaylistSheet.show(context);
                    },
                  ),
                  Expanded(
                    child: playlists.isEmpty
                          ? Center(
                              child: Text(
                                "You don't have any playlists yet.",
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: playlists.length,
                              itemBuilder: (context, index) {
                                final playlist = playlists[index];
                                final songCount = playlist.songs.length;
                                return ListTile(
                                  leading: const Icon(Icons.playlist_play),
                                  title: Text(playlist.name),
                                  subtitle: Text('$songCount songs'),
                                  onTap: () {
                                    playlistService.addSongsToPlaylist(
                                      playlist.id,
                                      [song],
                                    );
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Added to ${playlist.name}',
                                          style: const TextStyle(color: Colors.white),
                                        ),
                                        backgroundColor: primaryOrange,
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSkipFeedback(BuildContext context, bool isNext) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 400),
            onEnd: () => overlayEntry.remove(),
            builder: (context, value, child) {
              return Opacity(
                opacity: 1.0 - value,
                child: Transform.scale(
                  scale: 1.0 + (value * 0.5),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: primaryOrange.withOpacity(0.9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isNext ? Icons.skip_next : Icons.skip_previous,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    
    overlay.insert(overlayEntry);
  }
}
