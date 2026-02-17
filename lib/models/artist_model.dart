class ArtistModel {
  final String id;
  final String name;
  final String imageUrl;
  final String type; // 'artist'

  ArtistModel({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.type = 'artist',
  });

  factory ArtistModel.fromOfficialJson(Map<String, dynamic> json) {
     String getImageUrl(String? url) {
      if (url == null || url.isEmpty) return '';
      return url.replaceAll('150x150', '500x500'); // Better quality
    }

    return ArtistModel(
      id: json['id'] ?? '',
      name: json['title'] ?? json['name'] ?? 'Unknown Artist',
      imageUrl: getImageUrl(json['image']),
    );
  }
}
