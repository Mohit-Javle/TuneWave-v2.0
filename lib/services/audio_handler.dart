import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

class AudioPlayerHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  final ConcatenatingAudioSource _playlist = ConcatenatingAudioSource(children: []);
  final List<MediaItem> _queue = [];
  
  // Callback to fetch a fresh URL from the Service when needed (JIT)
  Future<String?> Function(String songId)? onGetFreshUrl;

  AudioPlayerHandler() {
    _initAudioSession();
    _setupPlayerListeners();
  }

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }

  void _setupPlayerListeners() {
    // 1. Listen to sequence state
    _player.sequenceStateStream.listen((state) {
      if (state == null) return;
      final sequence = state.sequence;
      if (sequence.isEmpty) return;
      
      final currentItem = sequence[state.currentIndex];
      final mediaItem = currentItem.tag as MediaItem;
      this.mediaItem.add(mediaItem);
    });

    // 2. Listen to player state
    _player.playerStateStream.listen((state) {
      final playing = state.playing;
      final processingState = state.processingState;
      debugPrint("🎵 AudioHandler: Player State: $processingState, playing: $playing");
      
      playbackState.add(PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        playing: playing,
        processingState: {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[processingState]!,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
      ));
    });

    // 3. Handle position updates
    _player.positionStream.listen((position) {
      playbackState.add(playbackState.value.copyWith(
        updatePosition: position,
      ));
    });

    // 4. Handle duration updates
    _player.durationStream.listen((duration) {
      if (duration == null) return;
      final currentItem = mediaItem.value;
      if (currentItem != null) {
        mediaItem.add(currentItem.copyWith(duration: duration));
      }
    });

    // 5. Sync media item when index changes
    _player.currentIndexStream.listen((index) {
      if (index != null && index < _queue.length) {
        final item = _queue[index].copyWith(duration: _player.duration);
        mediaItem.add(item);
      }
    });

    // 6. Handle playback errors
    _player.playbackEventStream.listen((event) {}, onError: (Object e, StackTrace st) {
      if (e is PlayerException) {
        debugPrint('🚨 AudioHandler: Native Player Error: ${e.message}');
      } else {
        debugPrint('🚨 AudioHandler: Native Error: $e');
      }
    });
  }

  @override
  Future<void> play() => _player.play();

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
  Future<void> seek(Duration position) {
    debugPrint("🎵 AudioHandler: Seeking to $position");
    return _player.seek(position);
  }

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    playbackState.add(playbackState.value.copyWith(repeatMode: repeatMode));
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        await _player.setLoopMode(LoopMode.off);
        break;
      case AudioServiceRepeatMode.one:
        await _player.setLoopMode(LoopMode.one);
        break;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        await _player.setLoopMode(LoopMode.all);
        break;
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final enabled = shuffleMode == AudioServiceShuffleMode.all;
    await _player.setShuffleModeEnabled(enabled);
    playbackState.add(playbackState.value.copyWith(shuffleMode: shuffleMode));
  }

  // --- Queue Management ---

  Future<void> setPlaylist(List<MediaItem> items, int initialIndex) async {
    _queue.clear();
    _queue.addAll(items);
    queue.add(items);

    final sources = items.map((item) => _createAudioSource(item)).toList();
    await _playlist.clear();
    await _playlist.addAll(sources);

    try {
      final session = await AudioSession.instance;
      await session.setActive(true);
      
      await _player.setAudioSource(_playlist, initialIndex: initialIndex);
      if (initialIndex >= 0 && initialIndex < items.length) {
        mediaItem.add(items[initialIndex]);
      }
      await _player.play();
    } catch (e) {
      debugPrint("🚨 AudioHandler: Error setting/playing playlist: $e");
    }
  }

  Future<void> preparePlaylist(List<MediaItem> items, int initialIndex) async {
    _queue.clear();
    _queue.addAll(items);
    queue.add(items);

    final sources = items.map((item) => _createAudioSource(item)).toList();
    await _playlist.clear();
    await _playlist.addAll(sources);

    try {
      final session = await AudioSession.instance;
      await session.setActive(true);
      
      await _player.setAudioSource(_playlist, initialIndex: initialIndex);
      if (initialIndex >= 0 && initialIndex < items.length) {
        mediaItem.add(items[initialIndex]);
      }
    } catch (e) {
      debugPrint("🚨 AudioHandler: Error preparing playlist: $e");
    }
  }

  Future<void> setInitialPosition(Duration position) async {
    await _player.seek(position);
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _playlist.length) return;
    await _player.seek(Duration.zero, index: index);
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    _queue.add(mediaItem);
    queue.add(_queue);
    await _playlist.add(_createAudioSource(mediaItem));
  }

  Future<void> addToPlayNext(MediaItem mediaItem) async {
    final index = _player.currentIndex ?? 0;
    _queue.insert(index + 1, mediaItem);
    queue.add(_queue);
    await _playlist.insert(index + 1, _createAudioSource(mediaItem));
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    if (index < 0 || index >= _playlist.length) return;
    _queue.removeAt(index);
    queue.add(_queue);
    await _playlist.removeAt(index);
  }

  @override
  Future<void> updateQueue(List<MediaItem> queue) async {
    _queue.clear();
    _queue.addAll(queue);
    this.queue.add(queue);
    final sources = queue.map((item) => _createAudioSource(item)).toList();
    await _playlist.clear();
    await _playlist.addAll(sources);
  }

  AudioSource _createAudioSource(MediaItem item) {
    final url = item.extras?['url'] as String?;
    if (url != null && url.isNotEmpty) {
      if (url.startsWith('http')) {
        return AudioSource.uri(
          Uri.parse(url), 
          tag: item,
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
          },
        );
      } else {
        return AudioSource.file(url, tag: item);
      }
    }
    return AudioSource.uri(Uri.parse(""), tag: item);
  }

  int? get currentIndex => _player.currentIndex;

  @override
  Future<void> onTaskRemoved() async {
    await stop();
    await _player.dispose();
  }
}
