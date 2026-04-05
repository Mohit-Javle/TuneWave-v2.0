// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:clone_mp/services/music_service.dart';
import 'package:clone_mp/services/playlist_service.dart';
import 'package:clone_mp/services/theme_notifier.dart';

import 'package:clone_mp/widgets/create_playlist_sheet.dart';
import 'package:clone_mp/widgets/download_button.dart';
import 'package:clone_mp/widgets/synced_lyrics_widget.dart';
import 'package:flutter/material.dart';
import 'package:clone_mp/route_names.dart';
import 'dart:math' as math;
import 'package:clone_mp/widgets/music_toast.dart';
import 'package:clone_mp/widgets/song_info_dialog.dart';
import 'package:clone_mp/widgets/share_card_widget.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:ui' as ui;
import 'dart:io';
import 'dart:typed_data';
import 'package:provider/provider.dart';
import 'package:flutter/rendering.dart';

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
  final GlobalKey _shareCardKey = GlobalKey();
  bool _isSharing = false;

  late final MusicService _musicService;

  static const Color primaryOrange = Color(0xFFFF6600);

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

    // Hide global mini player logic moved to MiniPlayerObserver
  }

  void _handleSongChange() {
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
                    Navigator.pushNamed(context, AppRoutes.queue);
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
                  final artistId = currentSong.artistId;
                  if (artistId != null && artistId.isNotEmpty) {
                    Navigator.pushNamed(
                      context, 
                      AppRoutes.artist, 
                      arguments: {
                        'id': artistId,
                        'name': currentSong.artist,
                        'image': '', // Don't pass song image for artist profile
                      },
                    );
                  } else {
                    showMusicToast(context, 'Artist details unavailable', type: ToastType.error);
                  }
                } else if (result == 'about_song') {
                  _showSongDetailsDialog(context, currentSong);
                } else if (result == 'add_to_playlist') {
                  _showAddToPlaylistOptions(context, currentSong);
                } else if (result == 'share') {
                  _shareSongAsImage(context, currentSong);
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
                  value: 'share',
                  icon: Icons.share_outlined,
                  text: 'Share',
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
    final textLight = theme.colorScheme.onSurface.withValues(alpha: 0.7);
    final iconColor = theme.unselectedWidgetColor;

    return Scaffold(
      body: ValueListenableBuilder<Color?>(
        valueListenable: musicService.currentAccentColorNotifier,
        builder: (context, accentColor, _) {
          final Color topColor = accentColor?.withValues(alpha: 0.6) ?? 
                               (theme.brightness == Brightness.light ? Colors.white : theme.colorScheme.surface);
          final Color bottomColor = accentColor?.withValues(alpha: 0.2) ?? 
                                 (theme.brightness == Brightness.light ? const Color.fromARGB(100, 255, 218, 192) : theme.colorScheme.background);

          return AnimatedContainer(
            duration: const Duration(milliseconds: 800),
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [topColor, bottomColor],
                stops: const [0.1, 0.9],
              ),
            ),
            child: Stack(
              children: [
                // Hidden Share Card for capture (Rendered behind the main UI)
                Opacity(
                  opacity: 0.01, // Nearly invisible but FORCES rendering
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      key: _shareCardKey,
                      child: Builder(
                        builder: (context) {
                            final song = musicService.currentSongNotifier.value;
                            if (song == null) return const SizedBox();
                            return ShareCardWidget(
                              song: song,
                              accentColor: accentColor,
                            );
                          }
                        ),
                      ),
                    ),
                  ),
                // Main UI
                (() {
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
                                _buildArtAndControls(context, currentSong, accentColor, theme, musicService, textDark, textLight, iconColor, isLiked, playlistService),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                })(),
                // Sharing Overlay
                if (_isSharing)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: primaryOrange),
                          SizedBox(height: 20),
                          Text(
                            'Generating your shareable card...',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
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
    Color? accentColor,
  ) {
    final effectiveAccentColor = accentColor ?? primaryOrange;
    return Column(
      children: [
        const SizedBox(height: 10),
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
                              activeTrackColor: effectiveAccentColor.computeLuminance() < 0.2 
                                  ? Color.alphaBlend(effectiveAccentColor.withValues(alpha: 0.5), Colors.white70)
                                  : effectiveAccentColor,
                              inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
                              thumbColor: Colors.white, // Always white thumb for maximum contrast
                              overlayColor: effectiveAccentColor.withValues(alpha: 0.2),
                              trackHeight: 4,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 7,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 15,
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
                      color: isShuffle ? effectiveAccentColor : iconColor,
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
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: effectiveAccentColor,
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
                      color: isRepeat ? effectiveAccentColor : iconColor,
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

  Widget _buildLyricsSection(ThemeData theme, SongModel currentSong) {
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
          SyncedLyricsWidget(song: currentSong),
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
    SongInfoDialog.show(context, song);
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
                        color: primaryOrange.withValues(alpha: 0.5),
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
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.7),
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
                                  showMusicToast(
                                    context,
                                    'Added to ${playlist.name}',
                                    type: ToastType.success,
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
                      color: primaryOrange.withValues(alpha: 0.9),
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

  // --- SHARING ENGINE ---
  
  Future<void> _shareSongAsImage(BuildContext context, SongModel song) async {
    setState(() => _isSharing = true);
    
    try {
      // 1. Ensure artwork is in memory (don't let this crash the process)
      try {
        await precacheImage(NetworkImage(song.imageUrl), context).timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint("Precache skipped/failed: $e");
      }
      
      // 2. Extra time for the widget tree to settle
      await Future.delayed(const Duration(milliseconds: 800));

      // 3. Ensure we have a valid capture context
      final RenderRepaintBoundary? boundary = 
          _shareCardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) {
        throw Exception("Capture area not found. Please try again.");
      }

      // 4. Capture the image (Safety check for memory)
      final ui.Image image = await boundary.toImage(pixelRatio: 1.5); // Fast & Safe quality
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) {
        throw Exception("Byte data conversion failed");
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // 3. Save to temporary directory
      final String tempPath = (await getTemporaryDirectory()).path;
      final File imgFile = File('$tempPath/tunewave_share_${DateTime.now().millisecondsSinceEpoch}.png');
      await imgFile.writeAsBytes(pngBytes);

      // 4. Trigger system share
      setState(() => _isSharing = false);
      
      await Share.shareXFiles(
        [XFile(imgFile.path)],
        text: 'Check out "${song.name}" by ${song.artist} on TuneWave! 🎧',
      );

    } catch (e) {
      if (mounted) setState(() => _isSharing = false);
      debugPrint("Sharing Error Details: $e");
      
      // Detailed feedback for debugging
      String errorMsg = 'Sharing Error: ${e.toString().split(':').last.trim()}';
      if (e.toString().contains('boundary')) errorMsg = 'App is busy. Wait a second and try again.';
      
      showMusicToast(context, errorMsg, type: ToastType.error);
    }
  }

  // Extracted UI builder to separate concerns and handle hidden ShareCard
  Widget _buildArtAndControls(
    BuildContext context, 
    SongModel currentSong, 
    Color? accentColor, 
    ThemeData theme, 
    MusicService musicService,
    Color textDark,
    Color textLight,
    Color iconColor,
    bool isLiked,
    PlaylistService playlistService,
  ) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _rotationController,
          builder: (context, child) {
            return GestureDetector(
              onDoubleTapDown: (details) {
                final RenderBox box = context.findRenderObject() as RenderBox;
                final localPosition = box.globalToLocal(details.globalPosition);
                final width = box.size.width;

                if (localPosition.dx < width / 2) {
                  _showSkipFeedback(context, false);
                  musicService.playPrevious();
                } else {
                  _showSkipFeedback(context, true);
                  musicService.playNext();
                }
              },
              child: Consumer<ThemeNotifier>(
                builder: (context, themeNotifier, _) {
                  final bool isDisc = themeNotifier.isDiscStyle;
                  const double artSize = 280.0;
                  
                  if (isDisc) {
                    return Transform.rotate(
                      angle: _rotationController.value * 2 * math.pi,
                      child: Container(
                        width: artSize,
                        height: artSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (accentColor ?? theme.shadowColor).withValues(alpha: 0.3),
                              blurRadius: 30,
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
                    );
                  } else {
                    return Container(
                      width: artSize,
                      height: artSize,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: (accentColor ?? theme.shadowColor).withValues(alpha: 0.3),
                            blurRadius: 30,
                            spreadRadius: 5,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.network(
                          currentSong.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(color: Colors.grey),
                        ),
                      ),
                    );
                  }
                },
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
                  final isLiked = playlistService.isLiked(currentSong);
                  showMusicToast(
                    context,
                    isLiked ? 'Added to Liked Songs' : 'Removed from Liked Songs',
                    type: isLiked ? ToastType.success : ToastType.info,
                    isBottom: !isLiked,
                  );
                },
                icon: Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
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
          accentColor,
        ),
        const SizedBox(height: 40),
        _buildLyricsSection(theme, currentSong),
      ],
    );
  }
}
