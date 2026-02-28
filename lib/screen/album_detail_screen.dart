
import 'package:clone_mp/models/album_model.dart';
import 'package:clone_mp/services/api_service.dart';
import 'package:clone_mp/services/music_service.dart';
import 'package:clone_mp/services/playlist_service.dart';
import 'package:clone_mp/services/download_service.dart';
import 'package:clone_mp/services/ui_state_service.dart';
import 'package:clone_mp/widgets/music_toast.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AlbumDetailScreen extends StatefulWidget {
  final AlbumModel album;

  const AlbumDetailScreen({super.key, required this.album});

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  List<SongModel> albumSongs = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlbumSongs();
  }

  Future<void> _loadAlbumSongs() async {
    try {
      final api = ApiService();
      final songs = await api.getAlbumDetails(widget.album.id);
      if (mounted) {
        setState(() {
          albumSongs = songs;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading album songs: $e");
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _showMoreMenu(BuildContext context, SongModel song, MusicService musicService) {
    final uiStateService = Provider.of<UiStateService>(context, listen: false);
    
    // Hide miniplayer when modal opens
    uiStateService.setModalActive(true);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Consumer<DownloadService>(
          builder: (context, downloadService, child) {
            final isDownloaded = downloadService.isSongDownloaded(song.id);
            final isDownloading = downloadService.isDownloading(song.id);
            
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        song.imageUrl,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      ),
                    ),
                    title: Text(song.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(song.artist),
                  ),
                  const Divider(),
                  ListTile(
                    leading: Icon(
                      isDownloaded ? Icons.download_done_rounded : Icons.download_rounded, 
                      color: isDownloaded ? Colors.green : const Color(0xFFFF6600)
                    ),
                    title: Text(isDownloading ? "Downloading..." : (isDownloaded ? "Delete Download" : "Download")),
                    onTap: () async {
                      if (isDownloading) return;
                      
                      if (isDownloaded) {
                        Navigator.pop(context);
                        // Show delete confirmation
                        _confirmDelete(context, song, downloadService);
                      } else {
                        Navigator.pop(context);
                        showMusicToast(context, 'Downloading "${song.name}"...', type: ToastType.info);
                        await downloadService.downloadSong(song);
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.playlist_add_rounded, color: Color(0xFFFF6600)),
                    title: const Text("Add to Queue"),
                    onTap: () {
                      musicService.addToQueue(song);
                      Navigator.pop(context);
                      showMusicToast(context, "Added to queue", type: ToastType.success);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded, color: Color(0xFFFF6600)),
                    title: const Text("Song Details"),
                    onTap: () {
                      Navigator.pop(context);
                      _showSongDetails(context, song);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) => uiStateService.setModalActive(false));
  }

  void _confirmDelete(BuildContext context, SongModel song, DownloadService downloadService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Download'),
        content: Text('Are you sure you want to delete "${song.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await downloadService.deleteSong(song.id);
              if (context.mounted) {
                showMusicToast(context, success ? 'Deleted' : 'Failed to delete', type: success ? ToastType.info : ToastType.error);
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showSongDetails(BuildContext context, SongModel song) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Song Details"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Title: ${song.name}"),
            const SizedBox(height: 8),
            Text("Artist: ${song.artist}"),
            const SizedBox(height: 8),
            Text("Album: ${song.album}"),
            if (song.duration != null) ...[
              const SizedBox(height: 8),
              Text("Duration: ${_formatDuration(song.duration)}"),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
        ],
      ),
    );
  }

  String _formatDuration(String? dur) {
    if (dur == null || dur.isEmpty) return "";
    final totalSec = int.tryParse(dur) ?? 0;
    if (totalSec == 0) return "";
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return "$m:${s.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final musicService = Provider.of<MusicService>(context, listen: false);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300.0,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    widget.album.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                       color: Colors.grey[900], 
                       child: const Center(child: Icon(Icons.album, size: 80, color: Colors.white54)),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                        stops: [0.6, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
             backgroundColor: theme.colorScheme.surface,
             leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
             ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.album.name,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (!isLoading && albumSongs.isNotEmpty) ...[
                    // Show metadata after songs load
                    Builder(
                      builder: (context) {
                        int totalSeconds = 0;
                        for (var s in albumSongs) {
                          totalSeconds += int.tryParse(s.duration ?? '0') ?? 0;
                        }
                        String durationText = "";
                        if (totalSeconds > 0) {
                          final minutes = totalSeconds ~/ 60;
                          final hours = minutes ~/ 60;
                          final remMin = minutes % 60;
                          durationText = hours > 0 ? " • $hours hr $remMin min" : " • $minutes min";
                        }

                        return Text(
                          "${albumSongs.length} songs$durationText",
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      }
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isLoading)
             const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: Color(0xFFFF6600))),
             )
          else if (albumSongs.isEmpty)
             const SliverFillRemaining(
                child: Center(child: Text("No songs found in this album.")),
             )
          else
             SliverList(
                delegate: SliverChildBuilderDelegate(
                   (context, index) {
                      final song = albumSongs[index];
                      return ListTile(
                         contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                         title: Consumer<MusicService>(
                          builder: (context, musicService, _) {
                             final bool isActive = musicService.isActive(song.id);
                             return Text(
                                song.name, 
                                style: TextStyle(
                                   color: isActive
                                       ? const Color(0xFFFF6600)
                                       : theme.colorScheme.onSurface,
                                   fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                             );
                          },
                       ),
                         subtitle: Text(
                            song.artist, 
                            style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(178)), // 0.7 * 255 = 178.5
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                         ),
                         trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                               Consumer<PlaylistService>(
                                  builder: (context, playlistService, _) {
                                     if (playlistService.isLiked(song)) {
                                        return const Padding(
                                           padding: EdgeInsets.only(right: 8.0),
                                           child: Icon(Icons.favorite, color: Color(0xFFFF6600), size: 22),
                                        );
                                     }
                                     return const SizedBox.shrink();
                                  },
                               ),
                               IconButton(
                                  icon: Icon(Icons.more_vert, color: theme.colorScheme.onSurface.withAlpha(153)), // 0.6 * 255 = 153
                                  onPressed: () => _showMoreMenu(context, song, musicService),
                               ),
                            ],
                         ),
                         onTap: () {
                            musicService.loadPlaylist(albumSongs, index);
                         },
                      );
                   },
                   childCount: albumSongs.length,
                ),
             ),
             const SliverToBoxAdapter(
              child: SizedBox(height: 100), // Bottom padding for miniplayer
            ),
        ],
      ),
    );
  }
}
