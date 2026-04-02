// services/music_service.dart

import 'package:audio_service/audio_service.dart';
import '../models/song_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'auth_service.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:flutter/material.dart';

import 'download_service.dart';
import 'dart:async';

import 'api_service.dart';
export '../models/song_model.dart'; 

class MusicService with ChangeNotifier, WidgetsBindingObserver {
  final AudioHandler _audioHandler; // Use base handler
  final DownloadService _downloadService;
  final ApiService _apiService;

  List<SongModel> _playlist = [];
  List<SongModel> _listeningHistory = []; 
  
  List<Map<String, dynamic>> _recentContexts = [];
  List<Map<String, dynamic>> get recentContexts => _recentContexts;

  List<SongModel> get listeningHistory => _listeningHistory;
  
  final ValueNotifier<SongModel?> currentSongNotifier = ValueNotifier(null);
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier(false);
  final ValueNotifier<Duration> currentDurationNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> totalDurationNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<bool> isRepeatNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isShuffleNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isAutoplayEnabled = ValueNotifier(true); // Default to true
  final ValueNotifier<String?> errorMessageNotifier = ValueNotifier(null);
  final ValueNotifier<Color?> currentAccentColorNotifier = ValueNotifier(null);

  // Music DNA Tracking
  Map<String, int> _playCounts = {};
  Duration _totalListeningTime = Duration.zero;
  Map<String, Map<String, dynamic>> _songMetadataCache = {};
  
  Map<String, int> get playCounts => _playCounts;
  
  Duration get totalListeningTime {
    if (_lastPlayStartTime != null && isPlayingNotifier.value) {
      return _totalListeningTime + DateTime.now().difference(_lastPlayStartTime!);
    }
    return _totalListeningTime;
  }
  
  Map<String, Map<String, dynamic>> get songMetadataCache => _songMetadataCache;

  bool isActive(String songId) {
    return currentSongNotifier.value?.id == songId;
  }

  SongModel? get currentSong => currentSongNotifier.value;
  bool get isPlaying => isPlayingNotifier.value;

  List<SongModel> _originalPlaylist = [];
  Timer? _positionSaveTimer;
  bool _isAutoplayTriggering = false;


  MusicService(this._audioHandler, this._downloadService, this._apiService); // Inject services

  void init() {
    // Listen to AudioHandler state
    _audioHandler.playbackState.listen((playbackState) {
      bool wasPlaying = isPlayingNotifier.value;
      isPlayingNotifier.value = playbackState.playing;
      currentDurationNotifier.value = playbackState.position;
      
      if (playbackState.playing && !wasPlaying) {
        _startListeningTimeTracking();
      } else if (!playbackState.playing && wasPlaying) {
        _stopListeningTimeTracking();
      }

      if (playbackState.processingState == AudioProcessingState.completed || 
          (playbackState.processingState == AudioProcessingState.idle && !playbackState.playing)) {
         // Use a small cooldown to avoid double-triggers
         if (!_isAutoplayTriggering) {
            _handleQueueEnd();
         }
      }
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
              artistId: mediaItem.extras?['artistId'],
              album: mediaItem.album ?? '',
              albumId: mediaItem.extras?['albumId'],
              imageUrl: mediaItem.artUri?.toString() ?? '',
              downloadUrl: mediaItem.extras?['url'] ?? '',
              hasLyrics: false, // Default
            ),
        );
        
        if (currentSongNotifier.value?.id != song.id) {
           debugPrint("🎵 MusicService: Setting currentSongNotifier to ${song.name}");
           currentSongNotifier.value = song;
           addToHistory(song);
           _updateAccentColor(song.imageUrl);
        }
        totalDurationNotifier.value = mediaItem.duration ?? Duration.zero;
      }
    });

    _loadHistory();
    _loadStats();
    
    // Lifecycle Monitoring
    WidgetsBinding.instance.addObserver(this);
    
    // Periodically save position while playing
    _positionSaveTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (isPlayingNotifier.value) {
        _saveStats();
      }
    });
  }

  Future<void> _handleQueueEnd() async {
    debugPrint("🎵 MusicService: _handleQueueEnd check - Autoplay: ${isAutoplayEnabled.value}, Triggering: $_isAutoplayTriggering");
    if (!isAutoplayEnabled.value || _isAutoplayTriggering) return;
    
    // Give the state a moment to stabilize
    await Future.delayed(const Duration(milliseconds: 200));

    final lastSong = currentSongNotifier.value;
    final currentIndex = currentQueueIndex;
    final queueLen = _playlist.length;
    
    debugPrint("🎵 MusicService: End Detection -> LastSong: ${lastSong?.name}, Index: $currentIndex, QueueLen: $queueLen");

    if (lastSong == null) return;

    // Check if we are at the end: Last index or single song in queue
    if (currentIndex >= queueLen - 1 || queueLen <= 1) {
       debugPrint("🎵 MusicService: Final Song detected! Triggering Smart Autoplay for ${lastSong.name}...");
       await _triggerSmartAutoplay(lastSong.id);
    } else {
       debugPrint("🎵 MusicService: Not at end of queue yet.");
    }
  }

  Future<void> _triggerSmartAutoplay(String songId) async {
    _isAutoplayTriggering = true;
    try {
      final current = currentSongNotifier.value;
      if (current == null) return;

      debugPrint("🎵 MusicService: Vibe Engine starting for ${current.name} [${current.genre} / ${current.language}]");

      // Reservoir for mixed suggestions
      List<SongModel> vibeMix = [];

      // 1. Vibe Match: Direct Suggestions (40%)
      final directSuggestions = await _apiService.getSuggestedSongs(songId);
      if (directSuggestions.isNotEmpty) {
        vibeMix.addAll(directSuggestions.take(6));
      }

      // 2. Style Match: Artist Top Songs (30%)
      if (current.artistId != null) {
        final artistDetails = await _apiService.getArtistDetails(current.artistId!);
        if (artistDetails['topSongs'] != null) {
          final artistSongs = List<SongModel>.from(artistDetails['topSongs']);
          artistSongs.removeWhere((s) => s.id == songId); // Don't repeat current
          vibeMix.addAll(artistSongs.take(5));
        }
      }

      // 3. Mood Match: Same Genre/Language Hits (30%)
      if (current.genre != null || current.language != null) {
        final genreHits = await _apiService.getSongsByGenre(current.genre, current.language);
        if (genreHits.isNotEmpty) {
          genreHits.removeWhere((s) => s.id == songId);
          vibeMix.addAll(genreHits.take(5));
        }
      }

      if (vibeMix.isNotEmpty) {
        // SMART SHUFFLE: Randomize the vibe mix to make it feel like a Radio station
        vibeMix.shuffle();
        
        debugPrint("🎵 MusicService: Vibe Mix created with ${vibeMix.length} diverse tracks.");
        
        // Add unique songs to queue
        int addedCount = 0;
        for (var song in vibeMix) {
          if (!_playlist.any((s) => s.id == song.id)) {
            await addToQueue(song);
            addedCount++;
          }
          if (addedCount >= 12) break; // Keep the next session concise
        }
        
        // Play next if stopped
        if (!isPlayingNotifier.value) {
           playNext();
        }
      } else {
        debugPrint("🎵 MusicService: Vibe Engine could not find any matches.");
      }
    } catch (e) {
      debugPrint("🎵 MusicService: Error in Vibe Engine: $e");
    } finally {
      _isAutoplayTriggering = false;
    }
  }

  // Method to recover last session without autoplay
  Future<void> _recoverSession(SharedPreferences prefs) async {
    try {
      final playlistJson = prefs.getString('last_playlist');
      final index = prefs.getInt('last_index') ?? 0;
      final positionMs = prefs.getInt('last_position_ms') ?? 0;
      final bool isRepeat = prefs.getBool('last_is_repeat') ?? false;
      final bool isShuffle = prefs.getBool('last_is_shuffle') ?? false;

      if (playlistJson != null && playlistJson.isNotEmpty) {
        final List<dynamic> decoded = json.decode(playlistJson);
        final List<SongModel> recoveredPlaylist = decoded
            .map((e) => SongModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();

        if (recoveredPlaylist.isNotEmpty) {
          _playlist = recoveredPlaylist;
          _originalPlaylist = List.from(recoveredPlaylist);
          isRepeatNotifier.value = isRepeat;
          isShuffleNotifier.value = isShuffle;

          // Update notifiers for UI
          SongModel currentSong = _playlist[index];
          currentSongNotifier.value = currentSong;
          currentDurationNotifier.value = Duration(milliseconds: positionMs);
          
          // CRITICAL: Fetch fresh details (URL & Duration) for the restored song
          // JioSaavn URLs expire, so we MUST get a fresh one or playback will fail
          _apiService.getSongDetails(currentSong.id).then((freshSong) {
            if (freshSong != null) {
              debugPrint("🎵 MusicService: Refetched fresh URL for ${freshSong.name}");
              
              // Only update if it's still the active song by the time API returns
              if (currentSongNotifier.value?.id == freshSong.id) {
                // Update the track in our playlist with the fresh data
                final actualIdx = _playlist.indexWhere((s) => s.id == freshSong.id);
                if (actualIdx != -1) {
                  _playlist[actualIdx] = freshSong;
                }
                currentSongNotifier.value = freshSong;
                
                // Restore total duration so progress bar shows correct percentage
                if (freshSong.duration != null && freshSong.duration!.isNotEmpty) {
                  final durationStr = freshSong.duration!;
                  if (durationStr.contains(':')) {
                    final parts = durationStr.split(':');
                    if (parts.length == 2) {
                      final mins = int.tryParse(parts[0]) ?? 0;
                      final secs = int.tryParse(parts[1]) ?? 0;
                      totalDurationNotifier.value = Duration(minutes: mins, seconds: secs);
                    }
                  } else {
                    final seconds = int.tryParse(durationStr) ?? 0;
                    if (seconds > 0) {
                      totalDurationNotifier.value = Duration(seconds: seconds);
                    }
                  }
                }
                
                // Update audio engine with fresh URL
                final mediaItems = _playlist.map((song) => _createMediaItem(song)).toList();
                final dynamic handler = _audioHandler;
                handler.preparePlaylist(mediaItems, actualIdx != -1 ? actualIdx : index);
                
                // Re-sync with handler positions (wait for source setup to complete)
                Future.delayed(const Duration(milliseconds: 1000), () async {
                  await handler.setInitialPosition(Duration(milliseconds: positionMs));
                  notifyListeners();
                });
              }
            } else {
                // Fallback if API fails
                final mediaItems = _playlist.map((song) => _createMediaItem(song)).toList();
                final dynamic handler = _audioHandler;
                handler.preparePlaylist(mediaItems, index);
            }
          });
          
          _updateAccentColor(currentSong.imageUrl);
          
          debugPrint("🎵 MusicService: Recovered session: ${currentSong.name} at $index");
        }
      }
    } catch (e) {
      debugPrint("Error recovering last playback session: $e");
    }
  }

  DateTime? _lastPlayStartTime;

  void _startListeningTimeTracking() {
    _lastPlayStartTime ??= DateTime.now();
  }

  void _stopListeningTimeTracking() {
    if (_lastPlayStartTime != null) {
      final sessionTime = DateTime.now().difference(_lastPlayStartTime!);
      _totalListeningTime += sessionTime;
      _lastPlayStartTime = null;
      _saveStats();
      notifyListeners();
    }
  }

  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    final countsJson = prefs.getString('play_counts') ?? '{}';
    _playCounts = Map<String, int>.from(json.decode(countsJson));
    final totalSeconds = prefs.getInt('total_listening_seconds') ?? 0;
    _totalListeningTime = Duration(seconds: totalSeconds);
    
    final cacheJson = prefs.getString('song_metadata_cache') ?? '{}';
    _songMetadataCache = Map<String, Map<String, dynamic>>.from(
      json.decode(cacheJson).map((key, value) => MapEntry(key, Map<String, dynamic>.from(value)))
    );

    final contextsJson = prefs.getString('recent_contexts');
    if (contextsJson != null) {
      try {
        final List<dynamic> decoded = json.decode(contextsJson);
        _recentContexts = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (e) {
        debugPrint('Error loading recent contexts: $e');
      }
    }
    
    notifyListeners();
    
    // Recover session last to ensure notifiers are ready
    await _recoverSession(prefs);
  }

  void logPlayContext(String id, String type, String title, String imageUrl, List<SongModel> songs) {
    if (songs.isEmpty) return;
    _recentContexts.removeWhere((c) => c['id'] == id);
    _recentContexts.insert(0, {
      'id': id,
      'type': type,
      'title': title,
      'image': imageUrl,
      'songs': songs.map((s) => s.toJson()).toList(),
    });
    if (_recentContexts.length > 20) {
      _recentContexts = _recentContexts.sublist(0, 20); // Keep up to 20 recent contexts
    }
    _saveStats();
    notifyListeners();
  }

  Future<void> _saveStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('play_counts', json.encode(_playCounts));
    await prefs.setInt('total_listening_seconds', _totalListeningTime.inSeconds);
    await prefs.setString('song_metadata_cache', json.encode(_songMetadataCache));
    
    // Save history locally so it persists across hot restarts and app launches
    final historyJsonList = _listeningHistory.map((s) => json.encode(s.toJson())).toList();
    await prefs.setStringList('listening_history', historyJsonList);
    
    await prefs.setString('recent_contexts', json.encode(_recentContexts));

    // Save playback session
    if (_playlist.isNotEmpty) {
      final playlistJson = json.encode(_playlist.map((s) => s.toJson()).toList());
      await prefs.setString('last_playlist', playlistJson);
      
      final dynamic handler = _audioHandler;
      await prefs.setInt('last_index', handler.currentIndex ?? 0);
      await prefs.setInt('last_position_ms', currentDurationNotifier.value.inMilliseconds);
      await prefs.setBool('last_is_repeat', isRepeatNotifier.value);
      await prefs.setBool('last_is_shuffle', isShuffleNotifier.value);
    }
  }

  Future<void> _updateAccentColor(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) {
      currentAccentColorNotifier.value = null;
      return;
    }

    try {
      final PaletteGenerator paletteGenerator = await PaletteGenerator.fromImageProvider(
        NetworkImage(imageUrl),
        maximumColorCount: 20,
      );

      // Prefer vibrant or dominant color
      final Color? color = paletteGenerator.vibrantColor?.color ?? 
                          paletteGenerator.dominantColor?.color;
      
      currentAccentColorNotifier.value = color;
      debugPrint("🎨 MusicService: Extracted accent color: $color");
    } catch (e) {
      debugPrint("🎨 MusicService: Color extraction failed: $e");
      currentAccentColorNotifier.value = null;
    }
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
      artistId: song.artistId,
      album: song.album,
      albumId: song.albumId,
      imageUrl: song.imageUrl,
      downloadUrl: song.downloadUrl,
      hasLyrics: song.hasLyrics,
      playedAt: DateTime.now(),
    );

    _listeningHistory.insert(0, historyEntry);
    
    if (_listeningHistory.length > 50) {
      _listeningHistory = _listeningHistory.sublist(0, 50);
    }
    
    // Update play counts
    _playCounts[song.id] = (_playCounts[song.id] ?? 0) + 1;
    
    // Cache metadata
    _songMetadataCache[song.id] = song.toJson();
    
    _saveStats();
    
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
    _stopListeningTimeTracking();
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
    final newMode = isRepeatNotifier.value ? AudioServiceRepeatMode.one : AudioServiceRepeatMode.none;
    _audioHandler.setRepeatMode(newMode);
    _saveStats();
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
    _saveStats();
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
    currentSongNotifier.value = null;
    notifyListeners();
  }
  @override
  void dispose() {
    // We don't own the handler, so we don't dispose it here usually, 
    // unless we want to stop background audio when UI closes (which we don't).
    WidgetsBinding.instance.removeObserver(this);
    _positionSaveTimer?.cancel();
    super.dispose();
  }

  // Handle Lifecycle for Auto-Save
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || 
        state == AppLifecycleState.inactive || 
        state == AppLifecycleState.detached) {
      debugPrint("🎵 MusicService: Saving stats due to lifecycle state Change: $state");
      _saveStats();
    }
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
      extras: {
        'url': url,
        'artistId': song.artistId,
        'albumId': song.albumId,
      },
    );
  }
}
