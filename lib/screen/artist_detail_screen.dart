
import 'package:clone_mp/models/album_model.dart';
import 'package:clone_mp/services/api_service.dart';
import 'package:clone_mp/services/music_service.dart';
import 'package:clone_mp/services/follow_service.dart';
import 'package:clone_mp/services/playlist_service.dart';
import 'package:clone_mp/services/download_service.dart';
import 'package:clone_mp/services/ui_state_service.dart';
import 'package:clone_mp/widgets/music_toast.dart';
import 'package:flutter/material.dart';
import 'package:clone_mp/route_names.dart';
import 'package:provider/provider.dart';

class ArtistDetailScreen extends StatefulWidget {
  final Map<String, String> artist;

  const ArtistDetailScreen({super.key, required this.artist});

  @override
  State<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends State<ArtistDetailScreen> {
  List<SongModel> topSongs = [];
  List<AlbumModel> albums = [];
  bool isLoading = true;
  bool _showAllSongs = false;

  @override
  void initState() {
    super.initState();
    _loadArtistDetails();
  }

  Future<void> _loadArtistDetails() async {
    try {
      final api = ApiService();
      final artistId = widget.artist['id'];
      
      if (artistId != null && artistId.isNotEmpty) {
        final details = await api.getArtistDetails(artistId);
        
        List<AlbumModel> fetchedAlbums = details['albums'] ?? [];
        List<SongModel> fetchedSongs = details['topSongs'] ?? [];

        if (fetchedAlbums.isEmpty) {
           fetchedAlbums = await api.searchAlbums(widget.artist['name']!);
        }
        
        final artistName = widget.artist['name']!.toLowerCase().trim();
        
        fetchedAlbums = fetchedAlbums.where((album) {
           final albumArtists = album.artist.toLowerCase();
           return albumArtists.startsWith(artistName); 
        }).toList();

        fetchedAlbums.sort((a, b) {
           int yearA = int.tryParse(a.year) ?? 0;
           int yearB = int.tryParse(b.year) ?? 0;
           return yearB.compareTo(yearA);
        });

        if (mounted) {
          setState(() {
            topSongs = fetchedSongs;
            albums = fetchedAlbums;
            isLoading = false;
          });
        }
      } else {
        final songs = await api.searchSongs(widget.artist['name']!);
        var searchedAlbums = await api.searchAlbums(widget.artist['name']!);
        
        final artistName = widget.artist['name']!.toLowerCase().trim();
        searchedAlbums = searchedAlbums.where((album) {
           final albumArtists = album.artist.toLowerCase();
           return albumArtists.startsWith(artistName);
        }).toList();
        
        searchedAlbums.sort((a, b) {
           int yearA = int.tryParse(a.year) ?? 0;
           int yearB = int.tryParse(b.year) ?? 0;
           return yearB.compareTo(yearA);
        });
        
        if (mounted) {
          setState(() {
            topSongs = songs.take(10).toList();
            albums = searchedAlbums;
            isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading artist details: $e");
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _shufflePlay(MusicService musicService) {
    if (topSongs.isEmpty) return;
    final shuffled = List<SongModel>.from(topSongs)..shuffle();
    musicService.loadPlaylist(shuffled, 0);
    showMusicToast(context, 'Shuffling artist songs...', type: ToastType.success);
  }

  void _showMoreMenu(BuildContext context, SongModel song) {
    final uiStateService = Provider.of<UiStateService>(context, listen: false);
    final musicService = Provider.of<MusicService>(context, listen: false);
    
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
    final visibleSongs = _showAllSongs ? topSongs : topSongs.take(5).toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // --- Hero Header ---
          SliverAppBar(
            expandedHeight: 340.0,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.artist['name']!,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  shadows: [
                    Shadow(offset: Offset(0, 1), blurRadius: 4.0, color: Colors.black87),
                  ],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    widget.artist['image']!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[900],
                      child: const Center(child: Icon(Icons.person, size: 80, color: Colors.white54)),
                    ),
                  ),
                  // Gradient overlay for readability
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black54,
                          Colors.black87,
                        ],
                        stops: [0.0, 0.4, 0.75, 1.0],
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

          // --- Action Buttons Row (Follow + Shuffle) ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  // Follow/Unfollow Button
                  Consumer<FollowService>(
                    builder: (context, followService, child) {
                      final artistId = widget.artist['id'] ?? '';
                      final isFollowing = artistId.isNotEmpty && followService.isFollowing(artistId);
                      return Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            if (artistId.isNotEmpty) {
                              followService.toggleFollow(artistId);
                            }
                          },
                          icon: Icon(
                            isFollowing ? Icons.check : Icons.person_add_alt_1,
                            size: 18,
                          ),
                          label: Text(
                            isFollowing ? 'Following' : 'Follow',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isFollowing 
                                ? theme.colorScheme.onSurface 
                                : Colors.white,
                            backgroundColor: isFollowing 
                                ? Colors.transparent 
                                : const Color(0xFFFF6600),
                            side: BorderSide(
                              color: isFollowing 
                                  ? theme.colorScheme.onSurface.withValues(alpha: 0.3) 
                                  : const Color(0xFFFF6600),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  // Shuffle Play Button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: topSongs.isNotEmpty 
                          ? () => _shufflePlay(musicService) 
                          : null,
                      icon: const Icon(Icons.shuffle, size: 18),
                      label: const Text(
                        'Shuffle',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6600),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[700],
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- Loading State ---
          if (isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: Color(0xFFFF6600))),
            )
          else ...[
            // --- Top Songs Section ---
            if (topSongs.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Most Popular",
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // Play All button
                      TextButton.icon(
                        onPressed: () {
                          musicService.loadPlaylist(topSongs, 0);
                        },
                        icon: const Icon(Icons.play_arrow, size: 18, color: Color(0xFFFF6600)),
                        label: const Text(
                          'Play All',
                          style: TextStyle(
                            color: Color(0xFFFF6600),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final song = visibleSongs[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          song.imageUrl,
                          width: 45,
                          height: 45,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => 
                              Container(width: 45, height: 45, color: Colors.grey[800]),
                        ),
                      ),
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
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                      subtitle: Text(
                        song.artist,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
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
                            icon: Icon(Icons.more_vert, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                            onPressed: () => _showMoreMenu(context, song),
                          ),
                        ],
                      ),
                      onTap: () {
                        musicService.loadPlaylist(topSongs, index);
                      },
                    );
                  },
                  childCount: visibleSongs.length,
                ),
              ),
              if (topSongs.length > 5)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _showAllSongs = !_showAllSongs;
                        });
                      },
                      child: Text(
                        _showAllSongs ? "See Less" : "See More",
                        style: const TextStyle(
                          color: Color(0xFFFF6600),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],

            // --- Discography Section ---
            if (albums.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                  child: Text(
                    "Discography",
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 220,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: albums.length,
                    itemBuilder: (context, index) {
                      final album = albums[index];
                      return GestureDetector(
                        onTap: () {
                           Navigator.pushNamed(context, AppRoutes.album, arguments: album);
                        },
                        child: Container(
                          width: 140,
                          margin: const EdgeInsets.only(right: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  album.imageUrl,
                                  width: 140,
                                  height: 140,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    width: 140, 
                                    height: 140, 
                                    color: Colors.grey[800],
                                    child: const Icon(Icons.album, color: Colors.white54, size: 40),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                album.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                album.year,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],

            // Bottom padding for mini player
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ],
      ),
    );
  }
}
