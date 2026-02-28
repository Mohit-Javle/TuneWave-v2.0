
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/music_service.dart';
import '../services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ListeningHistoryScreen extends StatelessWidget {
  const ListeningHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Listening Activity"),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
      ),
      body: Consumer<MusicService>(
        builder: (context, musicService, child) {
          final email = AuthService.instance.currentUser?.email;

          if (email == null) {
            return _buildEmptyState(theme, "Please log in to see history");
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(email)
                .collection('listeningHistory')
                .orderBy('playedAt', descending: true)
                .limit(100)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6600)));
              }

              if (snapshot.hasError) {
                return _buildEmptyState(theme, "Error loading history");
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyState(theme, "No listening history yet");
              }

              final history = snapshot.data!.docs
                  .map((doc) => SongModel.fromJson(doc.data() as Map<String, dynamic>))
                  .toList();

              final groupedHistory = _groupHistoryByDate(history);

              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: groupedHistory.keys.length,
                itemBuilder: (context, index) {
                  final dateKey = groupedHistory.keys.elementAt(index);
                  final songs = groupedHistory[dateKey]!;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          dateKey,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      ...songs.map((song) => ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            song.imageUrl,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              width: 50,
                              height: 50,
                              color: Colors.grey[800],
                              child: const Icon(Icons.music_note, color: Colors.white54),
                            ),
                          ),
                        ),
                        title: Text(
                          song.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: musicService.isActive(song.id)
                                ? const Color(0xFFFF6600)
                                : theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                        trailing: const Icon(Icons.play_circle_outline, color: Color(0xFFFF6600)),
                        onTap: () {
                          musicService.loadPlaylist([song], 0);
                        },
                      )),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 80, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, List<SongModel>> _groupHistoryByDate(List<SongModel> history) {
    final Map<String, List<SongModel>> grouped = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (var song in history) {
      if (song.playedAt == null) continue; // Skip legacy data without timestamp

      // Convert from UTC if your Firestore saves in UTC, or just use as-is
      final date = song.playedAt!.toLocal(); 
      final dateOnly = DateTime(date.year, date.month, date.day);
      
      String header;
      if (dateOnly == today) {
        header = "Today";
      } else if (dateOnly == yesterday) {
        header = "Yesterday";
      } else {
        header = DateFormat('MMMM d, yyyy').format(date);
      }

      if (!grouped.containsKey(header)) {
        grouped[header] = [];
      }
      grouped[header]!.add(song);
    }
    return grouped;
  }
}
