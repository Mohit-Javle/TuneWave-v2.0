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

    return ArtistModel(
      id: json['id']?.toString() ?? '',
      name: json['title'] ?? json['name'] ?? 'Unknown Artist',
      imageUrl: getImageUrl(json['image']),
    );
  }

  factory ArtistModel.fromJson(Map<String, dynamic> json) {
    return ArtistModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      type: json['type'] ?? 'artist',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imageUrl': imageUrl,
      'type': type,
    };
  }
}
