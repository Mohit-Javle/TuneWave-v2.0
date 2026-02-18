import 'package:clone_mp/services/music_service.dart';
import 'package:clone_mp/services/playlist_service.dart';
import 'package:clone_mp/models/album_model.dart';
import 'package:clone_mp/models/artist_model.dart';
import 'package:clone_mp/services/api_service.dart';

import 'package:clone_mp/services/follow_service.dart';
import 'package:flutter/material.dart';
import 'package:clone_mp/route_names.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:clone_mp/widgets/download_button.dart';

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
  List<String> _recentSearches = [];
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
    setState(() {
      _recentSearches = prefs.getStringList('recent_searches') ?? [];
    });
  }

  Future<void> _saveRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('recent_searches', _recentSearches);
  }

  void _addToRecentSearches(String query) {
    if (query.trim().isEmpty) return;
    setState(() {
      _recentSearches.removeWhere((term) => term.toLowerCase() == query.trim().toLowerCase());
      _recentSearches.insert(0, query.trim());
      if (_recentSearches.length > 10) {
        _recentSearches.removeLast();
      }
    });
    _saveRecentSearches();
  }

  void _removeFromRecentSearches(String query) {
    setState(() {
      _recentSearches.remove(query);
    });
    _saveRecentSearches();
  }

  void _clearRecentSearches() {
    setState(() {
      _recentSearches.clear();
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
      _addToRecentSearches(query);
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
                                         followService.toggleFollow(artist.id);
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
                                  // Swipe Left-to-Right: Add to Queue
                                  context.read<MusicService>().addToQueue(song);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('${song.name} added to queue'),
                                      backgroundColor: const Color(0xFFFF6600),
                                      duration: const Duration(seconds: 1),
                                    ),
                                  );
                                } else if (direction == DismissDirection.endToStart) {
                                  // Swipe Right-to-Left: Toggle Like
                                  await context.read<PlaylistService>().toggleLike(song);
                                  if (!context.mounted) return false;
                                  final isLiked = context.read<PlaylistService>().isLiked(song);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        isLiked 
                                          ? 'Added to Liked Songs' 
                                          : 'Removed from Liked Songs'
                                      ),
                                      backgroundColor: const Color(0xFFFF6600),
                                      duration: const Duration(seconds: 1),
                                    ),
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
                                    Icon(Icons.queue_music, color: Colors.white),
                                    SizedBox(width: 8),
                                    Text('Queue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                                title: Text(
                                  song.name,
                                  style: TextStyle(color: theme.colorScheme.onSurface),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
                                    DownloadButton(song: song),
                                    Consumer<PlaylistService>(
                                       builder: (context, playlistService, _) {
                                          if (playlistService.isLiked(song)) {
                                             return const Padding(
                                                padding: EdgeInsets.only(right: 8.0),
                                                child: Icon(Icons.favorite, color: Color(0xFFFF6600), size: 16),
                                             );
                                          }
                                          return const SizedBox.shrink();
                                       },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.play_circle_outline, color: Color(0xFFFF6600)),
                                      onPressed: () {
                                        final index = _songResults.indexOf(song);
                                        widget.onPlaySong(song, _songResults, index);
                                      },
                                    ),
                                  ],
                                ),
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
    if (_recentSearches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: theme.unselectedWidgetColor.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              "Search History is empty",
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
                        fontSize: 16,
                     ),
                  ),
                  if (_recentSearches.isNotEmpty)
                     TextButton(
                        onPressed: _clearRecentSearches,
                        child: const Text("Clear All", style: TextStyle(color: Color(0xFFFF6600))),
                     ),
               ],
            ),
         ),
         Expanded(
            child: ListView.builder(
               itemCount: _recentSearches.length,
               itemBuilder: (context, index) {
                  final term = _recentSearches[index];
                  return ListTile(
                     leading: Icon(Icons.history, color: theme.unselectedWidgetColor),
                     title: Text(term, style: TextStyle(color: theme.colorScheme.onSurface)),
                     trailing: IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => _removeFromRecentSearches(term),
                     ),
                     onTap: () {
                        _searchController.text = term;
                        _performSearch(term);
                     },
                  );
               },
            ),
         ),
      ],
    );
  }
}
