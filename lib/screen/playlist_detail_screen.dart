// screen/playlist_detail_screen.dart
// ignore_for_file: deprecated_member_use


import 'package:clone_mp/services/music_service.dart';
import 'package:clone_mp/services/playlist_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:clone_mp/screen/add_songs_screen.dart';
import 'package:clone_mp/services/download_service.dart';
import 'package:clone_mp/services/ui_state_service.dart';
import 'package:clone_mp/widgets/falling_item.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final Playlist playlist;
  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  // Method to show rename dialog
  void _showRenamePlaylistDialog() {
    final playlistService = Provider.of<PlaylistService>(
      context,
      listen: false,
    );
    final TextEditingController nameController = TextEditingController(
      text: widget.playlist.name,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Rename Playlist"),
        content: TextField(controller: nameController, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                playlistService.renamePlaylist(
                  widget.playlist.id,
                  nameController.text,
                );
                Navigator.pop(context);
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // Method to show options for a song
  void _showSongOptions(SongModel song) {
    final playlistService = Provider.of<PlaylistService>(context, listen: false);
    final downloadService = Provider.of<DownloadService>(context, listen: false);
    final uiStateService = Provider.of<UiStateService>(context, listen: false);
    final musicService = Provider.of<MusicService>(context, listen: false);
    final isDownloaded = downloadService.isSongDownloaded(song.id);
    
    // Hide mini player when modal opens to prevent overlap
    uiStateService.setModalActive(true);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Play Next Option
              ListTile(
                leading: const Icon(
                  Icons.queue_play_next_rounded,
                  color: Color(0xFFFF6600),
                ),
                title: const Text('Play Next'),
                onTap: () {
                  musicService.addToPlayNext(song);
                  Navigator.pop(context);
                },
              ),

              // Download Option
              ListTile(
                leading: Icon(
                  isDownloaded ? Icons.delete_outline : Icons.download_outlined,
                  color: isDownloaded ? Colors.red : const Color(0xFFFF6600),
                ),
                title: Text(isDownloaded ? 'Delete Download' : 'Download'),
                onTap: () async {
                  Navigator.pop(context); // Close sheet first
                  if (isDownloaded) {
                    // Delete logic
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Download'),
                        content: Text('Are you sure you want to delete "${song.name}"?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Delete', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await downloadService.deleteSong(song.id);
                    }
                  } else {
                    // Download logic
                    await downloadService.downloadSong(song);
                  }
                },
              ),
              
              // Remove from Playlist Option
              ListTile(
                leading: const Icon(
                  Icons.remove_circle_outline,
                  color: Colors.grey,
                ),
                title: const Text('Remove from playlist'),
                onTap: () {
                  playlistService.removeSongFromPlaylist(
                    widget.playlist.id,
                    song.id,
                  );
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    ).then((_) {
      // Show mini player back when modal is dismissed
      uiStateService.setModalActive(false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final musicService = context.watch<MusicService>();

    return Consumer<PlaylistService>(
      builder: (context, playlistService, child) {
        // This logic correctly finds the latest version of the playlist
        final currentPlaylist = playlistService.playlists.firstWhere(
          (p) => p.id == widget.playlist.id,
          // Fallback in case the playlist was just deleted.
          orElse: () => widget.playlist,
        );

        final List<SongModel> playlistSongs = currentPlaylist.songs;

        return Scaffold(
          extendBodyBehindAppBar: true,
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: theme.brightness == Brightness.light
                    ? [Colors.white, const Color.fromARGB(100, 255, 218, 192)]
                    : [theme.colorScheme.surface, const Color(0xFF121212)],
                stops: const [0.3, 0.7],
              ),
            ),
            child: CustomScrollView(
              slivers: [
                _buildSliverAppBar(
                  context,
                  theme,
                  currentPlaylist.name,
                  playlistSongs,
                ),
                _buildActionButtons(
                  context,
                  musicService,
                  playlistSongs,
                  currentPlaylist,
                ),
                if (playlistSongs.isEmpty)
                  _buildEmptyState(theme)
                else
                  _buildSongList(currentPlaylist, playlistSongs, musicService),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 150), // Standard bottom padding for miniplayer
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  SliverAppBar _buildSliverAppBar(
    BuildContext context,
    ThemeData theme,
    String playlistName,
    List<SongModel> songs,
  ) {
    final textDark = theme.colorScheme.onSurface;

    return SliverAppBar(
      backgroundColor: theme.colorScheme.surface.withOpacity(0.8),
      elevation: 0,
      pinned: true,
      centerTitle: false,
      title: Text(
        playlistName,
        style: TextStyle(
          color: textDark,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      iconTheme: IconThemeData(color: textDark),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_outlined, color: Color(0xFFFF6600)),
          onPressed: _showRenamePlaylistDialog,
          tooltip: 'Rename Playlist',
        ),
      ],
    );
  }


  SliverToBoxAdapter _buildActionButtons(
    BuildContext context,
    MusicService musicService,
    List<SongModel> playlistSongs,
    Playlist currentPlaylist, // Pass the current playlist object
  ) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.playlist_add, size: 28),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    // Pass the most up-to-date playlist object
                    builder: (context) =>
                        AddSongsScreen(playlist: currentPlaylist),
                  ),
                );
              },
              tooltip: 'Add Songs',
            ),
            ElevatedButton.icon(
              onPressed: playlistSongs.isEmpty
                  ? null
                  : () {
                      musicService.loadPlaylist(playlistSongs, 0);
                      musicService.logPlayContext(currentPlaylist.id, 'playlist', currentPlaylist.name, playlistSongs.isNotEmpty ? playlistSongs.first.imageUrl : '', playlistSongs);
                    },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Play'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6600),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.shuffle, size: 28),
              onPressed: playlistSongs.isEmpty
                  ? null
                  : () {
                      final shuffledList = List<SongModel>.from(playlistSongs)
                        ..shuffle();
                      musicService.loadPlaylist(shuffledList, 0);
                      musicService.logPlayContext(currentPlaylist.id, 'playlist', currentPlaylist.name, playlistSongs.isNotEmpty ? playlistSongs.first.imageUrl : '', playlistSongs);
                    },
              tooltip: 'Shuffle',
            ),
          ],
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildEmptyState(ThemeData theme) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.playlist_add, size: 60, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                "This playlist is empty",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Tap the '+' icon above to add songs.",
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  SliverList _buildSongList(
    Playlist currentPlaylist,
    List<SongModel> playlistSongs,
    MusicService musicService,
  ) {
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final song = playlistSongs[index];
        final tileKey = GlobalKey();
        Offset? capturedPosition;
        Size? capturedSize;
        return Dismissible(
          key: Key('playlist_${widget.playlist.id}_${song.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (direction) async {
            // Capture position while still in tree
            final box = tileKey.currentContext?.findRenderObject() as RenderBox?;
            if (box != null) {
              capturedPosition = box.localToGlobal(Offset.zero);
              capturedSize = box.size;
            }
            return true;
          },
          onDismissed: (direction) {
            final playlistService = Provider.of<PlaylistService>(context, listen: false);
            triggerFallingItem(
              context, 
              _buildSongTile(song, musicService, playlistSongs, currentPlaylist, index, isStatic: true, isActive: musicService.isActive(song.id)),
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              manualPosition: capturedPosition,
              manualSize: capturedSize,
            );
            
            // Remove from playlist
            playlistService.removeSongFromPlaylist(widget.playlist.id, song.id);
          },
          child: Container(
            key: tileKey,
            child: _buildSongTile(song, musicService, playlistSongs, currentPlaylist, index, isActive: musicService.isActive(song.id)),
          ),
        );
      }, childCount: playlistSongs.length),
    );
  }

  Widget _buildSongTile(SongModel song, MusicService musicService, List<SongModel> playlistSongs, Playlist? currentPlaylist, int index, {bool isStatic = false, bool isActive = false}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 4,
      ),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(
          song.imageUrl,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
        ),
      ),
      title: Text(
        song.name,
        style: TextStyle(
          color: isActive ? const Color(0xFFFF6600) : null,
          fontWeight: isActive ? FontWeight.bold : null,
        ),
      ),
      subtitle: Text(song.artist),
      trailing: IconButton(
        icon: const Icon(Icons.more_vert),
        onPressed: isStatic ? null : () => _showSongOptions(song),
      ),
      onTap: isStatic ? null : () {
        musicService.loadPlaylist(playlistSongs, index);
        if (currentPlaylist != null) {
          musicService.logPlayContext(currentPlaylist.id, 'playlist', currentPlaylist.name, playlistSongs.isNotEmpty ? playlistSongs.first.imageUrl : '', playlistSongs);
        }
      },
    );
  }
}
