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
    String getImageUrl(String? url) {
      if (url == null || url.isEmpty) return '';
      return url.replaceAll(RegExp(r'(?:150x150|50x50)'), '500x500'); 
    }

    return AlbumModel(
      id: json['id'] ?? '',
      name: json['title']?.toString().replaceAll('&quot;', '"') ?? 'Unknown Album',
      artist: json['more_info']?['music'] ?? json['subtitle'] ?? 'Unknown Artist',
      imageUrl: getImageUrl(json['image']),
      year: json['year'] ?? json['more_info']?['year'] ?? '',
    );
  }
}
