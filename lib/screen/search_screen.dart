import 'package:clone_mp/services/music_service.dart';
import 'package:clone_mp/services/playlist_service.dart';
import 'package:clone_mp/models/album_model.dart';
import 'package:clone_mp/models/artist_model.dart';
import 'package:clone_mp/services/api_service.dart';

import 'package:clone_mp/services/follow_service.dart';
import 'package:clone_mp/services/download_service.dart';
import 'package:clone_mp/services/ui_state_service.dart';
import 'package:clone_mp/widgets/music_toast.dart';
import 'package:clone_mp/widgets/song_info_dialog.dart';
import 'package:flutter/material.dart';
import 'package:clone_mp/route_names.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';

class SearchScreen extends StatefulWidget {
  final Function(SongModel, List<SongModel>, int) onPlaySong;

  const SearchScreen({super.key, required this.onPlaySong});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<SongModel> _songResults = [];
  List<AlbumModel> _albumResults = [];
  List<ArtistModel> _artistResults = [];
  List<Map<String, dynamic>> _recentItems = [];
  bool _isLoading = false;
  final ApiService _apiService = ApiService();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> history = prefs.getStringList('recent_items_v2') ?? [];
    setState(() {
      _recentItems = history.map((item) => json.decode(item) as Map<String, dynamic>).toList();
    });
  }

  Future<void> _saveRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> history = _recentItems.map((item) => json.encode(item)).toList();
    await prefs.setStringList('recent_items_v2', history);
  }

  void _addToHistory(dynamic item, String type) {
    Map<String, dynamic> historyItem;
    
    if (type == 'query') {
      historyItem = {'type': 'query', 'data': item as String};
    } else if (type == 'song') {
      historyItem = {'type': 'song', 'data': (item as SongModel).toJson()};
    } else if (type == 'album') {
      historyItem = {'type': 'album', 'data': (item as AlbumModel).toJson()};
    } else if (type == 'artist') {
      historyItem = {'type': 'artist', 'data': (item as ArtistModel).toJson()};
    } else {
      return;
    }

    setState(() {
      // Remove existing occurrences
      _recentItems.removeWhere((element) {
        if (element['type'] != type) return false;
        if (type == 'query') return element['data'] == historyItem['data'];
        return element['data']['id'] == historyItem['data']['id'];
      });
      
      _recentItems.insert(0, historyItem);
      if (_recentItems.length > 20) {
        _recentItems.removeLast();
      }
    });
    _saveRecentSearches();
  }

  void _removeFromRecentSearches(Map<String, dynamic> item) {
    setState(() {
      _recentItems.remove(item);
    });
    _saveRecentSearches();
  }

  void _clearRecentSearches() {
    setState(() {
      _recentItems.clear();
    });
    _saveRecentSearches();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty) {
        _performSearch(query, saveHistory: false);
      } else {
        setState(() {
           _songResults = [];
           _albumResults = [];
        });
      }
    });
  }

  Future<void> _performSearch(String query, {bool saveHistory = true}) async {
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _songResults = [];
          _albumResults = [];
          _isLoading = false;
        });
      }
      return;
    }
    
    if (saveHistory) {
      _addToHistory(query, 'query');
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final results = await Future.wait([
        _apiService.searchSongs(query),
        _apiService.searchAlbums(query),
        _apiService.searchArtists(query),
      ]);

      if (mounted) {
        setState(() {
          _songResults = results[0] as List<SongModel>;
          _albumResults = results[1] as List<AlbumModel>;
          _artistResults = results[2] as List<ArtistModel>;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Search error: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
                    leading: const Icon(Icons.queue_play_next_rounded, color: Color(0xFFFF6600)),
                    title: const Text("Play Next"),
                    onTap: () {
                      musicService.addToPlayNext(song);
                      Navigator.pop(context);
                      showMusicToast(context, "Playing next: ${song.name}", type: ToastType.success);
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
                showMusicToast(
                   context, 
                   success ? 'Deleted' : 'Failed to delete', 
                   type: success ? ToastType.info : ToastType.error,
                   isBottom: true,
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showSongDetails(BuildContext context, SongModel song) {
    SongInfoDialog.show(context, song);
  }



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool showHistory = _searchController.text.isEmpty && _songResults.isEmpty && _albumResults.isEmpty;
    
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          style: TextStyle(color: theme.colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: "Search for songs, albums...",
            hintStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            border: InputBorder.none,
          ),
          onChanged: _onSearchChanged,
          onSubmitted: (query) => _performSearch(query, saveHistory: true),
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
             IconButton(
                icon: Icon(Icons.clear, color: theme.colorScheme.onSurface),
                onPressed: () {
                   _searchController.clear();
                   _onSearchChanged('');
                },
             ),
          IconButton(
            icon: Icon(Icons.search, color: theme.colorScheme.onSurface),
            onPressed: () => _performSearch(_searchController.text, saveHistory: true),
          ),
        ],
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6600)))
          : showHistory
              ? _buildRecentSearches(theme)
              : (_songResults.isEmpty && _albumResults.isEmpty)
                  ? Center(
                      child: Text(
                        "No results found.",
                        style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                      ),
                    )
                  : CustomScrollView(
                      slivers: [
                    if (_artistResults.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            "Artists",
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final artist = _artistResults[index];
                            return ListTile(
                              leading: GestureDetector(
                                onTap: () {
                                  // Navigate to artist detail
                                  Navigator.pushNamed(
                                    context, 
                                    AppRoutes.artist, 
                                    arguments: {'name': artist.name, 'image': artist.imageUrl}
                                  );
                                },
                                child: CircleAvatar(
                                  radius: 25,
                                  backgroundImage: NetworkImage(artist.imageUrl),
                                  backgroundColor: Colors.grey[800],
                                ),
                              ),
                              title: Text(
                                artist.name,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Consumer<FollowService>(
                                builder: (context, followService, child) {
                                  final isFollowing = followService.isFollowing(artist.id);
                                  if (isFollowing) {
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      followService.updateArtistMetadata(artist.id, artist.name, artist.imageUrl);
                                    });
                                  }
                                  return SizedBox(
                                    height: 32,
                                    width: 100,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isFollowing ? Colors.transparent : const Color(0xFFFF6600),
                                        foregroundColor: isFollowing ? theme.colorScheme.onSurface : Colors.white,
                                        side: isFollowing ? BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)) : null,
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      ),
                                      onPressed: () {
                                         followService.toggleFollow(
                                            artist.id, 
                                            name: artist.name, 
                                            image: artist.imageUrl
                                          );
                                      },
                                      child: Text(
                                         isFollowing ? "Following" : "Follow",
                                         style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  );
                                }
                              ),
                              onTap: () {
                                  _addToHistory(artist, 'artist');
                                  Navigator.pushNamed(
                                    context, 
                                    AppRoutes.artist, 
                                    arguments: {
                                      'id': artist.id,
                                      'name': artist.name, 
                                      'image': artist.imageUrl
                                    }
                                  );
                              },
                            );
                          },
                          childCount: _artistResults.take(1).length,
                        ),
                      ),
                    ],
                    if (_albumResults.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            "Albums",
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 180,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _albumResults.length,
                            itemBuilder: (context, index) {
                              final album = _albumResults[index];
                              return GestureDetector(
                                onTap: () {
                                  _addToHistory(album, 'album');
                                  Navigator.pushNamed(context, AppRoutes.album, arguments: album);
                                },
                                child: Container(
                                  width: 130,
                                  margin: const EdgeInsets.only(right: 16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          album.imageUrl,
                                          width: 130,
                                          height: 130,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) =>
                                              Container(
                                            width: 130,
                                            height: 130,
                                            color: Colors.grey[800],
                                            child: const Icon(Icons.album, color: Colors.white),
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
                                        album.artist,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
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
                    if (_songResults.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                          child: Text(
                            "Songs",
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final song = _songResults[index];
                            return Dismissible(
                              key: Key('search_${song.id}'),
                              confirmDismiss: (direction) async {
                                if (direction == DismissDirection.startToEnd) {
                                  // Swipe Left-to-Right: Play Next
                                  context.read<MusicService>().addToPlayNext(song);
                                  showMusicToast(context, 'Playing next: ${song.name}', type: ToastType.success);
                                } else if (direction == DismissDirection.endToStart) {
                                  // Swipe Right-to-Left: Toggle Like
                                  await context.read<PlaylistService>().toggleLike(song);
                                  if (!context.mounted) return false;
                                  final isLiked = context.read<PlaylistService>().isLiked(song);
                                  showMusicToast(
                                    context, 
                                    isLiked ? 'Added to Liked Songs' : 'Removed from Liked Songs',
                                    type: isLiked ? ToastType.success : ToastType.info,
                                    isBottom: !isLiked,
                                  );
                                }
                                return false; // Always snap back
                              },
                              background: Container(
                                color: Colors.green,
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.only(left: 20),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.queue_play_next_rounded, color: Colors.white),
                                    SizedBox(width: 8),
                                    Text('Play Next', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              secondaryBackground: Container(
                                color: const Color(0xFFFF6600),
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Like', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    SizedBox(width: 8),
                                    Icon(Icons.favorite, color: Colors.white),
                                  ],
                                ),
                              ),
                              child: ListTile(
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(
                                    song.imageUrl,
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        Container(color: Colors.grey, width: 50, height: 50),
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
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    );
                                  },
                                ),
                                subtitle: Text(
                                  song.artist,
                                  style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
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
                                  _addToHistory(song, 'song');
                                  // Pass only the selected song to keep the queue clean
                                  // Smart Autoplay will handle the rest when the song ends
                                  widget.onPlaySong(song, [song], 0);
                                },
                              ),
                            );
                          },
                          childCount: _songResults.length,
                        ),
                      ),
                      const SliverToBoxAdapter(
                         child: SizedBox(height: 100), // Bottom padding for miniplayer
                      ),
                    ],
                  ],
                ),
    );
  }
  Widget _buildRecentSearches(ThemeData theme) {
    if (_recentItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: theme.unselectedWidgetColor.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              "Your recent searches will appear here",
              style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 16),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                  Text(
                     "Recent Searches",
                     style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                     ),
                  ),
                  TextButton(
                     onPressed: _clearRecentSearches,
                     child: const Text("Clear All", style: TextStyle(color: Color(0xFFFF6600))),
                  ),
               ],
            ),
         ),
         Expanded(
            child: ListView.builder(
               padding: const EdgeInsets.only(bottom: 100),
               itemCount: _recentItems.length,
               itemBuilder: (context, index) {
                  final item = _recentItems[index];
                  final type = item['type'] as String;
                  final data = item['data'];

                  Widget leading;
                  String title;
                  String? subtitle;
                  VoidCallback onTap;

                  if (type == 'query') {
                    leading = const Icon(Icons.history);
                    title = data as String;
                    subtitle = 'Search';
                    onTap = () {
                      _searchController.text = title;
                      _performSearch(title);
                    };
                  } else if (type == 'song') {
                    final song = SongModel.fromJson(data);
                    leading = ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(song.imageUrl, width: 40, height: 40, fit: BoxFit.cover),
                    );
                    title = song.name;
                    final primaryArtist = song.artist.split(',')[0].trim();
                    subtitle = 'Song • $primaryArtist';
                    onTap = () {
                       widget.onPlaySong(song, [song], 0);
                    };
                  } else if (type == 'artist') {
                    final artist = ArtistModel.fromJson(data);
                    leading = CircleAvatar(
                      radius: 20,
                      backgroundImage: NetworkImage(artist.imageUrl),
                    );
                    title = artist.name;
                    subtitle = 'Artist';
                    onTap = () {
                      Navigator.pushNamed(context, AppRoutes.artist, arguments: artist);
                    };
                  } else if (type == 'album') {
                    final album = AlbumModel.fromJson(data);
                    leading = ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(album.imageUrl, width: 40, height: 40, fit: BoxFit.cover),
                    );
                    title = album.name;
                    final primaryArtist = album.artist.split(',')[0].trim();
                    subtitle = 'Album • $primaryArtist';
                    onTap = () {
                      Navigator.pushNamed(context, AppRoutes.album, arguments: album);
                    };
                  } else {
                    return const SizedBox.shrink();
                  }

                  return ListTile(
                     leading: SizedBox(width: 40, height: 40, child: Center(child: leading)),
                     title: Text(title, style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w500)),
                     subtitle: Text(subtitle, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12)),
                     trailing: IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => _removeFromRecentSearches(item),
                     ),
                     onTap: onTap,
                  );
               },
            ),
         ),
      ],
    );
  }
}
