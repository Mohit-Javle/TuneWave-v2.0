class AlbumModel {
  final String id;
  final String name;
  final String artist;
  final String imageUrl;
  final String year;

  AlbumModel({
    required this.id,
    required this.name,
    required this.artist,
    required this.imageUrl,
    required this.year,
  });

  factory AlbumModel.fromOfficialJson(Map<String, dynamic> json) {
    String getImageUrl(dynamic image) {
      if (image == null) return '';
      if (image is List && image.isNotEmpty) {
        return image.last['link']?.toString() ?? '';
      }
      if (image is String) {
        if (image.isEmpty) return '';
        return image.replaceAll(RegExp(r'(?:150x150|50x50)'), '500x500'); 
      }
      return '';
    }

    final moreInfo = json['more_info'] is Map ? json['more_info'] : {};

    return AlbumModel(
      id: json['id']?.toString() ?? '',
      name: (json['name'] ?? json['title'])?.toString().replaceAll('&quot;', '"') ?? 'Unknown Album',
      artist: (moreInfo['music'] ?? json['subtitle'] ?? json['artist']?['name'] ?? json['artist'])?.toString() ?? 'Unknown Artist',
      imageUrl: getImageUrl(json['image']),
      year: (json['year'] ?? moreInfo['year'])?.toString() ?? '',
    );
  }

  factory AlbumModel.fromJson(Map<String, dynamic> json) {
    return AlbumModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      artist: json['artist'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      year: json['year'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'artist': artist,
      'imageUrl': imageUrl,
      'year': year,
    };
  }
}
