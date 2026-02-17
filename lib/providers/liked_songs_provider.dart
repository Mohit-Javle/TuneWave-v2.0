// lib/liked_songs_provider.dart
import 'package:flutter/material.dart';

class LikedSongsProvider with ChangeNotifier {
  final List<Map<String, String>> _likedSongs = [];

  List<Map<String, String>> get likedSongs => _likedSongs;

  bool isLiked(Map<String, String> song) {
    return _likedSongs.any((item) => item['title'] == song['title']);
  }

  void toggleLike(Map<String, String> song) {
    if (isLiked(song)) {
      _likedSongs.removeWhere((item) => item['title'] == song['title']);
    } else {
      _likedSongs.add(song);
    }
    notifyListeners();
  }
}
