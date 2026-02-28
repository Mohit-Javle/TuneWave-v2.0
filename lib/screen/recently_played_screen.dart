

import 'package:clone_mp/services/music_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:clone_mp/route_names.dart';


class RecentlyPlayedScreen extends StatelessWidget {
  const RecentlyPlayedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final musicService = context.watch<MusicService>();
    final recentlyPlayed = musicService.listeningHistory;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recently Played'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        titleTextStyle: TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: recentlyPlayed.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 80,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No recently played songs',
                    style: TextStyle(
                      fontSize: 18,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 100),
              itemCount: recentlyPlayed.length,
              itemBuilder: (context, index) {
                final song = recentlyPlayed[index];
                // We don't track exact "time ago" in SongModel's history list easily 
                // unless we change how we store it, but for now we list them in order.
                // SongModel has playedAt field if we set it when adding to history.
                
                String timeAgo = '';
                if (song.playedAt != null) {
                  timeAgo = _getTimeAgo(song.playedAt!);
                }

                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      song.imageUrl,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 50,
                        height: 50,
                        color: Colors.grey,
                        child: const Icon(Icons.music_note),
                      ),
                    ),
                  ),
                  title: Text(
                    song.name,
                    style: TextStyle(
                      color: musicService.isActive(song.id)
                          ? const Color(0xFFFF6600)
                          : theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.artist,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (timeAgo.isNotEmpty)
                        Text(
                          timeAgo,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.play_circle_filled, color: Color(0xFFFF6600)),
                    onPressed: () {
                       // Play this song
                       // We need to pass the list context if we want queue behavior, 
                       // or just play this one song. 
                       // Let's play the history list starting from this song.
                       musicService.loadPlaylist(recentlyPlayed, index);
                    },
                  ),
                  onTap: () {
                     musicService.loadPlaylist(recentlyPlayed, index);
                     Navigator.pushNamed(context, AppRoutes.main); // Go to player/home
                  },
                );
              },
            ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return '${(difference.inDays / 7).floor()} weeks ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }
}
