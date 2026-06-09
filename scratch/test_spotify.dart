import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

const String SPOTIFY_CLIENT_ID = '7314c88b03174a6fb02fb3eeb7ff0b8d';
const String SPOTIFY_CLIENT_SECRET = 'bd50163cb2764a7b8ff09443cc5d4835';

Future<String> resolveRedirect(String urlString) async {
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
      print("Redirect resolution failed: $e");
      break;
    } finally {
      client.close();
    }
  }
  return currentUrl;
}

String? extractPlaylistId(String url) {
  final regExp = RegExp(r'(?:playlist/|playlist:)([a-zA-Z0-9]{22})');
  final match = regExp.firstMatch(url);
  return match?.group(1);
}

Future<Map<String, dynamic>?> tryScraper(String playlistId) async {
  print("Attempting Phase 1: Embed Scraper...");
  final url = 'https://open.spotify.com/embed/playlist/$playlistId';
  try {
    final response = await http.get(Uri.parse(url), headers: {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    });
    if (response.statusCode != 200) {
      print("Embed Scraper returned status code: ${response.statusCode}");
      return null;
    }
    print("Scraper: Got response. Length = ${response.body.length}");
    print("First 1000 chars: ${response.body.substring(0, response.body.length > 1000 ? 1000 : response.body.length)}");
    final document = html_parser.parse(response.body);
    final scriptTag = document.getElementById('__NEXT_DATA__');
    if (scriptTag == null) {
      print("Embed Scraper: Could not find __NEXT_DATA__ script tag.");
      // Let's print script tags in the head/body to see if they exist
      final scripts = document.getElementsByTagName('script');
      print("Found ${scripts.length} script tags.");
      for (var s in scripts) {
        if (s.text.contains("props") || s.text.contains("track")) {
          print("A script tag contains 'props' or 'track', length: ${s.text.length}");
        }
      }
      return null;
    }
    print("Found __NEXT_DATA__! Parsing JSON...");
    final Map<String, dynamic> nextData = json.decode(scriptTag.text);
    print("JSON keys: ${nextData.keys.toList()}");
    final props = nextData['props'];
    if (props is Map) {
      print("props keys: ${props.keys.toList()}");
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
                print("Scraper Succeeded via JSON! Name: $playlistName, tracks found: ${trackList.length}");
                return {
                  'name': playlistName,
                  'tracks': trackList.map((t) => {
                    'title': t['title'],
                    'artist': t['subtitle'],
                  }).toList(),
                };
              }
            }
          }
        }
      }
    }
    
    // DOM-based fallback parsing
    print("JSON parsing failed or state was null. Trying DOM-based fallback parsing...");
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
        print("Scraper Succeeded via DOM! Name: $playlistName, tracks found: ${tracks.length}");
        return {
          'name': playlistName,
          'tracks': tracks,
        };
      }
    }
    
    print("Embed Scraper failed to extract properties. Structure did not match.");
  } catch (e) {
    print("Scraper failed with exception: $e");
  }
  return null;
}

Future<Map<String, dynamic>?> tryWebApiFallback(String playlistId) async {
  print("Attempting Phase 2: Spotify Web API Fallback...");
  try {
    final authCreds = base64.encode(utf8.encode('$SPOTIFY_CLIENT_ID:$SPOTIFY_CLIENT_SECRET'));
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
      print("Web API token fetch failed: ${authResponse.body}");
      return null;
    }
    final authData = json.decode(authResponse.body);
    final accessToken = authData['access_token'];
    
    // Fetch Playlist Details
    final playlistResponse = await http.get(
      Uri.parse('https://api.spotify.com/v1/playlists/$playlistId'),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );
    if (playlistResponse.statusCode != 200) {
      print("Web API playlist fetch failed: ${playlistResponse.body}");
      return null;
    }
    final playlistData = json.decode(playlistResponse.body);
    final playlistName = playlistData['name'];
    final tracksObj = playlistData['tracks'];
    final List<dynamic> items = tracksObj['items'] ?? [];
    
    final List<Map<String, String>> tracks = [];
    for (var item in items) {
      final track = item['track'];
      if (track != null) {
        final name = track['name'];
        final artists = (track['artists'] as List?)?.map((a) => a['name']).join(', ') ?? '';
        tracks.add({'title': name, 'artist': artists});
      }
    }
    
    // Handle pagination
    String? nextUrl = tracksObj['next'];
    while (nextUrl != null) {
      print("Fetching next page: $nextUrl");
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
            final name = track['name'];
            final artists = (track['artists'] as List?)?.map((a) => a['name']).join(', ') ?? '';
            tracks.add({'title': name, 'artist': artists});
          }
        }
        nextUrl = nextPageData['next'];
      } else {
        print("Failed to fetch next page, stopping pagination.");
        break;
      }
    }
    
    print("API Succeeded! Name: $playlistName, tracks fetched: ${tracks.length}");
    return {
      'name': playlistName,
      'tracks': tracks,
    };
  } catch (e) {
    print("Web API failed with exception: $e");
  }
  return null;
}

void main() async {
  // Test with a known public playlist
  final testUrl = 'https://open.spotify.com/playlist/5k9sz7e4ave0ZdJxqWnQMe';
  print("Testing url: $testUrl");
  final resolved = await resolveRedirect(testUrl);
  print("Resolved URL: $resolved");
  final id = extractPlaylistId(resolved);
  print("Extracted ID: $id");
  if (id != null) {
    var result = await tryScraper(id);
    if (result == null) {
      result = await tryWebApiFallback(id);
    }
    if (result != null) {
      print("SUCCESS!");
      print("Playlist Name: ${result['name']}");
      print("Total Tracks: ${result['tracks']?.length}");
      if ((result['tracks'] as List).isNotEmpty) {
        print("First Track: ${result['tracks'][0]}");
      }
    } else {
      print("FAILED BOTH PHASES!");
    }
  }
}
