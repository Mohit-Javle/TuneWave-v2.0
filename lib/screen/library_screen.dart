// screen/library_screen.dart
// ignore_for_file: deprecated_member_use, unused_element

import 'package:clone_mp/screen/playlist_detail_screen.dart';
import 'package:clone_mp/services/playlist_service.dart';
import 'package:clone_mp/services/download_service.dart';
import 'package:clone_mp/widgets/create_playlist_sheet.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  bool _isGridView = true;

  static const Color primaryOrange = Color(0xFFFF6600);
  static const Color veryLightOrange = Color(0xFFFF9D5C);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playlistService = context.watch<PlaylistService>();

    return Scaffold(
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
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                Expanded(child: _buildPlaylistContent(playlistService)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    final textDark = theme.colorScheme.onSurface;
    final iconColor = theme.unselectedWidgetColor;

    return Row(
      children: [
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            "Your Library",
            style: TextStyle(
              color: textDark,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        IconButton(
          icon: Icon(
            _isGridView ? Icons.view_list : Icons.view_module,
            color: iconColor,
          ),
          onPressed: () {
            setState(() {
              _isGridView = !_isGridView;
            });
          },
        ),
        IconButton(
          icon: Icon(Icons.add, color: iconColor),
          onPressed: () => CreatePlaylistSheet.show(context),
        ),
      ],
    );
  }

  // Helper because we are mixing Playlist objects and "Liked Songs" concept
  Widget _buildPlaylistContent(PlaylistService playlistService) {
    final userPlaylists = playlistService.playlists;

    // Items: 0=Liked, 1=Recently Played, 2=Downloads, 3+=Playlists
    final int totalItems = 3 + userPlaylists.length;

    if (_isGridView) {
      return CustomScrollView(
        slivers: [
          SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.7,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              if (index == 0) {
                return _buildLikedSongsCard();
              }
              if (index == 1) {
                return _buildRecentlyPlayedCard();
              }
              if (index == 2) {
                return _buildDownloadsCard();
              }
              final playlist = userPlaylists[index - 3];
              return _buildPlaylistCard(playlist);
            }, childCount: totalItems),
          ),
        ],
      );
    } else {
      return ListView.builder(
        itemCount: totalItems,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildLikedSongsTile();
          }
          if (index == 1) {
            return _buildRecentlyPlayedTile();
          }
           if (index == 2) {
            return _buildDownloadsTile();
          }
          final playlist = userPlaylists[index - 3];
          return _buildPlaylistTile(playlist);
        },
      );
    }
  }

  Widget _buildLikedSongsCard() {
    final theme = Theme.of(context);
    final playlistService = context.watch<PlaylistService>();
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/liked_songs'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.0,
            child: Card(
              elevation: 4,
              shadowColor: Colors.black.withOpacity(0.2),
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.deepPurple, Colors.blueAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.favorite, color: Colors.white, size: 60),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Liked Songs',
            style: TextStyle(fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${playlistService.likedSongs.length} songs',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLikedSongsTile() {
    final playlistService = context.watch<PlaylistService>();
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple, Colors.blueAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(Icons.favorite, color: Colors.white),
        ),
      ),
      title: const Text(
        'Liked Songs',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text('${playlistService.likedSongs.length} songs'),
      onTap: () => Navigator.pushNamed(context, '/liked_songs'),
    );
  }

  Widget _buildRecentlyPlayedCard() {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/recently_played'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.0,
            child: Card(
              elevation: 4,
              shadowColor: Colors.black.withOpacity(0.2),
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF6600), Color(0xFFFF9D5C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.history, color: Colors.white, size: 60),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Recently Played',
            style: TextStyle(fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            'Your history',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentlyPlayedTile() {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF6600), Color(0xFFFF9D5C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(Icons.history, color: Colors.white),
        ),
      ),
      title: const Text(
        'Recently Played',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: const Text('Your history'),
      onTap: () => Navigator.pushNamed(context, '/recently_played'),
    );
  }

  Widget _buildDownloadsCard() {
    final theme = Theme.of(context);
    final downloadService = context.watch<DownloadService>();
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/downloads'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.0,
            child: Card(
              elevation: 4,
              shadowColor: Colors.black.withOpacity(0.2),
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green, Colors.teal],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.download_rounded, color: Colors.white, size: 60),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Downloads',
            style: TextStyle(fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${downloadService.downloadedSongs.length} songs',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadsTile() {
    final downloadService = context.watch<DownloadService>();
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green, Colors.teal],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(Icons.download_rounded, color: Colors.white),
        ),
      ),
      title: const Text(
        'Downloads',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text('${downloadService.downloadedSongs.length} songs'),
      onTap: () => Navigator.pushNamed(context, '/downloads'),
    );
  }

  Widget _buildPlaylistCard(Playlist playlist) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlaylistDetailScreen(playlist: playlist),
          ),
        );
      },
      onLongPress: () => _showPlaylistOptions(playlist),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.0,
            child: Card(
              elevation: 4,
              shadowColor: Colors.black.withOpacity(0.2),
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: _buildPlaylistArt(playlist, isGrid: true),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            playlist.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${playlist.songs.length} songs',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistTile(Playlist playlist) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 56,
          height: 56,
          child: _buildPlaylistArt(playlist, isGrid: false),
        ),
      ),
      title: Text(
        playlist.name,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text('${playlist.songs.length} songs'),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlaylistDetailScreen(playlist: playlist),
          ),
        );
      },
      trailing: IconButton(
        icon: Icon(Icons.more_vert, color: theme.unselectedWidgetColor),
        onPressed: () => _showPlaylistOptions(playlist),
      ),
    );
  }

  Widget _buildPlaylistArt(Playlist playlist, {required bool isGrid}) {
    final songs = playlist.songs;

    if (songs.isEmpty) {
      return Container(
        color: veryLightOrange.withOpacity(0.5),
        child: Icon(
          Icons.music_note,
          size: isGrid ? 50 : 30,
          color: primaryOrange,
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
      ),
      itemCount: songs.length > 4 ? 4 : songs.length,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        return Image.network(
          songs[index].imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: veryLightOrange.withOpacity(0.5),
            child: const Center(
              child: Icon(Icons.error_outline, color: Colors.grey),
            ),
          ),
        );
      },
    );
  }



  void _showPlaylistOptions(Playlist playlist) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      builder: (context) {
        return Wrap(
          children: <Widget>[
            ListTile(
              leading: Icon(Icons.delete_outline, color: Colors.red[400]),
              title: Text(
                'Delete Playlist',
                style: TextStyle(color: Colors.red[400]),
              ),
              onTap: () {
                Navigator.pop(context);
                _confirmDeletePlaylist(playlist);
              },
            ),
          ],
        );
      },
    );
  }

  void _confirmDeletePlaylist(Playlist playlist) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Playlist'),
          content: Text('Are you sure you want to delete "${playlist.name}"?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Delete', style: TextStyle(color: Colors.red[400])),
              onPressed: () {
                Provider.of<PlaylistService>(
                  context,
                  listen: false,
                ).deletePlaylist(playlist.id);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
