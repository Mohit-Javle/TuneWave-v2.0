import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:string_similarity/string_similarity.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../models/song_model.dart';
import 'api_service.dart';
import 'playlist_service.dart';

enum ImportStatus { initial, picking, parsing, searching, saving, complete, error }

class ImportProgress {
  final ImportStatus status;
  final int current;
  final int total;
  final String currentSongName;
  final String? errorMessage;

  ImportProgress({
    required this.status,
    this.current = 0,
    this.total = 0,
    this.currentSongName = '',
    this.errorMessage,
  });
}

class SpotifyImportService extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final PlaylistService _playlistService;
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  ValueNotifier<ImportProgress> progressNotifier = ValueNotifier(ImportProgress(status: ImportStatus.initial));

  static const String _clientId = '7314c88b03174a6fb02fb3eeb7ff0b8d';
  static const String _clientSecret = 'bd50163cb2764a7b8ff09443cc5d4835';

  SpotifyImportService(this._playlistService) {
    _initNotifications();
  }

  void reset() {
    progressNotifier.value = ImportProgress(status: ImportStatus.initial);
    notifyListeners();
  }

  Future<void> _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('mipmap/app_icon');
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    await _notificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _showNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'spotify_import_channel',
      'Spotify Import',
      channelDescription: 'Notifications for Spotify playlist import progress',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await _notificationsPlugin.show(0, title, body, platformChannelSpecifics);
  }

  Future<String> _resolveRedirect(String urlString) async {
    String currentUrl = urlString;
    for (int i = 0; i < 5; i++) {
      if (!currentUrl.contains("spotify.link") && !currentUrl.contains("spoti.fi")) {
        break;
      }
      final uri = Uri.parse(currentUrl);
      final client = http.Client();
      try {
        final request = http.Request('GET', uri)..followRedirects = false;
        request.headers['User-Agent'] =
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
        final response = await client.send(request);
        final redirectUrl = response.headers['location'];
        if (redirectUrl != null && redirectUrl.isNotEmpty) {
          currentUrl = redirectUrl;
        } else {
          break;
        }
      } catch (e) {
        debugPrint("Redirect resolution failed: $e");
        break;
      } finally {
        client.close();
      }
    }
    return currentUrl;
  }

  String? _extractPlaylistId(String url) {
    final regExp = RegExp(r'(?:playlist/|playlist:)([a-zA-Z0-9]{22})');
    final match = regExp.firstMatch(url);
    return match?.group(1);
  }

  Future<Map<String, dynamic>?> _tryScraper(String playlistId) async {
    final url = 'https://open.spotify.com/embed/playlist/$playlistId';
    try {
      final response = await http.get(Uri.parse(url), headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      });
      if (response.statusCode != 200) {
        return null;
      }
      
      final document = html_parser.parse(response.body);
      final scriptTag = document.getElementById('__NEXT_DATA__');
      if (scriptTag != null) {
        final Map<String, dynamic> nextData = json.decode(scriptTag.text);
        final props = nextData['props'];
        if (props is Map) {
          final pageProps = props['pageProps'];
          if (pageProps is Map && pageProps['state'] != null) {
            final state = pageProps['state'];
            if (state is Map) {
              final stateData = state['data'];
              if (stateData is Map) {
                final entity = stateData['entity'];
                if (entity is Map) {
                  final playlistName = entity['name'] ?? entity['title'];
                  final trackList = entity['trackList'];
                  if (trackList is List && trackList.isNotEmpty) {
                    final List<Map<String, String>> tracks = [];
                    for (var t in trackList) {
                      final title = t['title']?.toString() ?? '';
                      final artist = t['subtitle']?.toString() ?? '';
                      if (title.isNotEmpty) {
                        tracks.add({'title': title, 'artist': artist});
                      }
                    }
                    return {
                      'name': playlistName,
                      'tracks': tracks,
                    };
                  }
                }
              }
            }
          }
        }
      }
      
      final rows = document.querySelectorAll('li[data-testid^="tracklist-row-"]');
      if (rows.isNotEmpty) {
        String playlistName = 'Spotify Playlist';
        final img = document.querySelector('img[class*="CoverArtBase_coverArt"]');
        if (img != null) {
          final alt = img.attributes['alt'];
          if (alt != null && alt.endsWith(' cover')) {
            playlistName = alt.substring(0, alt.length - 6);
          } else if (alt != null) {
            playlistName = alt;
          }
        }
        
        final List<Map<String, String>> tracks = [];
        for (var row in rows) {
          final titleEl = row.querySelector('h3');
          final artistEl = row.querySelector('h4');
          if (titleEl != null) {
            final title = titleEl.text.trim();
            final artist = artistEl?.text.trim() ?? '';
            if (title.isNotEmpty) {
              tracks.add({'title': title, 'artist': artist});
            }
          }
        }
        
        if (tracks.isNotEmpty) {
          return {
            'name': playlistName,
            'tracks': tracks,
          };
        }
      }
    } catch (e) {
      debugPrint("Embed Scraper failed: $e");
    }
    return null;
  }

  Future<Map<String, dynamic>?> _tryWebApiFallback(String playlistId) async {
    try {
      final authCreds = base64.encode(utf8.encode('$_clientId:$_clientSecret'));
      final authResponse = await http.post(
        Uri.parse('https://accounts.spotify.com/api/token'),
        headers: {
          'Authorization': 'Basic $authCreds',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'grant_type': 'client_credentials',
        },
      );
      if (authResponse.statusCode != 200) {
        return null;
      }
      final authData = json.decode(authResponse.body);
      final accessToken = authData['access_token'];
      
      final playlistResponse = await http.get(
        Uri.parse('https://api.spotify.com/v1/playlists/$playlistId'),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );
      if (playlistResponse.statusCode != 200) {
        return null;
      }
      final playlistData = json.decode(playlistResponse.body);
      final playlistName = playlistData['name'] ?? 'Spotify Playlist';
      final tracksObj = playlistData['tracks'];
      final List<dynamic> items = tracksObj['items'] ?? [];
      
      final List<Map<String, String>> tracks = [];
      for (var item in items) {
        final track = item['track'];
        if (track != null) {
          final name = track['name']?.toString() ?? '';
          final artists = (track['artists'] as List?)?.map((a) => a['name']).join(', ') ?? '';
          if (name.isNotEmpty) {
            tracks.add({'title': name, 'artist': artists});
          }
        }
      }
      
      String? nextUrl = tracksObj['next'];
      while (nextUrl != null) {
        final nextPageResponse = await http.get(
          Uri.parse(nextUrl),
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        );
        if (nextPageResponse.statusCode == 200) {
          final nextPageData = json.decode(nextPageResponse.body);
          final List<dynamic> nextItems = nextPageData['items'] ?? [];
          for (var item in nextItems) {
            final track = item['track'];
            if (track != null) {
              final name = track['name']?.toString() ?? '';
              final artists = (track['artists'] as List?)?.map((a) => a['name']).join(', ') ?? '';
              if (name.isNotEmpty) {
                tracks.add({'title': name, 'artist': artists});
              }
            }
          }
          nextUrl = nextPageData['next'];
        } else {
          break;
        }
      }
      
      return {
        'name': playlistName,
        'tracks': tracks,
      };
    } catch (e) {
      debugPrint("Web API Fallback failed: $e");
    }
    return null;
  }

  Future<void> startImport(String playlistUrl) async {
    try {
      progressNotifier.value = ImportProgress(status: ImportStatus.picking);
      
      final resolvedUrl = await _resolveRedirect(playlistUrl);
      final playlistId = _extractPlaylistId(resolvedUrl);
      if (playlistId == null) {
        progressNotifier.value = ImportProgress(
          status: ImportStatus.error,
          errorMessage: "Invalid Spotify link. Please provide a link containing a valid playlist ID.",
        );
        return;
      }
      
      progressNotifier.value = ImportProgress(status: ImportStatus.parsing);
      
      Map<String, dynamic>? playlistData = await _tryScraper(playlistId);
      if (playlistData == null) {
        playlistData = await _tryWebApiFallback(playlistId);
      }
      
      if (playlistData == null) {
        progressNotifier.value = ImportProgress(
          status: ImportStatus.error,
          errorMessage: "Failed to fetch Spotify playlist. Make sure the playlist is public or check your internet connection.",
        );
        return;
      }
      
      final playlistName = playlistData['name'] ?? 'Spotify Playlist';
      final List<Map<String, String>> songsToSearch = playlistData['tracks'];
      if (songsToSearch.isEmpty) {
        progressNotifier.value = ImportProgress(
          status: ImportStatus.error,
          errorMessage: "The Spotify playlist is empty.",
        );
        return;
      }
      
      progressNotifier.value = ImportProgress(
        status: ImportStatus.searching,
        total: songsToSearch.length,
        current: 0,
      );
      
      final List<SongModel> matchedSongs = [];
      final List<Map<String, String>> unmatchedSongs = [];
      
      const int batchSize = 5;
      for (int i = 0; i < songsToSearch.length; i += batchSize) {
        final batch = songsToSearch.skip(i).take(batchSize).toList();
        final List<Future<SongModel?>> futures = batch.map((s) => _searchAndMatch(s['title']!, s['artist']!)).toList();
        final results = await Future.wait(futures);
        
        for (int j = 0; j < results.length; j++) {
          final song = results[j];
          final original = batch[j];
          if (song != null) {
            matchedSongs.add(song);
          } else {
            unmatchedSongs.add(original);
          }
        }
        
        progressNotifier.value = ImportProgress(
          status: ImportStatus.searching,
          total: songsToSearch.length,
          current: (i + batch.length).clamp(0, songsToSearch.length),
          currentSongName: batch.isNotEmpty ? batch.last['title']! : '',
        );
        
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      progressNotifier.value = ImportProgress(status: ImportStatus.saving);
      
      if (matchedSongs.isNotEmpty) {
        _playlistService.createPlaylist(
          playlistName,
          source: 'spotify_link',
          unmatchedSongs: unmatchedSongs,
          initialSongs: matchedSongs,
        );
      }
      
      progressNotifier.value = ImportProgress(
        status: ImportStatus.complete,
        total: songsToSearch.length,
        current: matchedSongs.length,
      );
      
      await _showNotification(
        "Import Complete",
        "✅ ${matchedSongs.length} songs imported from '$playlistName'.",
      );
    } catch (e) {
      debugPrint("Import failed: $e");
      progressNotifier.value = ImportProgress(
        status: ImportStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<SongModel?> _searchAndMatch(String track, String artist) async {
    final query1 = "$track $artist";
    SongModel? match = await _performSearchAndMatch(query1, track, artist);
    if (match != null) return match;

    // Split artists for more granular fallbacks
    // Added semicolon (;) to splitting logic
    final artists = artist.split(RegExp(r'[,\&\/\-\;]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    // Attempt 2: Track + Primary Artist (First one)
    if (artists.isNotEmpty) {
      final firstArtist = artists.first;
      debugPrint("🎵 SpotifyImport: Fallback 1 - Searching for track + primary artist: $track $firstArtist");
      match = await _performSearchAndMatch("$track $firstArtist", track, artist);
      if (match != null) return match;
    }

    // Attempt 3: Just Track (Fallback for when artists are completely mismatched)
    // Stage 2: Lowered threshold to 3 characters for songs like "Shor"
    if (track.length >= 3) {
      debugPrint("🎵 SpotifyImport: Fallback 2 - Searching for just track: $track");
      match = await _performSearchAndMatch(track, track, artist);
      if (match != null) return match;
    }

    // Attempt 4: Track + Second Artist (In case the featured artist is the one listed primary on Saavn)
    if (artists.length > 1) {
      final secondArtist = artists[1];
      debugPrint("🎵 SpotifyImport: Fallback 3 - Searching for track + second artist: $track $secondArtist");
      match = await _performSearchAndMatch("$track $secondArtist", track, artist);
      if (match != null) return match;
    }
    
    return null;
  }

  Future<SongModel?> _performSearchAndMatch(String query, String targetTrack, String targetArtist) async {
    final normalizedQuery = _normalize(query, isSearch: true);
    final results = await _apiService.searchSongs(normalizedQuery);

    if (results.isEmpty) return null;

    SongModel? bestMatch;
    double highestScore = 0;
    String debugInfo = "";

    for (var result in results) {
      final scoreData = _calculateMatchScoreDetailed(targetTrack, targetArtist, result.name, result.artist);
      final score = scoreData['total']!;
      
      if (score > highestScore) {
        highestScore = score;
        bestMatch = result;
        debugInfo = "Track: ${scoreData['track']?.toStringAsFixed(2)}, Artist: ${scoreData['artist']?.toStringAsFixed(2)}";
      }
    }

    if (highestScore > 0.75) {
       debugPrint("🎵 SpotifyImport: Match found! [${bestMatch?.name}] by [${bestMatch?.artist}] (Score: ${highestScore.toStringAsFixed(2)}, $debugInfo)");
       return bestMatch;
    } else if (bestMatch != null) {
       debugPrint("🎵 SpotifyImport: Weak match rejected [${bestMatch.name}] by [${bestMatch.artist}] (Score: ${highestScore.toStringAsFixed(2)}, $debugInfo)");
    }
    
    return null;
  }

  Map<String, double> _calculateMatchScoreDetailed(String targetTrack, String targetArtist, String resTrack, String resArtist) {
    final nTargetTrack = _normalize(targetTrack);
    final nResTrack = _normalize(resTrack);
    
    // 1. Track Name Score
    final trackScore = nTargetTrack.similarityTo(nResTrack);

    // 2. Artist Overlap Check
    // Added 'feat', 'ft', and semicolon (;) to splitting logic
    final artistSplitPattern = RegExp(r'[,\&\/\-\;]|feat\.?|ft\.?', caseSensitive: false);
    final targetArtists = targetArtist.toLowerCase().split(artistSplitPattern).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final resArtists = resArtist.toLowerCase().split(artistSplitPattern).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    double artistScore = 0;
    bool anyOverlap = false;

    for (var ta in targetArtists) {
       for (var ra in resArtists) {
         final sim = ta.similarityTo(ra);
         // More lenient artist match (0.80)
         if (sim > 0.80 || ta.contains(ra) || ra.contains(ta)) {
           anyOverlap = true;
           artistScore = sim.clamp(artistScore, 1.0);
         }
       }
    }

    if (!anyOverlap) {
      artistScore = targetArtist.toLowerCase().similarityTo(resArtist.toLowerCase()) * 0.8;
    } else {
      artistScore = (artistScore + 0.4).clamp(0.0, 1.0);
    }

    double finalScore;

    // Phase 2 logic for short names
    if (nTargetTrack.length <= 4 && trackScore > 0.9) {
      if (artistScore < 0.1) {
        finalScore = 0.0;
      } else {
        finalScore = (trackScore * 0.5) + (artistScore * 0.5);
      }
    } else {
      if (artistScore < 0.1 && trackScore < 0.98) {
        finalScore = 0.0;
      } else {
        finalScore = (trackScore * 0.6) + (artistScore * 0.4);
      }
    }

    return {
      'total': finalScore,
      'track': trackScore,
      'artist': artistScore,
    };
  }

  String _normalize(String input, {bool isSearch = false}) {
    String normalized = input.toLowerCase()
        .replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '') // remove (feat...) [remix...]
        .replaceAll(RegExp(r'official|audio|video|lyrics|video|latest', caseSensitive: false), '')
        .replaceAll(RegExp(r'[^\w\s]'), '') // remove special chars
        .trim();
    
    // Don't remove 'remix' or 'edit' for search queries, as users often want specifics
    if (isSearch) {
       // Keep original to some extent but normalized
       return input.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), ' ').trim();
    }
    
    return normalized;
  }
}
