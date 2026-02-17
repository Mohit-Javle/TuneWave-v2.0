
import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioPlayerHandler extends BaseAudioHandler with SeekHandler {
  final _player = AudioPlayer();
  List<MediaItem> _queue = [];
  int _index = 0;

  AudioPlayerHandler() {
    _player.onPlayerComplete.listen((_) {
      skipToNext();
    });

    _player.onPositionChanged.listen((position) {
      playbackState.add(playbackState.value.copyWith(
        updatePosition: position,
      ));
    });

    _player.onDurationChanged.listen((duration) {
      final oldMediaItem = mediaItem.value;
      if (oldMediaItem != null) {
        mediaItem.add(oldMediaItem.copyWith(duration: duration));
      }
    });

    _player.onPlayerStateChanged.listen((state) {
      playbackState.add(playbackState.value.copyWith(
        playing: state == PlayerState.playing,
        processingState: {
          PlayerState.stopped: AudioProcessingState.idle,
          PlayerState.playing: AudioProcessingState.ready,
          PlayerState.paused: AudioProcessingState.ready,
          PlayerState.completed: AudioProcessingState.completed,
          PlayerState.disposed: AudioProcessingState.idle,
        }[state]!,
      ));
    });
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

  Future<void> _playCurrent() async {
    if (_queue.isEmpty || _index < 0 || _index >= _queue.length) return;
    
    final item = _queue[_index];
    mediaItem.add(item);
    
    try {
      await _player.stop();
      final url = item.extras?['url'] as String?;
      
      if (url != null && url.isNotEmpty) {
         if (url.startsWith('http')) {
           await _player.play(UrlSource(url));
         } else {
           // Assume local file
           await _player.play(DeviceFileSource(url));
         }
      }
      
      playbackState.add(playbackState.value.copyWith(
        playing: true,
        controls: [
          MediaControl.skipToPrevious,
          MediaControl.pause,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        processingState: AudioProcessingState.ready,
      ));
    } catch (e) {
      debugPrint("Error playing audio: $e");
    }
  }

  @override
  Future<void> play() => _player.resume();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    playbackState.add(playbackState.value.copyWith(
      playing: false,
      processingState: AudioProcessingState.idle,
    ));
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
      // Loop back or stop? Let's stop for now, or loop if repeat is on (logic can be added)
      await stop();
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
