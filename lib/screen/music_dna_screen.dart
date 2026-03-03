import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/music_service.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:io';
import 'dart:async';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/music_toast.dart';

import '../services/api_service.dart';

class MusicDNAScreen extends StatefulWidget {
  const MusicDNAScreen({super.key});

  @override
  State<MusicDNAScreen> createState() => _MusicDNAScreenState();
}

class _MusicDNAScreenState extends State<MusicDNAScreen> {
  final GlobalKey _globalKey = GlobalKey();
  
  String? _fetchedArtistName;
  String? _fetchedArtistImage;
  
  String? _fetchedAlbumId;
  String? _fetchedAlbumImage;

  Future<void> _fetchArtistImage(String artistName) async {
    if (artistName.isEmpty || artistName == 'Unknown') return;
    try {
      final results = await ApiService().searchArtists(artistName);
      if (results.isNotEmpty && mounted) {
        setState(() {
          String rawUrl = results.first.imageUrl;
          // JioSaavn format image URL cleanup for artists
          if (rawUrl.contains('150x150')) {
             rawUrl = rawUrl.replaceAll('150x150', '500x500');
          } else if (rawUrl.contains('50x50')) {
             rawUrl = rawUrl.replaceAll('50x50', '500x500');
          }
          _fetchedArtistImage = rawUrl;
        });
      }
    } catch (e) {
      debugPrint("Failed to fetch artist image: $e");
    }
  }

  Future<void> _fetchAlbumImage(String albumId) async {
    if (albumId.isEmpty) return;
    try {
      final results = await ApiService().getAlbumDetails(albumId);
      if (results.isNotEmpty && mounted) {
        setState(() {
          // The first song in the album contains the album's image URL
          _fetchedAlbumImage = results.first.imageUrl.toString().replaceAll(RegExp(r'(?:150x150|50x50)'), '500x500');
        });
      }
    } catch (e) {
      debugPrint("Failed to fetch album image: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Music DNA',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
      body: Consumer<MusicService>(
        builder: (context, musicService, child) {
          final stats = _calculateStats(musicService);
          
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                children: [
                  // The Collage Card
                  RepaintBoundary(
                    key: _globalKey,
                    child: AspectRatio(
                      aspectRatio: 9 / 16,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isDark 
                                ? [Colors.grey[900]!, Colors.black]
                                : [Colors.white, Colors.grey[50]!],
                          ),
                          borderRadius: BorderRadius.circular(40), // Softer corners
                          boxShadow: [
                            BoxShadow(
                              color: (isDark ? Colors.purple : Colors.deepOrange).withValues(alpha: 0.15),
                              blurRadius: 50,
                              spreadRadius: 5,
                            ),
                            if (!isDark) 
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 10), // Extra top spacing
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'MUSICAL\nIDENTITY',
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black,
                                    fontSize: 34,
                                    fontWeight: ui.FontWeight.w900,
                                    letterSpacing: 1.5,
                                    height: 1.1,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.03),
                                  ),
                                  child: Image.asset('assets/images/logo.png', height: 42),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            
                            // Grid Layout for Stats
                            Expanded(
                              child: GridView.count(
                                crossAxisCount: 2,
                                childAspectRatio: 0.85,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                physics: const NeverScrollableScrollPhysics(),
                                children: [
                                  _buildStatCard(context, 'Top Artist', stats.topArtistName, stats.topArtistImage),
                                  _buildStatCard(context, 'Top Album', stats.topAlbumTitle, stats.topAlbumImage),
                                  _buildStatCard(context, 'Most Listened', stats.mostListenedTitle, stats.mostListenedImage),
                                  _buildStatCard(context, 'Recent Vibe', stats.recentVibeTitle, stats.recentVibeImage),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 12),
                            Center(
                              child: Text(
                                'TUNEWAVE',
                                style: TextStyle(
                                  color: isDark ? Colors.white38 : Colors.black38,
                                  fontSize: 11,
                                  letterSpacing: 5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 16), // More spacing above footer
                            
                            // Duration Footer
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
                              decoration: BoxDecoration(
                                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'LISTENING TIME',
                                    style: TextStyle(
                                      color: isDark ? Colors.white38 : Colors.black45, 
                                      fontSize: 11, 
                                      letterSpacing: 1.2,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  _LiveListeningTime(
                                    musicService: musicService,
                                    isDark: isDark,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  
                  // Share Button
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8E24AA), Color(0xFFD81B60)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD81B60).withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        )
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () => _shareImage(context),
                      icon: const Icon(Icons.ios_share, color: Colors.white, size: 20),
                      label: const Text(
                        'SHARE YOUR IDENTITY', 
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _shareImage(BuildContext context) async {
    try {
      final RenderRepaintBoundary? boundary =
          _globalKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      
      if (boundary == null) return;

      if (boundary.debugNeedsPaint) {
        // Wait for paint to complete if needed
        await Future.delayed(const Duration(milliseconds: 100));
        if (!context.mounted) return;
        return _shareImage(context);
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List pngBytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/music_dna.png').create();
      await file.writeAsBytes(pngBytes);

      if (!context.mounted) return;
      final XFile xFile = XFile(file.path);
      await Share.shareXFiles([xFile], text: 'Check out my Music DNA on TuneWave! 🧬🎵');
      
    } catch (e) {
      debugPrint('Sharing failed: $e');
      if (context.mounted) {
        showMusicToast(context, "Sharing failed: $e", type: ToastType.error);
      }
    }
  }

  Widget _buildStatCard(BuildContext context, String label, String value, String? imageUrl) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    Widget buildImage(String? url) {
      if (url != null && url.isNotEmpty) {
        return Image.network(
          url, 
          fit: BoxFit.cover, 
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) => Container(
            color: isDark ? Colors.grey[850] : Colors.grey[200],
            child: Icon(Icons.music_note, color: isDark ? Colors.white10 : Colors.black12),
          ),
        );
      }
      return Container(
        color: isDark ? Colors.grey[850] : Colors.grey[200], 
        child: Icon(Icons.music_note, color: isDark ? Colors.white10 : Colors.black12),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: (isDark ? 0.05 : 0.03)),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(), 
            style: TextStyle(
              color: isDark ? Colors.white38 : Colors.black38, 
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: buildImage(imageUrl),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black.withValues(alpha: 0.8), 
              fontWeight: FontWeight.w800, 
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  _DNAStats _calculateStats(MusicService musicService) {
    final playCounts = musicService.playCounts;
    final metadataCache = musicService.songMetadataCache;

    if (playCounts.isEmpty) {
      return _DNAStats(
        topArtistName: 'Explorer',
        topAlbumTitle: 'Beginnings',
        mostListenedTitle: 'Starting up',
        recentVibeTitle: 'Mystery',
      );
    }

    // Sort by play count
    final sortedSongIds = playCounts.keys.toList()
      ..sort((a, b) => playCounts[b]!.compareTo(playCounts[a]!));

    final mostListenedId = sortedSongIds.first;
    final mostListenedData = metadataCache[mostListenedId];

    // Top Artist
    final artistCounts = <String, int>{};
    for (var id in playCounts.keys) {
      final metadata = metadataCache[id];
      if (metadata != null) {
        final artist = metadata['artist'] ?? 'Unknown';
        artistCounts[artist] = (artistCounts[artist] ?? 0) + playCounts[id]!;
      }
    }
    final topArtist = artistCounts.isEmpty 
        ? 'Explorer' 
        : (artistCounts.keys.toList()..sort((a, b) => artistCounts[b]!.compareTo(artistCounts[a]!))).first;

    // Top Album
    final albumCounts = <String, int>{};
    final albumIdMap = <String, String>{}; // Map album name to ID
    for (var id in playCounts.keys) {
      final metadata = metadataCache[id];
      if (metadata != null) {
        final album = metadata['album'] ?? 'Unknown';
        albumCounts[album] = (albumCounts[album] ?? 0) + playCounts[id]!;
        if (metadata['albumId'] != null) {
          albumIdMap[album] = metadata['albumId'];
        }
      }
    }
    final topAlbum = albumCounts.isEmpty 
        ? 'Beginnings' 
        : (albumCounts.keys.toList()..sort((a, b) => albumCounts[b]!.compareTo(albumCounts[a]!))).first;
    final topAlbumId = albumIdMap[topAlbum];

    // Recent Vibe
    final history = musicService.listeningHistory;
    final recentData = history.isNotEmpty ? history.first : null;

    // Fetch actual artist image if not already fetched
    if (topArtist != 'Explorer' && topArtist != 'Unknown' && _fetchedArtistName != topArtist) {
      _fetchedArtistName = topArtist;
      _fetchedArtistImage = null; // Clear old image while fetching
      _fetchArtistImage(topArtist);
    }

    // Fetch actual album image if not already fetched
    if (topAlbumId != null && topAlbumId.isNotEmpty && _fetchedAlbumId != topAlbumId) {
      _fetchedAlbumId = topAlbumId;
      _fetchedAlbumImage = null; // Clear old image while fetching
      _fetchAlbumImage(topAlbumId);
    }

    return _DNAStats(
      topArtistName: topArtist,
      topArtistImage: _fetchedArtistImage ?? _findImageInCache(metadataCache, 'artist', topArtist),
      topAlbumTitle: topAlbum,
      topAlbumImage: _fetchedAlbumImage ?? _findImageInCache(metadataCache, 'album', topAlbum),
      mostListenedTitle: mostListenedData?['name'] ?? 'Unknown',
      mostListenedImage: mostListenedData?['imageUrl'],
      recentVibeTitle: recentData?.name ?? 'Unknown',
      recentVibeImage: recentData?.imageUrl,
    );
  }

  String? _findImageInCache(Map<String, Map<String, dynamic>> cache, String field, String value) {
    for (var metadata in cache.values) {
      if (metadata[field] == value) {
        return metadata['imageUrl'];
      }
    }
    return null;
  }
}

class _DNAStats {
  final String topArtistName;
  final String? topArtistImage;
  final String topAlbumTitle;
  final String? topAlbumImage;
  final String mostListenedTitle;
  final String? mostListenedImage;
  final String recentVibeTitle;
  final String? recentVibeImage;

  _DNAStats({
    required this.topArtistName,
    this.topArtistImage,
    required this.topAlbumTitle,
    this.topAlbumImage,
    required this.mostListenedTitle,
    this.mostListenedImage,
    required this.recentVibeTitle,
    this.recentVibeImage,
  });
}

class _LiveListeningTime extends StatefulWidget {
  final MusicService musicService;
  final bool isDark;

  const _LiveListeningTime({required this.musicService, required this.isDark});

  @override
  State<_LiveListeningTime> createState() => _LiveListeningTimeState();
}

class _LiveListeningTimeState extends State<_LiveListeningTime> {
  late Stream<int> _timer;

  @override
  void initState() {
    super.initState();
    _timer = Stream.periodic(const Duration(seconds: 1), (i) => i);
  }

  String _formatLiveDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else {
      return '${minutes}m ${seconds}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _timer,
      builder: (context, snapshot) {
        return Text(
          _formatLiveDuration(widget.musicService.totalListeningTime),
          style: TextStyle(
            color: widget.isDark ? Colors.white : Colors.black, 
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        );
      },
    );
  }
}
