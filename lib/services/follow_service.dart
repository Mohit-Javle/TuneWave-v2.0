import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';


class FollowService extends ChangeNotifier {
  List<String> _followedArtistIds = [];
  
  // You might want to store more than just IDs if you want to list followed artists later
  // For now, storing IDs to track state and count.
  
  List<String> get followedArtistIds => _followedArtistIds;
  int get followingCount => _followedArtistIds.length;

  FollowService() {
    _loadFollowedArtists();
  }

  Future<void> _loadFollowedArtists() async {
    final prefs = await SharedPreferences.getInstance();
    _followedArtistIds = prefs.getStringList('followed_artists') ?? [];
    notifyListeners();
  }

  Future<void> _saveFollowedArtists() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('followed_artists', _followedArtistIds);
    notifyListeners();
  }

  bool isFollowing(String artistId) {
    return _followedArtistIds.contains(artistId);
  }

  void toggleFollow(String artistId) {
    if (_followedArtistIds.contains(artistId)) {
      _followedArtistIds.remove(artistId);
    } else {
      _followedArtistIds.add(artistId);
    }
    _saveFollowedArtists();
  }
}
