import 'package:clone_mp/route_names.dart';
import 'package:flutter/material.dart';
import '../models/song_model.dart';

class SongInfoDialog {
  static void show(BuildContext context, SongModel song) {
    final theme = Theme.of(context);
    const primaryOrange = Color(0xFFFF6600);
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Image
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                child: Stack(
                  children: [
                    Image.network(
                      song.imageUrl,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 180,
                        color: Colors.grey[900],
                        child: const Icon(Icons.music_note, size: 60, color: Colors.white54),
                      ),
                    ),
                    Container(
                      height: 180,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            theme.colorScheme.surface.withValues(alpha: 0.8),
                            theme.colorScheme.surface,
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 20,
                      right: 20,
                      child: Text(
                        "About This Song",
                        style: TextStyle(
                          color: primaryOrange,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Details
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _buildInfoRow(Icons.music_note_rounded, "Title", song.name, theme),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      Icons.person_rounded, 
                      "Artist", 
                      song.artist, 
                      theme,
                      onTap: song.artistId != null && song.artistId!.isNotEmpty
                        ? () {
                            Navigator.pop(context); // Close dialog first
                            Navigator.pushNamed(
                              context, 
                              AppRoutes.artist, 
                              arguments: {
                                'id': song.artistId!,
                                'name': song.artist,
                                'image': '', // Don't pass song image for artist profile
                              },
                            );
                          }
                        : null,
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(Icons.album_rounded, "Album", song.album, theme),
                    if (song.duration != null && song.duration!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildInfoRow(Icons.access_time_filled_rounded, "Duration", _formatDuration(song.duration!), theme),
                    ],
                  ],
                ),
              ),

              // Close Button
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      "Close",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildInfoRow(IconData icon, String label, String value, ThemeData theme, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6600).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFFFF6600), size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          value,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (onTap != null)
                        const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFFFF6600)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDuration(String durationStr) {
    final seconds = int.tryParse(durationStr) ?? 0;
    if (seconds == 0) return "Unknown";
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return "$m:${s.toString().padLeft(2, '0')}";
  }
}
