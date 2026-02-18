// services/music_service.dart

import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import '../models/song_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'auth_service.dart';

import 'download_service.dart';

export '../models/song_model.dart'; 

class MusicService with ChangeNotifier {
  final AudioHandler _audioHandler; // Use base handler
  final DownloadService _downloadService;

  List<SongModel> _playlist = [];
  List<SongModel> _listeningHistory = []; 

  List<SongModel> get listeningHistory => _listeningHistory;
  
  final ValueNotifier<SongModel?> currentSongNotifier = ValueNotifier(null);
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier(false);
  final ValueNotifier<Duration> currentDurationNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> totalDurationNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<bool> isRepeatNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isShuffleNotifier = ValueNotifier(false);
  final ValueNotifier<String?> errorMessageNotifier = ValueNotifier(null);

  List<SongModel> _originalPlaylist = [];


  MusicService(this._audioHandler, this._downloadService); // Inject handler and download service

  void init() {
    // Listen to AudioHandler state
    _audioHandler.playbackState.listen((playbackState) {
      isPlayingNotifier.value = playbackState.playing;
      currentDurationNotifier.value = playbackState.position;
      // You might need a periodic timer or a ticker to update position smoothly in UI
      // but for now relying on state updates. 
      // Note: playbackState.position is only updated on state changes or specific events, 
      // not continuously. AudioService suggests using AudioService.position stream for 
      // continuous updates, but we are using our custom handler. 
      // Our custom handler emits position changes from _player.onPositionChanged 
      // into playbackState.updatePosition, so it should work.
    });

    _audioHandler.mediaItem.listen((mediaItem) {
      debugPrint("🎵 MusicService: mediaItem changed = ${mediaItem?.title ?? 'null'}");
      if (mediaItem != null) {
        // Find SongModel from playlist or create from MediaItem
        // Ideally we find it in _playlist to get full details
        final song = _playlist.firstWhere(
          (s) => s.id == mediaItem.id,
          orElse: () => SongModel(
              id: mediaItem.id,
              name: mediaItem.title,
              artist: mediaItem.artist ?? '',
              album: mediaItem.album ?? '',
              imageUrl: mediaItem.artUri?.toString() ?? '',
              downloadUrl: mediaItem.extras?['url'] ?? '',
              hasLyrics: false, // Default
            ),
        );
        
        if (currentSongNotifier.value?.id != song.id) {
           debugPrint("🎵 MusicService: Setting currentSongNotifier to ${song.name}");
           currentSongNotifier.value = song;
           addToHistory(song);
        }
        totalDurationNotifier.value = mediaItem.duration ?? Duration.zero;
      }
    });

    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final email = AuthService.instance.currentUser?.email;
    if (email != null) {
      try {
        final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(email)
          .collection('listeningHistory')
          .orderBy('playedAt', descending: true)
          .limit(50)
          .get();
        _listeningHistory = snapshot.docs
          .map((doc) => SongModel.fromJson(doc.data()))
          .toList();
      } catch (e) {
        debugPrint('Error loading history from Firestore, falling back to SharedPreferences: $e');
        // Fallback to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final historyJson = prefs.getStringList('listening_history') ?? [];
        _listeningHistory = historyJson
            .map((e) => SongModel.fromJson(json.decode(e)))
            .toList();
      }
    } else {
      // No user logged in, try SharedPreferences as fallback
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList('listening_history') ?? [];
      _listeningHistory = historyJson
          .map((e) => SongModel.fromJson(json.decode(e)))
          .toList();
    }
    notifyListeners();
  }

  Future<void> addToHistory(SongModel song) async {
    _listeningHistory.removeWhere((s) => s.id == song.id);
    
    final historyEntry = SongModel(
      id: song.id,
      name: song.name,
      artist: song.artist,
      album: song.album,
      imageUrl: song.imageUrl,
      downloadUrl: song.downloadUrl,
      hasLyrics: song.hasLyrics,
      playedAt: DateTime.now(),
    );

    _listeningHistory.insert(0, historyEntry);
    
    if (_listeningHistory.length > 50) {
      _listeningHistory = _listeningHistory.sublist(0, 50);
    }
    notifyListeners();

    // Non-blocking fire-and-forget write to Firestore
    final email = AuthService.instance.currentUser?.email;
    if (email != null) {
      FirebaseFirestore.instance
        .collection('users')
        .doc(email)
        .collection('listeningHistory')
        .doc(song.id)
        .set({
          ...historyEntry.toJson(),
          'playedAt': FieldValue.serverTimestamp(),
        })
        .catchError((e) => debugPrint('History write failed: $e'));
    }
  }

  void loadPlaylist(List<SongModel> songs, int startIndex) {
    debugPrint("MusicService: loadPlaylist called via AudioHandler.");
    _originalPlaylist = List.from(songs);
    _playlist = isShuffleNotifier.value ? _createShuffledPlaylist(songs, startIndex) : List.from(songs);
    
    // Find the actual index in the current playlist
    final actualIndex = isShuffleNotifier.value 
        ? _playlist.indexWhere((s) => s.id == songs[startIndex].id)
        : startIndex;
    
    // Convert to MediaItems
    final mediaItems = _playlist.map((song) => _createMediaItem(song)).toList();

    (_audioHandler as dynamic).setPlaylist(mediaItems, actualIndex >= 0 ? actualIndex : 0);
  }

  Future<void> play() async {
    await _audioHandler.play();
  }

  Future<void> pause() async {
    await _audioHandler.pause();
  }

  Future<void> seek(Duration position) async {
    await _audioHandler.seek(position);
  }

  Future<void> playNext() async {
    await _audioHandler.skipToNext();
  }

  Future<void> playPrevious() async {
    await _audioHandler.skipToPrevious();
  }
  
  // Custom method needed for our explicit queue management if we want to support repeat properly
  // logic could be moved to handler but sticking to simple delegation
  void toggleRepeat() {
    isRepeatNotifier.value = !isRepeatNotifier.value;
  }

  void toggleShuffle() {
    isShuffleNotifier.value = !isShuffleNotifier.value;
    
    if (_originalPlaylist.isEmpty) return;
    
    final currentSong = currentSongNotifier.value;
    if (currentSong == null) return;
    
    if (isShuffleNotifier.value) {
      // Enable shuffle: create shuffled playlist with current song first
      final currentIndex = _originalPlaylist.indexWhere((s) => s.id == currentSong.id);
      _playlist = _createShuffledPlaylist(_originalPlaylist, currentIndex >= 0 ? currentIndex : 0);
    } else {
      // Disable shuffle: restore original order
      _playlist = List.from(_originalPlaylist);
    }
    
    // Reload the playlist with current song
    final newIndex = _playlist.indexWhere((s) => s.id == currentSong.id);
    final mediaItems = _playlist.map((song) => _createMediaItem(song)).toList();
    
    (_audioHandler as dynamic).setPlaylist(mediaItems, newIndex >= 0 ? newIndex : 0);
    notifyListeners();
  }

  List<SongModel> _createShuffledPlaylist(List<SongModel> songs, int currentIndex) {
    if (songs.isEmpty) return [];
    
    // Get the current song
    final currentSong = songs[currentIndex];
    
    // Create a copy of the list without the current song
    final remaining = List<SongModel>.from(songs);
    remaining.removeAt(currentIndex);
    
    // Shuffle the remaining songs
    remaining.shuffle();
    
    // Put current song first, then shuffled songs
    return [currentSong, ...remaining];
  }

  // Queue Management Methods
  List<SongModel> get currentQueue => _playlist;
  
  int get currentQueueIndex {
    return (_audioHandler as dynamic).currentIndex ?? 0;
  }

  Future<void> addToPlayNext(SongModel song) async {
    final mediaItem = _createMediaItem(song);
    
    await (_audioHandler as dynamic).addToPlayNext(mediaItem);
    
    // Update local playlist
    final currentIndex = currentQueueIndex;
    _playlist.insert(currentIndex + 1, song);
    notifyListeners();
  }

  Future<void> addToQueue(SongModel song) async {
    final mediaItem = _createMediaItem(song);
    
    await (_audioHandler as dynamic).addToQueue(mediaItem);
    _playlist.add(song);
    notifyListeners();
  }

  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= _playlist.length) return;
    
    await (_audioHandler as dynamic).removeFromQueue(index);
    _playlist.removeAt(index);
    notifyListeners();
  }

  Future<void> skipToQueueItem(int index) async {
    await (_audioHandler as dynamic).skipToQueueItem(index);
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _playlist.length) return;
    if (newIndex < 0 || newIndex >= _playlist.length) return;
    
    final song = _playlist.removeAt(oldIndex);
    _playlist.insert(newIndex, song);
    
    await (_audioHandler as dynamic).reorderQueue(oldIndex, newIndex);
    notifyListeners();
  }

  Future<void> clearQueue() async {
    await (_audioHandler as dynamic).clearQueue();
    _playlist.clear();
    _originalPlaylist.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    // We don't own the handler, so we don't dispose it here usually, 
    // unless we want to stop background audio when UI closes (which we don't).
    super.dispose();
  }
  MediaItem _createMediaItem(SongModel song) {
    String url = song.downloadUrl;
    
    // Check if downloaded and use local path if available
    if (_downloadService.isSongDownloaded(song.id)) {
      final downloadedSong = _downloadService.getDownloadedSong(song.id);
      if (downloadedSong != null && downloadedSong.localFilePath != null) {
        url = downloadedSong.localFilePath!;
        debugPrint('Playing local file for ${song.name}: $url');
      }
    }
    
    return MediaItem(
      id: song.id,
      title: song.name,
      artist: song.artist,
      album: song.album,
      artUri: Uri.parse(song.imageUrl),
      extras: {'url': url},
    );
  }
}
