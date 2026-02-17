// ignore_for_file: deprecated_member_use

import 'package:clone_mp/services/music_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class QueueScreen extends StatelessWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final musicService = context.watch<MusicService>();
    final theme = Theme.of(context);
    final queue = musicService.currentQueue;
    final currentIndex = musicService.currentQueueIndex;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Queue'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          if (queue.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: () {
                _showClearQueueDialog(context, musicService);
              },
              tooltip: 'Clear Queue',
            ),
        ],
      ),
      body: queue.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.queue_music,
                    size: 80,
                    color: theme.colorScheme.onSurface.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Queue is empty',
                    style: TextStyle(
                      fontSize: 18,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add songs to start listening',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.only(bottom: 100),
              itemCount: queue.length,
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) {
                  newIndex -= 1;
                }
                musicService.reorderQueue(oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final song = queue[index];
                final isCurrentSong = index == currentIndex;

                return Dismissible(
                  key: ValueKey(song.id + index.toString()),
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (direction) async {
                    if (isCurrentSong) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Cannot remove currently playing song'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return false;
                    }
                    return true;
                  },
                  onDismissed: (direction) {
                    musicService.removeFromQueue(index);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${song.name} removed from queue'),
                        action: SnackBarAction(
                          label: 'Undo',
                          onPressed: () {
                            // Re-add at same position
                            musicService.reorderQueue(
                              queue.length - 1,
                              index,
                            );
                          },
                        ),
                      ),
                    );
                  },
                  child: Container(
                    color: isCurrentSong
                        ? const Color(0xFFFF6600).withOpacity(0.1)
                        : Colors.transparent,
                    child: ListTile(
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.drag_handle,
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                          const SizedBox(width: 8),
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.network(
                                  song.imageUrl,
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 50,
                                    height: 50,
                                    color: Colors.grey,
                                    child: const Icon(Icons.music_note),
                                  ),
                                ),
                              ),
                              if (isCurrentSong)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(
                                      Icons.play_arrow,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      title: Text(
                        song.name,
                        style: TextStyle(
                          color: isCurrentSong
                              ? const Color(0xFFFF6600)
                              : theme.colorScheme.onSurface,
                          fontWeight:
                              isCurrentSong ? FontWeight.bold : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        song.artist,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: isCurrentSong
                          ? const Icon(
                              Icons.equalizer,
                              color: Color(0xFFFF6600),
                            )
                          : null,
                      onTap: () {
                        musicService.skipToQueueItem(index);
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showClearQueueDialog(BuildContext context, MusicService musicService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Queue?'),
        content: const Text(
          'This will remove all songs from the queue and stop playback.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              musicService.clearQueue();
              Navigator.pop(context);
              Navigator.pop(context); // Close queue screen too
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
