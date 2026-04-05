import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

class AudioPlayerHandler extends BaseAudioHandler with SeekHandler {
  ap.AudioPlayer _player = ap.AudioPlayer();
  List<MediaItem> _queue = [];
  int _index = 0;
  int _tracksPlayedCount = 0;

  AudioServiceRepeatMode _repeatMode = AudioServiceRepeatMode.none;

  bool _isSwitchingTrack = false;
  Timer? _stallTimer;
  Duration _lastCheckedPosition = Duration.zero;
  int _stallTicks = 0;
  int _bufferingTicks = 0;
  bool _playbackStarted = false;
  
  // Callback to fetch a fresh URL from the Service when needed (JIT)
  Future<String?> Function(String songId)? onGetFreshUrl;

  AudioPlayerHandler() {
    _initAudioSession();
    _setupPlayerListeners();
    _startHeartbeat();
  }

  void _setupPlayerListeners() {
    _player.setAudioContext(
      ap.AudioContext(
        android: const ap.AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: true,
          contentType: ap.AndroidContentType.music,
          usageType: ap.AndroidUsageType.media,
          audioFocus: ap.AndroidAudioFocus.gain,
        ),
        iOS: ap.AudioContextIOS(
          category: ap.AVAudioSessionCategory.playback,
          options: const {},
        ),
      ),
    );

    _player.setReleaseMode(ap.ReleaseMode.stop);

    _player.onPlayerComplete.listen((_) async {
      await Future.delayed(const Duration(milliseconds: 300));
      if (_repeatMode != AudioServiceRepeatMode.one) {
        await skipToNext();
      }
    });

    _player.onPositionChanged.listen((position) {
      if (position > Duration.zero) {
        if (!_playbackStarted) {
           _playbackStarted = true;
           debugPrint("🎵 AudioHandler: Playback CONFIRMED at $position ✅");
           playbackState.add(playbackState.value.copyWith(
              processingState: AudioProcessingState.ready,
              updatePosition: position,
           ));
        }
        _stallTicks = 0;
        _bufferingTicks = 0;
      }
      playbackState.add(playbackState.value.copyWith(updatePosition: position));
    });

    _player.onDurationChanged.listen((duration) {
      final oldMediaItem = mediaItem.value;
      if (oldMediaItem != null) {
        mediaItem.add(oldMediaItem.copyWith(duration: duration));
      }
    });

    _player.onPlayerStateChanged.listen((state) {
      // CRITICAL: Block all native state updates during track switching
      // or if the session is logically in buffering state to prevent clearing notification
      if (_isSwitchingTrack || playbackState.value.processingState == AudioProcessingState.buffering) {
        if (state == ap.PlayerState.stopped || state == ap.PlayerState.completed) {
          return;
        }
      }

      final playing = state == ap.PlayerState.playing;
      playbackState.add(
        playbackState.value.copyWith(
          playing: playing,
          controls: [
            MediaControl.skipToPrevious,
            playing ? MediaControl.pause : MediaControl.play,
            MediaControl.skipToNext,
          ],
          processingState: {
            ap.PlayerState.stopped: AudioProcessingState.idle,
            ap.PlayerState.playing: AudioProcessingState.ready,
            ap.PlayerState.paused: AudioProcessingState.ready,
            ap.PlayerState.completed: AudioProcessingState.completed,
            ap.PlayerState.disposed: AudioProcessingState.idle,
          }[state]!,
        ),
      );
    });
  }

  void _startHeartbeat() {
    _stallTimer?.cancel();
    _stallTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
       if (_isSwitchingTrack) return;

       final state = playbackState.value;
       final playerState = _player.state;
       final isNativePlaying = playerState == ap.PlayerState.playing;

       if (state.playing && state.processingState == AudioProcessingState.buffering) {
         _bufferingTicks++;
         if (_bufferingTicks >= 10) { 
           debugPrint("🚨 AudioHandler: INITIAL BUFFERING TIMEOUT! Re-creating player...");
           _bufferingTicks = 0;
           await _recreatePlayerAndRetry();
         }
       } else {
         _bufferingTicks = 0;
       }

       if (state.playing && state.processingState == AudioProcessingState.ready) {
         final currentPos = state.position;
         if (currentPos == _lastCheckedPosition && currentPos > Duration.zero) {
           _stallTicks++;
           if (_stallTicks >= 5) { 
             debugPrint("🚨 AudioHandler: GHOST STALL detected! Full reset...");
             playbackState.add(state.copyWith(processingState: AudioProcessingState.buffering));
             _stallTicks = 0;
             await _recreatePlayerAndRetry();
           }
         } else {
           _stallTicks = 0;
         }
         _lastCheckedPosition = currentPos;
       }

       if (state.playing && !isNativePlaying && _playbackStarted) {
          debugPrint("🚨 AudioHandler: Native Pause Sync Fix.");
          playbackState.add(state.copyWith(playing: false));
       }
    });
  }

  Future<void> _recreatePlayerAndRetry() async {
    debugPrint("🔥 AudioHandler: KILLING and RE-CREATING player instance to clear native hang 🔥");
    try {
      await _player.stop();
      await _player.dispose();
    } catch (_) {}
    
    _player = ap.AudioPlayer();
    _setupPlayerListeners();
    await _playCurrent();
  }

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }

  String? get currentSongTitle => mediaItem.value?.title;

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    _repeatMode = repeatMode;
    playbackState.add(playbackState.value.copyWith(repeatMode: repeatMode));
    if (repeatMode == AudioServiceRepeatMode.one) {
      await _player.setReleaseMode(ap.ReleaseMode.loop);
    } else {
      await _player.setReleaseMode(ap.ReleaseMode.stop);
    }
  }

  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems) async {
    _queue = mediaItems;
    // Broadcast the new queue (optional, if UI needs to know)
    queue.add(_queue);
  }

  // Custom method to set playlist and play specific index
  Future<void> setPlaylist(List<MediaItem> items, int index) async {
    _queue = items;
    _index = index;
    queue.add(_queue);
    await _playCurrent();
  }

  // New method to prepare a playlist WITHOUT automatically playing
  Future<void> preparePlaylist(List<MediaItem> items, int index) async {
    _queue = items;
    _index = index;
    queue.add(_queue);
    
    if (_queue.isNotEmpty && _index >= 0 && _index < _queue.length) {
      final item = _queue[_index];
      debugPrint("🎵 AudioHandler: Preparing mediaItem ${item.title}");
      mediaItem.add(item);
      
      // Update playback state to ready but PAUSED
      playbackState.add(
        playbackState.value.copyWith(
          playing: false,
          controls: const [
            MediaControl.skipToPrevious,
            MediaControl.play,
            MediaControl.skipToNext,
          ],
          systemActions: const {
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
          },
          processingState: AudioProcessingState.ready,
        ),
      );

      // CRITICAL: Set the source on the player so resume() works
      try {
        final url = item.extras?['url'] as String?;
        if (url != null && url.isNotEmpty) {
          if (url.startsWith('http')) {
            await _player.setSource(ap.UrlSource(url));
          } else {
            await _player.setSource(ap.DeviceFileSource(url));
          }
        }
      } catch (e) {
        debugPrint("Error preparing source: $e");
      }
    }
  }

  // Set initial position for resume
  Future<void> setInitialPosition(Duration position) async {
    playbackState.add(playbackState.value.copyWith(updatePosition: position));
    // Also seek the actual player
    await _player.seek(position);
  }

  // Set initial repeat mode
  void setInitialRepeatMode(AudioServiceRepeatMode repeatMode) {
    _repeatMode = repeatMode;
    playbackState.add(playbackState.value.copyWith(repeatMode: repeatMode));
  }

  Future<void> _playCurrent() async {
    if (_queue.isEmpty || _index < 0 || _index >= _queue.length) return;

    final item = _queue[_index];
    _isSwitchingTrack = true; // Block native state updates

    try {
      debugPrint("🎵 AudioHandler: ATOMIC START for ${item.title}");
      
      // 1. Set MediaItem IMMEDIATELY for the system
      mediaItem.add(item);

      // 2. Stop/Release previous content first (native reset)
      try {
        await _player.stop();
        await _player.release(); 
      } catch (e) {
         debugPrint("Note: Native reset failed (non-critical): $e");
      }

      // 3. IMMEDIATELY RE-ASSERT the Media Session after native reset
      // This ensures the OS never thinks playback has stopped.
      playbackState.add(
        playbackState.value.copyWith(
          playing: true,
          processingState: AudioProcessingState.buffering,
          controls: [
            MediaControl.skipToPrevious,
            MediaControl.pause, 
            MediaControl.skipToNext,
          ],
          systemActions: const {
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
          },
        ),
      );

      // 4. Ensure Audio Session is active
      final session = await AudioSession.instance;
      await session.setActive(true);

      String? url = item.extras?['url'] as String?;

      // 5. JIT URL REFRESH (Async heavy lifting)
      if (url != null && url.startsWith('http') && onGetFreshUrl != null) {
        debugPrint("🎵 AudioHandler: Refreshing URL for ${item.title}...");
        final freshUrl = await onGetFreshUrl!(item.id);
        if (freshUrl != null && freshUrl.isNotEmpty) {
          url = freshUrl;
          final updatedItem = item.copyWith(
            extras: {...item.extras ?? {}, 'url': freshUrl},
          );
          _queue[_index] = updatedItem;
          // Redundant update to ensure title/artwork is still there
          mediaItem.add(updatedItem); 
        }
      }

      if (url != null && url.isNotEmpty) {
        final cacheBustUrl = url.contains('?') 
          ? "$url&cb=${DateTime.now().millisecondsSinceEpoch}"
          : "$url?cb=${DateTime.now().millisecondsSinceEpoch}";
        
        debugPrint("🎵 AudioHandler: Native Play trigger...");
        
        _tracksPlayedCount++;
        if (_tracksPlayedCount >= 10) { // Increased to 10 for better stability
          _tracksPlayedCount = 0;
          await _player.dispose();
          _player = ap.AudioPlayer();
          _setupPlayerListeners();
        }

        if (url.startsWith('http')) {
          await _player.play(ap.UrlSource(cacheBustUrl));
        } else {
          await _player.play(ap.DeviceFileSource(url));
        }
      }

      // Reset Health Tracking
      _lastCheckedPosition = Duration.zero;
      _stallTicks = 0;
      _bufferingTicks = 0;
      _playbackStarted = false;

      // Finish atomic cycle
      _isSwitchingTrack = false;
      
      // Ensure we stay in BUFFERING state until real movement starts
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.buffering,
        playing: true,
      ));
    } catch (e) {
      _isSwitchingTrack = false;
      debugPrint("🚨 AudioHandler: CRITICAL ERROR playing audio: $e");
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.idle,
        playing: false,
      ));
    }
  }

  @override
  Future<void> play() => _player.resume();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> onTaskRemoved() async {
    await stop();
  }

  @override
  Future<void> stop() async {
    _stallTimer?.cancel();
    _stallTimer = null;
    await _player.stop();
    playbackState.add(
      playbackState.value.copyWith(
        playing: false,
        processingState: AudioProcessingState.idle,
      ),
    );
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_queue.isEmpty) return;
    if (_index < _queue.length - 1) {
      _index++;
      await _playCurrent();
    } else {
      if (_repeatMode == AudioServiceRepeatMode.all) {
        _index = 0;
        await _playCurrent();
      } else {
        await stop();
      }
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_queue.isEmpty) return;

    // Smart previous: if more than 3 seconds into the song, restart it
    final currentPosition = await _player.getCurrentPosition();
    if (currentPosition != null && currentPosition.inSeconds > 3) {
      await seek(Duration.zero);
    } else {
      // Go to previous song
      if (_index > 0) {
        _index--;
        await _playCurrent();
      } else {
        // Already at first song, just restart it
        await seek(Duration.zero);
      }
    }
  }

  // Add song to play next (after current song)
  Future<void> addToPlayNext(MediaItem item) async {
    if (_queue.isEmpty) {
      _queue.add(item);
      _index = 0;
      queue.add(_queue);
      await _playCurrent();
    } else {
      _queue.insert(_index + 1, item);
      queue.add(_queue);
    }
  }

  // Add song to end of queue
  Future<void> addToQueue(MediaItem item) async {
    _queue.add(item);
    queue.add(_queue);
    if (_queue.length == 1) {
      _index = 0;
      await _playCurrent();
    }
  }

  // Remove song from queue by index
  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= _queue.length) return;

    if (index == _index) {
      // Removing current song, skip to next
      await skipToNext();
    } else if (index < _index) {
      // Removing song before current, adjust index
      _index--;
    }

    _queue.removeAt(index);
    queue.add(_queue);
  }

  // Skip to specific queue index
  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _index = index;
    await _playCurrent();
  }

  // Reorder queue
  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _queue.length) return;
    if (newIndex < 0 || newIndex >= _queue.length) return;

    final item = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, item);

    // Adjust current index if needed
    if (oldIndex == _index) {
      _index = newIndex;
    } else if (oldIndex < _index && newIndex >= _index) {
      _index--;
    } else if (oldIndex > _index && newIndex <= _index) {
      _index++;
    }

    queue.add(_queue);
  }

  // Clear queue
  Future<void> clearQueue() async {
    await stop();
    _queue.clear();
    _index = 0;
    queue.add(_queue);
  }

  // Get current queue index
  int get currentIndex => _index;

  // Get queue length
  int get queueLength => _queue.length;
}
