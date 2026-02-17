// screen/add_songs_screen.dart
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:async';
import 'package:clone_mp/models/song_model.dart';
import 'package:clone_mp/services/api_service.dart';
import 'package:clone_mp/services/playlist_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AddSongsScreen extends StatefulWidget {
  final Playlist playlist;

  const AddSongsScreen({super.key, required this.playlist});

  @override
  State<AddSongsScreen> createState() => _AddSongsScreenState();
}

class _AddSongsScreenState extends State<AddSongsScreen> {
  final Set<String> _selectedSongIds = {};
  final List<SongModel> _selectedSongs = [];
  List<SongModel> _searchResults = [];
  bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController();
  final ApiService _apiService = ApiService();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _selectedSongIds.clear();
    _selectedSongs.clear();
    _searchController.addListener(_onSearchChanged);
    // Optionally load some initial songs (e.g. trending)
    _performSearch("Arijit Singh"); // Default initial search
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        _performSearch(_searchController.text);
      }
    });

    if (_searchController.text.isEmpty) {
        // optionally clear options or show recent
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final results = await _apiService.searchSongs(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSongSelected(bool? isSelected, SongModel song) {
    setState(() {
      if (isSelected == true) {
        _selectedSongIds.add(song.id);
        if (!_selectedSongs.any((s) => s.id == song.id)) {
          _selectedSongs.add(song);
        }
      } else {
        _selectedSongIds.remove(song.id);
        _selectedSongs.removeWhere((s) => s.id == song.id);
      }
    });
  }

  void _addSelectedSongsToPlaylist() {
    if (_selectedSongs.isEmpty) return;

    final playlistService = Provider.of<PlaylistService>(
      context,
      listen: false,
    );

    playlistService.addSongsToPlaylist(widget.playlist.id, _selectedSongs);

    Navigator.pop(context); 
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("${_selectedSongs.length} song(s) added."),
        backgroundColor: const Color(0xFFFF6600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool canAddSongs = _selectedSongs.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Songs'),
        actions: [
          TextButton(
            onPressed: canAddSongs ? _addSelectedSongsToPlaylist : null,
            child: Text(
              'Add',
              style: TextStyle(
                color: canAddSongs ? const Color(0xFFFF6600) : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for a song...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.colorScheme.onSurface.withOpacity(0.1),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6600)))
                : ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final song = _searchResults[index];
                      // Check if already in playlist (by ID)
                      final isAlreadyInPlaylist = widget.playlist.songs
                          .any((s) => s.id == song.id);
                      final isSelected = _selectedSongIds.contains(song.id);

                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            song.imageUrl,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(color: Colors.grey),
                          ),
                        ),
                        title: Text(song.name),
                        subtitle: Text(song.artist),
                        trailing: Checkbox(
                          value: isSelected || isAlreadyInPlaylist,
                          onChanged: isAlreadyInPlaylist
                              ? null
                              : (bool? value) {
                                  _onSongSelected(value, song);
                                },
                          activeColor: const Color(0xFFFF6600),
                        ),
                        onTap: isAlreadyInPlaylist
                            ? null
                            : () {
                                _onSongSelected(!isSelected, song);
                              },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
