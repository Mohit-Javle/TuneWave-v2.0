// screens/liked_songs_screen.dart
// ignore_for_file: deprecated_member_use


import 'package:clone_mp/services/music_service.dart';
import 'package:clone_mp/services/playlist_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:clone_mp/widgets/falling_item.dart';

class LikedSongsScreen extends StatelessWidget {
  const LikedSongsScreen({super.key});

  static const Color primaryOrange = Color(0xFFFF6600);
  static const Color veryLightOrange = Color(0xFFFF9D5C);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textDark = theme.colorScheme.onSurface;
    final textLight = theme.colorScheme.onSurface.withOpacity(0.7);

    final playlistService = context.watch<PlaylistService>();
    final likedSongs = playlistService.likedSongs;
    final musicService = context.read<MusicService>();

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: theme.brightness == Brightness.light
                ? [Colors.white, const Color.fromARGB(100, 255, 218, 192)]
                : [theme.colorScheme.surface, theme.colorScheme.background],
            stops: const [0.3, 0.7],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: theme.colorScheme.surface.withOpacity(0.8),
              elevation: 0,
              pinned: true,
              title: Text(
                'Liked Songs',
                style: TextStyle(color: textDark, fontWeight: FontWeight.bold),
              ),
              iconTheme: IconThemeData(color: textDark),
              actions: [
                IconButton(
                  icon: const Icon(Icons.shuffle, color: primaryOrange),
                  onPressed: likedSongs.isEmpty
                      ? null
                      : () {
                          final shuffledList = List<SongModel>.from(likedSongs)
                            ..shuffle();
                          musicService.loadPlaylist(shuffledList, 0);
                        },
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: IconButton(
                    icon: const Icon(
                      Icons.play_circle_fill,
                      color: primaryOrange,
                      size: 30,
                    ),
                    onPressed: likedSongs.isEmpty
                        ? null
                        : () {
                            musicService.loadPlaylist(likedSongs, 0);
                          },
                  ),
                ),
              ],
            ),
            if (likedSongs.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.favorite_border, size: 80, color: textLight),
                      const SizedBox(height: 20),
                      Text(
                        'Songs you like will appear here',
                        style: TextStyle(color: textLight, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final song = likedSongs[index];
                  final tileKey = GlobalKey();
                  Offset? capturedPosition;
                  Size? capturedSize;
                  return Dismissible(
                    key: Key(song.id),
                    direction: DismissDirection.horizontal,
                    confirmDismiss: (direction) async {
                      if (direction == DismissDirection.startToEnd) {
                        // Swipe right - Add to queue
                        musicService.addToQueue(song);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${song.name} added to queue'),
                            backgroundColor: primaryOrange,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                        return false; // Don't dismiss
                      } else if (direction == DismissDirection.endToStart) {
                        // Capture position while the widget is still in the tree for falling animation
                        final box = tileKey.currentContext?.findRenderObject() as RenderBox?;
                        if (box != null) {
                          capturedPosition = box.localToGlobal(Offset.zero);
                          capturedSize = box.size;
                        }
                        return true; // Allow dismiss for left swipe
                      }
                      return false;
                    },
                    onDismissed: (direction) {
                      if (direction == DismissDirection.endToStart) {
                        final bool isActive = musicService.isActive(song.id);
                        // Trigger falling animation using the captured position
                        triggerFallingItem(
                          context, 
                          _buildSongTile(song, textDark, textLight, likedSongs, musicService, playlistService, index, theme, isActive: isActive, isStatic: true),
                          backgroundColor: theme.colorScheme.surface,
                          manualPosition: capturedPosition,
                          manualSize: capturedSize,
                        );
                        
                        // Swipe left - Remove from liked
                        playlistService.toggleLike(song);
                      }
                    },
                    background: Container(
                      color: primaryOrange,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const Row(
                        children: [
                          Icon(Icons.queue_music, color: Colors.white, size: 30),
                          SizedBox(width: 8),
                          Text(
                            'Add to Queue',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    secondaryBackground: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'Remove',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.delete, color: Colors.white, size: 30),
                        ],
                      ),
                    ),
                    child: Container(
                      key: tileKey,
                      child: Consumer<MusicService>(
                        builder: (context, mService, _) => _buildSongTile(
                          song, textDark, textLight, likedSongs, mService, playlistService, index, theme, 
                          isActive: mService.isActive(song.id)
                        ),
                      ),
                    ),
                  );
                }, childCount: likedSongs.length),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSongTile(
    SongModel song, 
    Color textDark, 
    Color textLight, 
    List<SongModel> likedSongs,
    MusicService musicService,
    PlaylistService playlistService,
    int index,
    ThemeData theme,
    {bool isActive = false, bool isStatic = false}
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 8,
      ),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          song.imageUrl,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => Container(
            width: 50,
            height: 50,
            color: veryLightOrange.withOpacity(0.5),
            child: Icon(Icons.music_note, color: textDark),
          ),
        ),
      ),
      title: Text(
        song.name,
        style: TextStyle(
          color: isActive ? primaryOrange : textDark,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        song.artist,
        style: TextStyle(color: textLight),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.favorite, color: primaryOrange),
        onPressed: isStatic ? null : () {
          playlistService.toggleLike(song);
        },
      ),
      onTap: isStatic ? null : () {
        musicService.loadPlaylist(likedSongs, index);
      },
    );
  }
}
