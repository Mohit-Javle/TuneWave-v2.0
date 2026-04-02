import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioPlayerHandler extends BaseAudioHandler with SeekHandler {
  final _player = AudioPlayer();
  List<MediaItem> _queue = [];
  int _index = 0;

  AudioServiceRepeatMode _repeatMode = AudioServiceRepeatMode.none;

  bool _isSwitchingTrack = false;

  AudioPlayerHandler() {
    _player.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: true,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gain,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const {},
        ),
      ),
    );

    _player.setReleaseMode(ReleaseMode.stop);

    _player.onPlayerComplete.listen((_) async {
      // Give native player a short time to clean up
      await Future.delayed(const Duration(milliseconds: 300));
      if (_repeatMode != AudioServiceRepeatMode.one) {
        await skipToNext();
      }
    });

    _player.onPositionChanged.listen((position) {
      playbackState.add(playbackState.value.copyWith(updatePosition: position));
    });

    _player.onDurationChanged.listen((duration) {
      final oldMediaItem = mediaItem.value;
      if (oldMediaItem != null) {
        mediaItem.add(oldMediaItem.copyWith(duration: duration));
      }
    });

    _player.onLog.listen((log) {
      if (log.contains('Source set successfully') || log.contains('Buffering')) {
         // Silently handle
      }
    });

    _player.onPlayerStateChanged.listen((state) {
      // If we are actively switching tracks, don't let it drop to idle/stopped
      // as that causes notification flickering.
      if (_isSwitchingTrack && (state == PlayerState.stopped || state == PlayerState.completed)) {
        return;
      }

      final playing = state == PlayerState.playing;
      playbackState.add(
        playbackState.value.copyWith(
          playing: playing,
          controls: [
            MediaControl.skipToPrevious,
            playing ? MediaControl.pause : MediaControl.play,
            MediaControl.skipToNext,
          ],
          processingState: {
            PlayerState.stopped: AudioProcessingState.idle,
            PlayerState.playing: AudioProcessingState.ready,
            PlayerState.paused: AudioProcessingState.ready,
            PlayerState.completed: AudioProcessingState.completed,
            PlayerState.disposed: AudioProcessingState.idle,
          }[state]!,
        ),
      );
    });
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    _repeatMode = repeatMode;
    playbackState.add(playbackState.value.copyWith(repeatMode: repeatMode));
    if (repeatMode == AudioServiceRepeatMode.one) {
      await _player.setReleaseMode(ReleaseMode.loop);
    } else {
      await _player.setReleaseMode(ReleaseMode.stop);
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
            await _player.setSource(UrlSource(url));
          } else {
            await _player.setSource(DeviceFileSource(url));
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
    _isSwitchingTrack = true; // Block idle state updates

    debugPrint("🎵 AudioHandler: Setting mediaItem to ${item.title}");
    mediaItem.add(item);

    // Promptly set state to buffering so notification title updates but keeps 'busy' state
    playbackState.add(
      playbackState.value.copyWith(
        playing: true, // Keep it true to maintain notification presence
        processingState: AudioProcessingState.buffering,
        controls: [
          MediaControl.skipToPrevious,
          MediaControl.pause, // Show pause while buffering
          MediaControl.skipToNext,
        ],
      ),
    );

    try {
      final url = item.extras?['url'] as String?;

      if (url != null && url.isNotEmpty) {
        // Ensure the old stream is stopped before playing new audio
        await _player.stop();
        
        if (url.startsWith('http')) {
          await _player.play(UrlSource(url));
        } else {
          await _player.play(DeviceFileSource(url));
        }
      }

      // Finish switching
      _isSwitchingTrack = false;
      
      playbackState.add(
        playbackState.value.copyWith(
          playing: true,
          systemActions: const {
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
          },
          processingState: AudioProcessingState.ready,
        ),
      );
    } catch (e) {
      _isSwitchingTrack = false;
      debugPrint("Error playing audio: $e");
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
