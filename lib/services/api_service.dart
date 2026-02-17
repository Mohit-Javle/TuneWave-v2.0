import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dart_des/dart_des.dart';
import '../models/song_model.dart';
import '../models/album_model.dart';
import '../models/artist_model.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  // Official JioSaavn API endpoint
  // Use local proxy for Web to avoid CORS
  static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:8082/api.php";
    }
    return "https://www.jiosaavn.com/api.php";
  }

  // Search for songs
  Future<List<SongModel>> searchSongs(String query) async {
    try {
      final uri = Uri.parse(
          '$baseUrl?__call=search.getResults&p=1&q=$query&_format=json&_marker=0&api_version=4&ctx=web6dot0');
      
      debugPrint("ApiService fetching: $uri");

      final response = await http.get(uri, headers: {
        "User-Agent":
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
      });

      if (response.statusCode == 200) {
        // Handle potential invalid JSON responses from official API
        var jsonString = response.body;
        // debugPrint("Response body len: ${jsonString.length}");

        try {
          final data = json.decode(jsonString);
          
          if (data['results'] != null) {
            final List results = data['results'];
            return results.map((item) {
              String encryptedUrl = item['more_info']?['encrypted_media_url'] ?? '';
              String decryptedUrl = _decryptUrl(encryptedUrl);
              return SongModel.fromOfficialJson(item, decryptedUrl: decryptedUrl);
            }).toList();
          }
        } catch (e) {
          debugPrint("JSON Parsing error: $e");
        }
      } else {
        debugPrint("API Error: ${response.statusCode}");
      }
      return [];
    } catch (e) {
      debugPrint("Error searching songs: $e");
      return [];
    }
  }

  // GetLyrics (Official API)
  Future<String> getLyrics(String songId) async {
    try {
       final uri = Uri.parse(
          '$baseUrl?__call=lyrics.getLyrics&ctx=web6dot0&api_version=4&_format=json&_marker=0&lyrics_id=$songId');
       
       final response = await http.get(uri, headers: {
          "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" 
       });
       if (response.statusCode == 200) {
         final data = json.decode(response.body);
         if (data['lyrics'] != null) {
           return data['lyrics'].toString().replaceAll('<br>', '\n');
         }
       }
       return 'No lyrics found.';
    } catch (e) {
      return 'Error fetching lyrics.';
    }
  }

  // Search for albums
  Future<List<AlbumModel>> searchAlbums(String query) async {
    try {
      final uri = Uri.parse(
          '$baseUrl?__call=search.getAlbumResults&p=1&q=$query&_format=json&_marker=0&api_version=4&ctx=web6dot0');

      final response = await http.get(uri, headers: {
        "User-Agent":
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
      });

      if (response.statusCode == 200) {
        var jsonString = response.body;
        try {
          final data = json.decode(jsonString);
          if (data['results'] != null) {
            final List results = data['results'];
            return results.map((item) => AlbumModel.fromOfficialJson(item)).toList();
          }
        } catch (e) {
          debugPrint("JSON Parsing error (Albums): $e");
        }
      }
      return [];
    } catch (e) {
      debugPrint("Error searching albums: $e");
      return [];
    }
  }

  // Search for artists
  Future<List<ArtistModel>> searchArtists(String query) async {
    try {
      final uri = Uri.parse(
          '$baseUrl?__call=search.getArtistResults&p=1&q=$query&_format=json&_marker=0&api_version=4&ctx=web6dot0');

      final response = await http.get(uri, headers: {
        "User-Agent":
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
      });

      if (response.statusCode == 200) {
        var jsonString = response.body;
        try {
          final data = json.decode(jsonString);
          if (data['results'] != null) {
            final List results = data['results'];
            return results.map((item) => ArtistModel.fromOfficialJson(item)).toList();
          }
        } catch (e) {
          debugPrint("JSON Parsing error (Artists): $e");
        }
      }
      return [];
    } catch (e) {
      debugPrint("Error searching artists: $e");
      return [];
    }
  }

  // Get Artist Details (Top Songs & Albums)
  Future<Map<String, dynamic>> getArtistDetails(String artistId) async {
    try {
      final uri = Uri.parse(
          '$baseUrl?__call=artist.getArtistPageDetails&artistId=$artistId&_format=json&_marker=0&api_version=4&ctx=web6dot0');

      final response = await http.get(uri, headers: {
        "User-Agent":
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
      });

      if (response.statusCode == 200) {
        var jsonString = response.body;
        final data = json.decode(jsonString);
        
        List<SongModel> topSongs = [];
        List<AlbumModel> albums = [];

        if (data['topSongs'] != null) {
          final List songsList = data['topSongs'];
          topSongs = songsList.map((item) {
             String encryptedUrl = item['more_info']?['encrypted_media_url'] ?? '';
             String decryptedUrl = _decryptUrl(encryptedUrl);
             return SongModel.fromOfficialJson(item, decryptedUrl: decryptedUrl);
          }).toList();
        }

        if (data['topAlbums'] != null) {
          final List albumsList = data['topAlbums'];
          albums = albumsList.map((item) => AlbumModel.fromOfficialJson(item)).toList();
        }

        return {
          'topSongs': topSongs,
          'albums': albums,
        };
      }
      return {};
    } catch (e) {
      debugPrint("Error fetching artist details: $e");
      return {};
    }
  }

  // Get Album Details
  Future<List<SongModel>> getAlbumDetails(String albumId) async {
    try {
       final uri = Uri.parse(
          '$baseUrl?__call=content.getAlbumDetails&albumid=$albumId&_format=json&_marker=0&api_version=4&ctx=web6dot0');
       
       final response = await http.get(uri);
       if (response.statusCode == 200) {
         final data = json.decode(response.body);
         if (data['list'] != null) {
           final List list = data['list'];
           return list.map((item) {
              String encryptedUrl = item['more_info']?['encrypted_media_url'] ?? '';
              String decryptedUrl = _decryptUrl(encryptedUrl);
              return SongModel.fromOfficialJson(item, decryptedUrl: decryptedUrl);
           }).toList();
         }
       }
       return [];
    } catch (e) {
      debugPrint("Error fetching album details: $e");
      return [];
    }
  }

  String _decryptUrl(String encryptedUrl) {
    if (encryptedUrl.isEmpty) return '';
    try {
      String key = "38346591";
      DES desECB = DES(key: key.codeUnits, mode: DESMode.ECB, paddingType: DESPaddingType.PKCS7);
      
      final encryptedBytes = base64.decode(encryptedUrl);
      final decryptedBytes = desECB.decrypt(encryptedBytes);
      
      final result = utf8.decode(decryptedBytes);
      // debugPrint("Decrypted URL: $result");
      return result;
    } catch (e) {
      debugPrint("Decryption failed for URL: $e");
      return '';
    }
  }
}
