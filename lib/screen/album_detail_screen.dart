
import 'package:clone_mp/models/album_model.dart';
import 'package:clone_mp/services/api_service.dart';
import 'package:clone_mp/services/music_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AlbumDetailScreen extends StatefulWidget {
  final AlbumModel album;

  const AlbumDetailScreen({super.key, required this.album});

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  List<SongModel> albumSongs = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlbumSongs();
  }

  Future<void> _loadAlbumSongs() async {
    try {
      final api = ApiService();
      final songs = await api.getAlbumDetails(widget.album.id);
      if (mounted) {
        setState(() {
          albumSongs = songs;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading album songs: $e");
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final musicService = Provider.of<MusicService>(context, listen: false);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300.0,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.album.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                       offset: Offset(0, 1),
                       blurRadius: 3.0,
                       color: Colors.black,
                    ),
                  ],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    widget.album.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                       color: Colors.grey[900], 
                       child: const Center(child: Icon(Icons.album, size: 80, color: Colors.white54)),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                        stops: [0.6, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
             backgroundColor: theme.colorScheme.surface,
             leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
             ),
          ),
          if (isLoading)
             const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: Color(0xFFFF6600))),
             )
          else if (albumSongs.isEmpty)
             const SliverFillRemaining(
                child: Center(child: Text("No songs found in this album.")),
             )
          else
             SliverList(
                delegate: SliverChildBuilderDelegate(
                   (context, index) {
                      final song = albumSongs[index];
                      return ListTile(
                         leading: Text(
                            "${index + 1}", 
                            style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                         ),
                         title: Text(song.name, style: TextStyle(color: theme.colorScheme.onSurface)),
                         subtitle: Text(
                            song.artist, 
                            style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                            maxLines: 1,
                         ),
                         trailing: const Icon(Icons.play_circle_outline, color: Color(0xFFFF6600)),
                         onTap: () {
                            // Play entire album starting from this song
                            musicService.loadPlaylist(albumSongs, index);
                         },
                      );
                   },
                   childCount: albumSongs.length,
                ),
             ),
             const SliverToBoxAdapter(
              child: SizedBox(height: 100), // Bottom padding for miniplayer
            ),
        ],
      ),
    );
  }
}
