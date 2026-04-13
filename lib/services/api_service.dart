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
      final success = await _getWithTolerantFallback(
        officialCall: 'search.getResults',
        params: {'q': query, 'p': '1'},
        mirrorPath: '/api/search/songs',
        mirrorParams: {'query': query},
      );

      if (success != null) {
        final data = json.decode(success['body']);
        List? results;
        
        // 1. Official Format or Direct Results
        if (data is Map) {
          if (data['results'] != null) {
            results = data['results'] as List;
          } else if (data['data'] != null) {
            // 2. Community Format (data.results)
            if (data['data'] is Map && data['data']['results'] != null) {
              results = data['data']['results'] as List;
            } else if (data['data'] is List) {
              // 3. Simple list format
              results = data['data'] as List;
            }
          }
        } else if (data is List) {
          results = data;
        }

        if (results != null) {
          return results.map((item) {
            // Use decrypted URL for Official format
            String? decryptedUrl;
            if (success['source'] == 'official') {
              String encryptedUrl = item['more_info']?['encrypted_media_url'] ?? '';
              decryptedUrl = _decryptUrl(encryptedUrl);
            }
            return SongModel.fromOfficialJson(item, decryptedUrl: decryptedUrl ?? '');
          }).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint("Error searching songs: $e");
      return [];
    }
  }

  // --- FAULT TOLERANCE ENGINE ---
  
  static final List<Map<String, String>> _identities = [
     {
       "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
       "Referer": "https://www.jiosaavn.com/",
       "Accept-Language": "en-US,en;q=0.9",
     },
     {
       "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Mobile/15E148 Safari/604.1",
       "Accept": "application/json",
     },
     {
       "User-Agent": "JioSaavn/9.11.1 (Android; 14; Mobile)",
       "X-Requested-With": "com.jio.media.jiobeats",
     }
  ];

  Future<Map<String, dynamic>?> _getWithTolerantFallback({
    required String officialCall,
    Map<String, String> params = const {},
    String? mirrorPath,
    Map<String, String> mirrorParams = const {},
  }) async {
    // 1. Try Official API with different identities
    for (var headers in _identities) {
      try {
        final queryParams = {
          '__call': officialCall,
          '_format': 'json',
          '_marker': '0',
          'api_version': '4',
          'ctx': 'web6dot0',
          ...params,
        };
        
        final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);
        debugPrint("ApiService: Attempting Official with ID ${_identities.indexOf(headers)}: $uri");
        
        final timeoutDuration = Duration(seconds: _identities.indexOf(headers) == 0 ? 6 : 10);
        final response = await http.get(uri, headers: headers).timeout(timeoutDuration);
        
        if (response.statusCode == 200 && !response.body.contains("Access Denied")) {
           // If official search returns empty, it might be restricted. Continue to mirrors.
           if (officialCall.contains('search') && (response.body.contains('"results":[]') || response.body.contains('"results":null'))) {
              debugPrint("ApiService: Official API returned empty results. Moving to failover...");
           } else {
              return {'body': response.body, 'source': 'official'};
           }
        }
        
        if (response.body.contains("Access Denied")) {
           debugPrint("ApiService: Official API BLOCKED with Access Denied. Skipping further IDs for this call.");
           break; // IMMEDIATELY jump to mirrors to save time
        }
        debugPrint("ApiService: ID failed with status ${response.statusCode}");
      } catch (e) {
        debugPrint("ApiService: Identity attempt failed: $e");
      }
    }

    // 2. Try Community Mirrors if official fails (Failover)
    final mirrors = [
      "https://saavn.sumit.co",
      "https://saavn.dev",
      "https://jiosaavn-api-revibe.vercel.app"
    ];

    if (mirrorPath != null) {
      for (var mirror in mirrors) {
        try {
          final uri = Uri.parse("$mirror$mirrorPath").replace(queryParameters: mirrorParams);
          debugPrint("ApiService: Attempting Failover Mirror: $uri");
          
          final response = await http.get(uri).timeout(const Duration(seconds: 10));
          if (response.statusCode == 200) {
            return {'body': response.body, 'source': 'mirror'};
          }
        } catch (e) {
          debugPrint("ApiService: Mirror failover attempt failed: $e");
        }
      }
    }

    return null;
  }

  // Get song details (metadata and fresh URL)
  Future<SongModel?> getSongDetails(String songId) async {
    try {
      final success = await _getWithTolerantFallback(
        officialCall: 'song.getDetails',
        params: {'pids': songId},
        mirrorPath: '/api/songs',
        mirrorParams: {'ids': songId},
      );

      if (success != null) {
        final data = json.decode(success['body']);
        
        // Official format
        if (data is Map && data.containsKey(songId)) {
          final item = data[songId];
          String encryptedUrl = item['more_info']?['encrypted_media_url'] ?? '';
          String decryptedUrl = _decryptUrl(encryptedUrl);
          return SongModel.fromOfficialJson(item, decryptedUrl: decryptedUrl);
        }
        
        // Mirror format
        if (data is Map && data['data'] != null && (data['data'] as List).isNotEmpty) {
          final item = (data['data'] as List).first;
          return SongModel.fromOfficialJson(item);
        }
      }
      return null;
    } catch (e) {
      debugPrint("Error fetching song details: $e");
      return null;
    }
  }

  // GetLyrics (Official API)
  Future<String> getLyrics(String songId) async {
    try {
       final success = await _getWithTolerantFallback(
          officialCall: 'lyrics.getLyrics',
          params: {'lyrics_id': songId},
          mirrorPath: '/api/songs/$songId/lyrics',
       );

       if (success != null) {
         final data = json.decode(success['body']);
         
         // Official format
         if (data is Map && data['lyrics'] != null) {
           return data['lyrics'].toString().replaceAll('<br>', '\n');
         }
         
         // Mirror format
         if (data is Map && data['data'] != null && data['data']['lyrics'] != null) {
            return data['data']['lyrics'].toString();
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
       final success = await _getWithTolerantFallback(
          officialCall: 'search.getAlbumResults',
          params: {'p': '1', 'q': query},
          mirrorPath: '/api/search/albums',
          mirrorParams: {'query': query},
       );

      if (success != null) {
        final data = json.decode(success['body']);
        
        // Official
        if (data is Map && data['results'] != null) {
          final List results = data['results'];
          return results.map((item) => AlbumModel.fromOfficialJson(item)).toList();
        }
        
        // Mirror
        if (data is Map && data['data'] != null && data['data']['results'] != null) {
          final List results = data['data']['results'];
          return results.map((item) => AlbumModel.fromOfficialJson(item)).toList();
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
      final success = await _getWithTolerantFallback(
        officialCall: 'search.getArtistResults',
        params: {'p': '1', 'q': query},
        mirrorPath: '/api/search/artists',
        mirrorParams: {'query': query},
      );

      if (success != null) {
        final data = json.decode(success['body']);
        
        // Official
        if (data is Map && data['results'] != null) {
          final List results = data['results'];
          return results.map((item) => ArtistModel.fromOfficialJson(item)).toList();
        }
        
        // Mirror
        if (data is Map && data['data'] != null && data['data']['results'] != null) {
          final List results = data['data']['results'];
          return results.map((item) => ArtistModel.fromOfficialJson(item)).toList();
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
      final success = await _getWithTolerantFallback(
        officialCall: 'artist.getArtistPageDetails',
        params: {'artistId': artistId},
        mirrorPath: '/api/artists',
        mirrorParams: {'id': artistId},
      );

      if (success != null) {
        final data = json.decode(success['body']);
        
        List<SongModel> topSongs = [];
        List<AlbumModel> albums = [];

        // Official
        if (data is Map && data['topSongs'] != null) {
          final List songsList = data['topSongs'];
          topSongs = songsList.map((item) {
             String encryptedUrl = item['more_info']?['encrypted_media_url'] ?? '';
             String decryptedUrl = _decryptUrl(encryptedUrl);
             return SongModel.fromOfficialJson(item, decryptedUrl: decryptedUrl);
          }).toList();
        }
        
        // Mirror
        if (data is Map && data['data'] != null && data['data']['topSongs'] != null) {
           final List songsList = data['data']['topSongs'];
           topSongs = songsList.map((item) => SongModel.fromOfficialJson(item)).toList();
        }

        if (data is Map && data['topAlbums'] != null) {
          final List albumsList = data['topAlbums'];
          albums = albumsList.map((item) => AlbumModel.fromOfficialJson(item)).toList();
        }
        
        if (data is Map && data['data'] != null && data['data']['topAlbums'] != null) {
           final List albumsList = data['data']['topAlbums'];
           albums = albumsList.map((item) => AlbumModel.fromOfficialJson(item)).toList();
        }

        final info = data['data'] ?? data;
        return {
          'name': info['name'] ?? info['title'] ?? '',
          'image': info['image'] is List ? (info['image'] as List).last['link'] : (info['image'] ?? ''),
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
       final success = await _getWithTolerantFallback(
          officialCall: 'content.getAlbumDetails',
          params: {'albumid': albumId},
          mirrorPath: '/api/albums',
          mirrorParams: {'id': albumId},
       );

       if (success != null) {
         final data = json.decode(success['body']);
         
         // Official
         if (data is Map && data['list'] != null) {
           final List list = data['list'];
           return list.map((item) {
              String encryptedUrl = item['more_info']?['encrypted_media_url'] ?? '';
              String decryptedUrl = _decryptUrl(encryptedUrl);
              return SongModel.fromOfficialJson(item, decryptedUrl: decryptedUrl);
           }).toList();
         }
         
         // Mirror
         if (data is Map && data['data'] != null && data['data']['songs'] != null) {
            final List songs = data['data']['songs'];
            return songs.map((item) => SongModel.fromOfficialJson(item)).toList();
         }
       }
       return [];
    } catch (e) {
      debugPrint("Error fetching album details: $e");
      return [];
    }
  }

  // Get suggested songs (recommendations)
  Future<List<SongModel>> getSuggestedSongs(String songId) async {
    try {
       final success = await _getWithTolerantFallback(
          officialCall: 'recommender.getSuggestedSongs',
          params: {'pid': songId},
          mirrorPath: '/api/songs/$songId/suggestions',
       );

       if (success != null) {
          final data = json.decode(success['body']);
          List? results;
          
          if (data is List) {
            results = data;
          } else if (data is Map) {
            results = (data['data'] as List?) ?? (data['songs'] as List?);
          }

          if (results != null && results.isNotEmpty) {
            return results.map((item) {
              String encryptedUrl = item['more_info']?['encrypted_media_url'] ?? '';
              String decryptedUrl = _decryptUrl(encryptedUrl);
              return SongModel.fromOfficialJson(item, decryptedUrl: decryptedUrl);
            }).toList();
          }
       }
       return [];
    } catch (e) {
      debugPrint("Error fetching suggested songs: $e");
      return [];
    }
  }

  // Get songs by genre and language (for better Autoplay)
  Future<List<SongModel>> getSongsByGenre(String? genre, String? language) async {
    try {
      final query = "${genre ?? ''} ${language ?? ''} hits".trim();
      if (query.isEmpty) return [];

       final success = await _getWithTolerantFallback(
          officialCall: 'search.getResults',
          params: {'q': query, 'p': '1'},
          mirrorPath: '/api/search/songs',
          mirrorParams: {'query': query},
       );

      if (success != null) {
        final data = json.decode(success['body']);
        List? results;
        if (data is Map) {
          results = data['results'] ?? data['data']?['results'];
        }
        if (results != null) {
          return results.map((item) {
            String encryptedUrl = item['more_info']?['encrypted_media_url'] ?? '';
            String decryptedUrl = _decryptUrl(encryptedUrl);
            return SongModel.fromOfficialJson(item, decryptedUrl: decryptedUrl);
          }).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint("Error fetching songs by genre: $e");
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
