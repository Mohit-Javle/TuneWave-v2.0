import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:string_similarity/string_similarity.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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

  Future<void> openExportify() async {
    final Uri url = Uri.parse('https://exportify.net');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  Future<void> startImport() async {
    try {
      progressNotifier.value = ImportProgress(status: ImportStatus.picking);
      
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.single.path == null) {
        progressNotifier.value = ImportProgress(status: ImportStatus.initial);
        return;
      }

      final file = File(result.files.single.path!);
      final playlistName = result.files.single.name.replaceAll('.csv', '').replaceAll('spotify_', '').replaceAll('_', ' ');
      
      progressNotifier.value = ImportProgress(status: ImportStatus.parsing);
      
      String csvString = "";
      try {
        final bytes = await file.readAsBytes();
        debugPrint("CSV File size: ${bytes.length} bytes.");
        if (bytes.length > 2) {
          debugPrint("First 4 bytes (Hex): ${bytes[0].toRadixString(16)}, ${bytes[1].toRadixString(16)}, ${bytes[2].toRadixString(16)}, ${bytes[3].toRadixString(16)}");
        }
        
        // Handle potential UTF-16 encoding (common in Windows CSVs)
        if (bytes.length >= 2 && ((bytes[0] == 0xFF && bytes[1] == 0xFE) || (bytes[0] == 0xFE && bytes[1] == 0xFF))) {
          debugPrint("Detected UTF-16 encoding. Manual decoding...");
          // Simple manual decode for UTF-16 (ignoring high bytes for common chars)
          final List<int> codes = [];
          for (int i = 2; i < bytes.length - 1; i += 2) {
             codes.add(bytes[i]); // Simplistic - assumes little endian and ASCII range
          }
          csvString = String.fromCharCodes(codes);
        } else {
          try {
            csvString = utf8.decode(bytes);
          } catch (e) {
            debugPrint("UTF-8 decode failed, falling back to latin1: $e");
            csvString = latin1.decode(bytes);
          }
        }
      } catch (e) {
        debugPrint("File read failed: $e");
        progressNotifier.value = ImportProgress(status: ImportStatus.error, errorMessage: "Could not read file: $e");
        return;
      }

      var fields = const CsvToListConverter().convert(csvString);

      debugPrint("CSV Parsed: ${fields.length} rows found.");
      
      // Fallback: If only 1 row (header) found, try splitting manually by lines
      // This helps if the CSV has weird EOL characters that the converter missed
      if (fields.length < 2) {
        debugPrint("Standard parsing failed to find data rows. Trying manual line split...");
        final lines = csvString.split(RegExp(r'\r\n|\n|\r'));
        debugPrint("Manual split found ${lines.length} lines.");
        
        if (lines.length >= 2) {
          final List<List<dynamic>> manualFields = [];
          for (var line in lines) {
            if (line.trim().isEmpty) continue;
            try {
              // Convert each line individually
              final lineFields = const CsvToListConverter().convert(line);
              if (lineFields.isNotEmpty) {
                manualFields.add(lineFields[0]);
              }
            } catch (e) {
              debugPrint("Failed to parse manual line: $e");
            }
          }
          if (manualFields.length >= 2) {
            fields = manualFields;
            debugPrint("Manual split succeeded with ${fields.length} rows.");
          }
        }
      }

      if (fields.length < 2) {
        progressNotifier.value = ImportProgress(status: ImportStatus.error, errorMessage: "CSV parsing failed. Only ${fields.length} row(s) found. Try a different CSV export.");
        return;
      }

      // Find the headers
      final headers = fields[0].map((e) => e.toString().toLowerCase().trim()).toList();
      debugPrint("CSV Headers: $headers");

      int trackIndex = headers.indexOf('track name');
      int artistIndex = headers.indexOf('artist name(s)');
      
      // Fallback if headers don't match exactly - check for variations
      if (trackIndex == -1) {
        trackIndex = headers.indexWhere((h) => h.contains('track') || h.contains('title') || h.contains('name'));
      }
      if (artistIndex == -1) {
        artistIndex = headers.indexWhere((h) => h.contains('artist'));
      }

      // Last resort fallback to Exportify defaults (Track=2, Artist=3 or 1 depends on version)
      if (trackIndex == -1) trackIndex = 1; // In user's CSV it's 1 (2nd col)
      if (artistIndex == -1) artistIndex = 3; // In user's CSV it's 3 (4th col)

      debugPrint("Using indices: trackIndex=$trackIndex, artistIndex=$artistIndex");

      final List<Map<String, String>> songsToSearch = [];
      for (var i = 1; i < fields.length; i++) {
        final row = fields[i];
        if (row.isEmpty) continue;

        if (row.length > trackIndex && row.length > artistIndex) {
          final track = row[trackIndex].toString().trim();
          final artist = row[artistIndex].toString().trim();
          
          if (track.isNotEmpty && track != "null" && track != "NaN") {
            songsToSearch.add({'track': track, 'artist': artist});
          }
        }
      }

      if (songsToSearch.isEmpty) {
        progressNotifier.value = ImportProgress(status: ImportStatus.error, errorMessage: "No songs found in CSV.");
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
        
        final List<Future<SongModel?>> futures = batch.map((s) => _searchAndMatch(s['track']!, s['artist']!)).toList();
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
          currentSongName: batch.isNotEmpty ? batch.last['track']! : '',
        );

        // Batch delay
        await Future.delayed(const Duration(milliseconds: 500));
      }

      progressNotifier.value = ImportProgress(status: ImportStatus.saving);

      if (matchedSongs.isNotEmpty) {
        _playlistService.createPlaylist(
          playlistName,
          source: 'spotify_exportify',
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
      debugPrint("Import Error: $e");
      progressNotifier.value = ImportProgress(status: ImportStatus.error, errorMessage: e.toString());
    }
  }

  Future<SongModel?> _searchAndMatch(String track, String artist) async {
    // Attempt 1: Track + Artist (Standard)
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

  double _calculateMatchScore(String targetTrack, String targetArtist, String resTrack, String resArtist) {
    return _calculateMatchScoreDetailed(targetTrack, targetArtist, resTrack, resArtist)['total']!;
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
