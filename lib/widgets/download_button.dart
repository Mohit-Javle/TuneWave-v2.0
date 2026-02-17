// widgets/download_button.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song_model.dart';
import '../services/download_service.dart';

class DownloadButton extends StatelessWidget {
  final SongModel song;
  final double size;
  final Color? color;

  const DownloadButton({
    super.key,
    required this.song,
    this.size = 24.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadService>(
      builder: (context, downloadService, child) {
        final isDownloaded = downloadService.isSongDownloaded(song.id);
        final isDownloading = downloadService.isDownloading(song.id);
        final downloadProgress = downloadService.getDownloadProgress(song.id);

        if (isDownloading) {
          // Show progress indicator while downloading
          return SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: downloadProgress,
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    color ?? Theme.of(context).primaryColor,
                  ),
                ),
                InkWell(
                  onTap: () {
                    downloadService.cancelDownload(song.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Download canceled'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Icon(
                    Icons.close,
                    size: size * 0.6,
                    color: color ?? Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
          );
        }

        if (isDownloaded) {
          // Show downloaded icon with delete option
          return PopupMenuButton<String>(
            icon: Icon(
              Icons.download_done,
              size: size,
              color: color ?? Colors.green,
            ),
            onSelected: (value) async {
              if (value == 'delete') {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Download'),
                    content: Text(
                      'Are you sure you want to delete "${song.name}"?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  final success = await downloadService.deleteSong(song.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Download deleted'
                              : 'Failed to delete download',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete Download'),
                  ],
                ),
              ),
            ],
          );
        }

        // Show download button
        return IconButton(
          icon: Icon(
            Icons.download,
            size: size,
            color: color,
          ),
          onPressed: () async {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Downloading "${song.name}"...'),
                duration: const Duration(seconds: 2),
              ),
            );

            final downloadedSong = await downloadService.downloadSong(song);
            
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    downloadedSong != null
                        ? 'Download complete!'
                        : 'Download failed',
                  ),
                  backgroundColor: downloadedSong != null ? Colors.green : Colors.red,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
        );
      },
    );
  }
}
