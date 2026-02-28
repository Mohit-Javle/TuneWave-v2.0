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
      // JioSaavn returns various low-res strings like 50x50, 150x150, etc.
      return url.replaceAll(RegExp(r'(?:150x150|50x50)'), '500x500'); 
    }

    return ArtistModel(
      id: json['id'] ?? '',
      name: json['title'] ?? json['name'] ?? 'Unknown Artist',
      imageUrl: getImageUrl(json['image']),
    );
  }
}
