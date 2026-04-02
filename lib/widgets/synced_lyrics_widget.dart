import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:provider/provider.dart';
import '../services/music_service.dart';

class LrcLine {
  final Duration timestamp;
  final String text;

  LrcLine({required this.timestamp, required this.text});
}

class SyncedLyricsWidget extends StatefulWidget {
  final SongModel song;

  const SyncedLyricsWidget({super.key, required this.song});

  @override
  State<SyncedLyricsWidget> createState() => _SyncedLyricsWidgetState();
}

class _SyncedLyricsWidgetState extends State<SyncedLyricsWidget> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ScrollOffsetController _scrollOffsetController = ScrollOffsetController();
  
  List<LrcLine> _syncedLines = [];
  String? _plainLyrics;
  bool _isLoading = true;
  bool _isError = false;
  int _currentLineIndex = -1;
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    _fetchLyrics();
  }

  @override
  void didUpdateWidget(SyncedLyricsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.id != widget.song.id || oldWidget.song.name != widget.song.name) {
      _fetchLyrics();
    }
  }

  Future<void> _fetchLyrics() async {
    setState(() {
      _isLoading = true;
      _isError = false;
      _syncedLines = [];
      _plainLyrics = null;
      _currentLineIndex = -1;
    });

    _syncTimer?.cancel();

    try {
      final uri = Uri.parse(
          'https://lrclib.net/api/get?artist_name=${Uri.encodeComponent(widget.song.artist)}&track_name=${Uri.encodeComponent(widget.song.name)}');
      
      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final syncedStr = data['syncedLyrics'];
        final plainStr = data['plainLyrics'];

        if (syncedStr != null && syncedStr.toString().trim().isNotEmpty) {
          _parseSyncedLyrics(syncedStr.toString());
          _startSyncing();
        } else if (plainStr != null && plainStr.toString().trim().isNotEmpty) {
          _plainLyrics = plainStr.toString();
        } else {
          _isError = true;
        }
      } else {
        _isError = true;
      }
    } catch (e) {
      _isError = true;
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _parseSyncedLyrics(String lrc) {
    final lines = lrc.split('\n');
    final RegExp timeRegExp = RegExp(r'\[(\d+):(\d+)\.(\d+)\](.*)');
    
    _syncedLines = [];
    for (String line in lines) {
      final match = timeRegExp.firstMatch(line);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        int milliseconds = int.parse(match.group(3)!);
        
        if (match.group(3)!.length == 2) {
          milliseconds *= 10;
        }
        
        final text = match.group(4)!.trim();
        
        if (text.isNotEmpty) {
           _syncedLines.add(LrcLine(
             timestamp: Duration(
               minutes: minutes,
               seconds: seconds,
               milliseconds: milliseconds,
             ),
             text: text,
           ));
        }
      }
    }
  }

  void _startSyncing() {
    _syncTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      final musicService = context.read<MusicService>();
      final position = musicService.currentDurationNotifier.value;
      
      if (_syncedLines.isEmpty) return;
      
      int newIndex = _syncedLines.lastIndexWhere((line) => line.timestamp <= position);
      if (newIndex == -1 && _syncedLines.isNotEmpty) {
        // If before the first line, we might still want to highlight nothing, or default
        newIndex = -1; // -1 means no active line
      }
      
      if (newIndex != _currentLineIndex) {
        setState(() {
          _currentLineIndex = newIndex;
        });
        
        if (newIndex >= 0 && _itemScrollController.isAttached) {
          _itemScrollController.scrollTo(
            index: newIndex,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            alignment: 0.4, // Keep current line relatively centered
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 400,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_isError || (_syncedLines.isEmpty && _plainLyrics == null)) {
      return _buildMessage(
        widget.song.name.toLowerCase().contains("instrumental") 
            ? "No lyrics for this song" 
            : "Lyrics not available"
      );
    }

    final musicService = context.read<MusicService>();

    return ValueListenableBuilder<Color?>(
      valueListenable: musicService.currentAccentColorNotifier,
      builder: (context, accentColor, _) {
        final baseColor = accentColor ?? const Color(0xFFFF6600);
        
        return Container(
          height: 400,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A), // Deep clean charcoal
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                baseColor.withValues(alpha: 0.15), // Very subtle accent glow
                const Color(0xFF121212),          // Deep black/grey
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: baseColor.withValues(alpha: 0.1),
                blurRadius: 20,
                spreadRadius: -10,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: _syncedLines.isNotEmpty ? _buildSyncedView() : _buildPlainView(),
        );
      },
    );
  }

  Widget _buildSyncedView() {
    return ScrollablePositionedList.builder(
      itemScrollController: _itemScrollController,
      scrollOffsetController: _scrollOffsetController,
      padding: const EdgeInsets.symmetric(vertical: 150, horizontal: 20),
      itemCount: _syncedLines.length,
      itemBuilder: (context, index) {
        final line = _syncedLines[index];
        final isActive = index == _currentLineIndex;
        // Lines can fade even when not active
        final isPast = index < _currentLineIndex;
        
        return GestureDetector(
          onTap: () {
            context.read<MusicService>().seek(line.timestamp);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              line.text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isActive 
                    ? Colors.white 
                    : isPast 
                        ? Colors.white.withValues(alpha: 0.3) 
                        : Colors.white.withValues(alpha: 0.5),
                fontSize: isActive ? 26 : 18,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlainView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      child: Center(
        child: Text(
          _plainLyrics ?? "",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 18,
            height: 1.8,
          ),
        ),
      ),
    );
  }

  Widget _buildMessage(String message) {
    return Container(
       height: 400,
       decoration: BoxDecoration(
         color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
         borderRadius: BorderRadius.circular(16),
       ),
       child: Center(
         child: Text(
           message,
           style: TextStyle(
             color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
             fontSize: 16,
           ),
         ),
       ),
    );
  }
}

