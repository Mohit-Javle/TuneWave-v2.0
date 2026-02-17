import 'package:flutter/material.dart';

class LyricLine {
  final Duration timestamp;
  final String text;

  LyricLine({required this.timestamp, required this.text});

  static List<LyricLine> parseLyrics(String rawLyrics) {
    final lines = rawLyrics.split('\n');
    final List<LyricLine> lyricLines = [];
    
    // Try to parse LRC format first (e.g., [00:12.00]Lyric text)
    final lrcRegex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2})\](.*)');
    
    for (var line in lines) {
      final match = lrcRegex.firstMatch(line);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final milliseconds = int.parse(match.group(3)!) * 10;
        final text = match.group(4)!.trim();
        
        if (text.isNotEmpty) {
          lyricLines.add(LyricLine(
            timestamp: Duration(
              minutes: minutes,
              seconds: seconds,
              milliseconds: milliseconds,
            ),
            text: text,
          ));
        }
      } else if (line.trim().isNotEmpty) {
        // If not LRC format, add as plain text with estimated timing
        lyricLines.add(LyricLine(
          timestamp: Duration(seconds: lyricLines.length * 3),
          text: line.trim(),
        ));
      }
    }
    
    return lyricLines;
  }
}

class SyncedLyricsWidget extends StatefulWidget {
  final String lyrics;
  final Duration currentPosition;
  final Function(Duration) onSeek;

  const SyncedLyricsWidget({
    super.key,
    required this.lyrics,
    required this.currentPosition,
    required this.onSeek,
  });

  @override
  State<SyncedLyricsWidget> createState() => _SyncedLyricsWidgetState();
}

class _SyncedLyricsWidgetState extends State<SyncedLyricsWidget> {
  late List<LyricLine> _lyricLines;
  final ScrollController _scrollController = ScrollController();
  int _currentLineIndex = 0;

  @override
  void initState() {
    super.initState();
    _lyricLines = LyricLine.parseLyrics(widget.lyrics);
  }

  @override
  void didUpdateWidget(SyncedLyricsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lyrics != widget.lyrics) {
      _lyricLines = LyricLine.parseLyrics(widget.lyrics);
    }
    _updateCurrentLine();
  }

  void _updateCurrentLine() {
    int newIndex = 0;
    for (int i = 0; i < _lyricLines.length; i++) {
      if (_lyricLines[i].timestamp <= widget.currentPosition) {
        newIndex = i;
      } else {
        break;
      }
    }

    if (newIndex != _currentLineIndex) {
      setState(() {
        _currentLineIndex = newIndex;
      });
      _scrollToCurrentLine();
    }
  }

  void _scrollToCurrentLine() {
    if (_scrollController.hasClients && _lyricLines.isNotEmpty) {
      final position = _currentLineIndex * 60.0; // Approximate line height
      _scrollController.animateTo(
        position,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_lyricLines.isEmpty) {
      return Center(
        child: Text(
          'No lyrics available',
          style: TextStyle(
            color: theme.colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 100),
      itemCount: _lyricLines.length,
      itemBuilder: (context, index) {
        final line = _lyricLines[index];
        final isActive = index == _currentLineIndex;
        final isPast = index < _currentLineIndex;

        return GestureDetector(
          onTap: () => widget.onSeek(line.timestamp),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
            child: Text(
              line.text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isActive ? 24 : 18,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive
                    ? const Color(0xFFFF6600)
                    : isPast
                        ? theme.colorScheme.onSurface.withOpacity(0.5)
                        : theme.colorScheme.onSurface.withOpacity(0.7),
                height: 1.5,
              ),
            ),
          ),
        );
      },
    );
  }
}
