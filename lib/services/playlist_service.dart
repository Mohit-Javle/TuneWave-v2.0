// services/playlist_service.dart
import 'dart:convert';
import 'package:clone_mp/models/song_model.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class Playlist {
  final String id;
  final String name;
  final List<SongModel> songs;

  Playlist({required this.id, required this.name, this.songs = const []});

  factory Playlist.fromJson(Map<String, dynamic> json) {
    var songList = json['songs'] as List;
    List<SongModel> songs = songList.map((i) => SongModel.fromJson(i)).toList();
    return Playlist(
      id: json['id'],
      name: json['name'],
      songs: songs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'songs': songs.map((s) => s.toJson()).toList(),
    };
  }
}

class PlaylistService with ChangeNotifier {
  // --- LIKED SONGS ---
  // --- LIKED SONGS ---
  List<SongModel> _likedSongs = [];
  List<SongModel> get likedSongs => _likedSongs;
  String? _currentUserEmail;

  // Load all user data
  Future<void> loadUserData(String userEmail) async {
    _currentUserEmail = userEmail;
    await _loadLikedSongs();
    await _loadPlaylists();
    notifyListeners();
  }

  Future<void> _loadLikedSongs() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'liked_songs_$_currentUserEmail';
    final jsonString = prefs.getString(key);
    
    if (jsonString != null) {
      final List<dynamic> decoded = jsonDecode(jsonString);
      _likedSongs = decoded.map((json) => SongModel.fromJson(json)).toList();
    } else {
      _likedSongs = [];
    }
  }

  Future<void> _loadPlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'playlists_$_currentUserEmail';
    final jsonString = prefs.getString(key);
    
    if (jsonString != null) {
      final List<dynamic> decoded = jsonDecode(jsonString);
      _playlists = decoded.map((json) => Playlist.fromJson(json)).toList();
    } else {
      _playlists = [];
    }
  }

  // Clear data on logout
  void clearData() {
    _currentUserEmail = null;
    _likedSongs = [];
    _playlists = [];
    notifyListeners();
  }

  bool isLiked(SongModel song) {
    return _likedSongs.any((s) => s.id == song.id);
  }

  Future<void> toggleLike(SongModel song) async {
    if (_currentUserEmail == null) return; 

    if (isLiked(song)) {
      _likedSongs.removeWhere((s) => s.id == song.id);
    } else {
      _likedSongs.add(song);
    }
    notifyListeners();
    
    // Persist changes
    final prefs = await SharedPreferences.getInstance();
    final key = 'liked_songs_$_currentUserEmail';
    final jsonString = jsonEncode(_likedSongs.map((s) => s.toJson()).toList());
    await prefs.setString(key, jsonString);
  }

  // --- USER-CREATED PLAYLISTS ---
  List<Playlist> _playlists = [];
  List<Playlist> get playlists => _playlists;
  final Uuid _uuid = const Uuid();

  // (loadUserPlaylists removed as it is merged into loadUserData/private helper)

  Future<void> _savePlaylists() async {
    if (_currentUserEmail == null) return;
    final prefs = await SharedPreferences.getInstance();
    final key = 'playlists_$_currentUserEmail';
    final jsonString = jsonEncode(_playlists.map((p) => p.toJson()).toList());
    await prefs.setString(key, jsonString);
  }

  void createPlaylist(String name) {
    final newPlaylist = Playlist(id: _uuid.v4(), name: name);
    _playlists.add(newPlaylist);
    notifyListeners();
    _savePlaylists();
  }

  void deletePlaylist(String playlistId) {
    _playlists.removeWhere((p) => p.id == playlistId);
    notifyListeners();
    _savePlaylists();
  }

  // Add multiple songs at once
  Future<void> addSongsToPlaylist(String playlistId, List<SongModel> newSongs) async {
    final playlistIndex = _playlists.indexWhere((p) => p.id == playlistId);
    if (playlistIndex == -1) return;

    final oldPlaylist = _playlists[playlistIndex];

    // Filter duplicates
    final validNewSongs = newSongs.where((newS) {
      return !oldPlaylist.songs.any((oldS) => oldS.id == newS.id);
    }).toList();

    if (validNewSongs.isNotEmpty) {
      final newSongList = List<SongModel>.from(oldPlaylist.songs)
        ..addAll(validNewSongs);

      _playlists[playlistIndex] = Playlist(
        id: oldPlaylist.id,
        name: oldPlaylist.name,
        songs: newSongList,
      );
      notifyListeners();
      await _savePlaylists();
    }
  }

  Future<void> renamePlaylist(String playlistId, String newName) async {
    final playlistIndex = _playlists.indexWhere((p) => p.id == playlistId);
    if (playlistIndex != -1) {
      final oldPlaylist = _playlists[playlistIndex];
      _playlists[playlistIndex] = Playlist(
        id: oldPlaylist.id,
        name: newName,
        songs: oldPlaylist.songs,
      );
      notifyListeners();
      await _savePlaylists();
    }
  }

  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    final playlistIndex = _playlists.indexWhere((p) => p.id == playlistId);
    if (playlistIndex != -1) {
      final oldPlaylist = _playlists[playlistIndex];
      final newSongList = List<SongModel>.from(oldPlaylist.songs)
        ..removeWhere((s) => s.id == songId);

      _playlists[playlistIndex] = Playlist(
        id: oldPlaylist.id,
        name: oldPlaylist.name,
        songs: newSongList,
      );
      notifyListeners();
      await _savePlaylists();
    }
  }
}
