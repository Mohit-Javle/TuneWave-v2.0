class SongModel {
  final String id;
  final String name;
  final String artist;
  final String album;
  final String imageUrl;
  final String downloadUrl;
  final bool hasLyrics;
  final DateTime? playedAt; // Added for history tracking
  final bool isDownloaded; // Track if song is downloaded
  final String? localFilePath; // Local file path for offline playback
  final DateTime? downloadedAt; // When the song was downloaded

  SongModel({
    required this.id,
    required this.name,
    required this.artist,
    required this.album,
    required this.imageUrl,
    required this.downloadUrl,
    required this.hasLyrics,
    this.playedAt,
    this.isDownloaded = false,
    this.localFilePath,
    this.downloadedAt,
  });

  // Updated to handle Official JioSaavn API response
  factory SongModel.fromOfficialJson(Map<String, dynamic> json, {String decryptedUrl = ''}) {
    // Helper to get high quality image
    String getImageUrl(String? url) {
      if (url == null || url.isEmpty) return '';
      return url.replaceAll('150x150', '500x500');
    }

    // Helper to get artist names
    String getArtists(Map<String, dynamic>? moreInfo) {
      if (moreInfo == null) return 'Unknown Artist';
      final artistMap = moreInfo['artistMap'];
      if (artistMap != null && artistMap['primary_artists'] != null) {
        final artists = artistMap['primary_artists'] as List;
        if (artists.isNotEmpty) {
          return artists.map((a) => a['name']).join(', ');
        }
      }
      return json['subtitle'] ?? 'Unknown Artist';
    }

    final moreInfo = json['more_info'] is Map ? json['more_info'] : {};

    return SongModel(
      id: json['id'] ?? '',
      name: json['title']?.toString().replaceAll('&quot;', '"').replaceAll('&amp;', '&') ?? 'Unknown',
      artist: getArtists(moreInfo),
      album: moreInfo['album']?.toString().replaceAll('&quot;', '"').replaceAll('&amp;', '&') ?? '',
      imageUrl: getImageUrl(json['image']),
      downloadUrl: decryptedUrl,
      hasLyrics: moreInfo['has_lyrics'] == 'true',
    );
  }

  // Keep this for now if needed, but the official API is preferred
  factory SongModel.fromJson(Map<String, dynamic> json) {
    // Check if this is our local format (has 'isLocal') or external API format
    if (json.containsKey('isLocal')) {
      return SongModel(
        id: json['id'],
        name: json['name'],
        artist: json['artist'],
        album: json['album'],
        imageUrl: json['imageUrl'],
        downloadUrl: json['downloadUrl'],
        hasLyrics: json['hasLyrics'],
        playedAt: json['playedAt'] != null ? DateTime.parse(json['playedAt']) : null,
        isDownloaded: json['isDownloaded'] ?? false,
        localFilePath: json['localFilePath'],
        downloadedAt: json['downloadedAt'] != null ? DateTime.parse(json['downloadedAt']) : null,
      );
    }
    return SongModel.fromOfficialJson(json);
  }

  Map<String, dynamic> toJson() {
    return {
      'isLocal': true,
      'id': id,
      'name': name,
      'artist': artist,
      'album': album,
      'imageUrl': imageUrl,
      'downloadUrl': downloadUrl,
      'hasLyrics': hasLyrics,
      'playedAt': playedAt?.toIso8601String(),
      'isDownloaded': isDownloaded,
      'localFilePath': localFilePath,
      'downloadedAt': downloadedAt?.toIso8601String(),
    };
  }
}
