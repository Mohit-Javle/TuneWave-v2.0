// lib/models/song.dart

class Song {
  final String id; // Add this line
  final String title;
  final String artist;
  final String assetPath;
  final String imageUrl;

  Song({
    required this.id, // Add this line
    required this.title,
    required this.artist,
    required this.assetPath,
    required this.imageUrl,
  });
}
