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
          currentSongName: batch.last['track']!,
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
    final query = _normalize("$track $artist");
    final results = await _apiService.searchSongs(query);

    if (results.isEmpty) return null;

    SongModel? bestMatch;
    double highestScore = 0;

    for (var result in results) {
      final score = _calculateMatchScore(track, artist, result.name, result.artist);
      if (score > highestScore) {
        highestScore = score;
        bestMatch = result;
      }
    }

    // Threshold
    if (highestScore > 0.75) {
      return bestMatch;
    }
    
    return null;
  }

  double _calculateMatchScore(String targetTrack, String targetArtist, String resTrack, String resArtist) {
    final nTargetTrack = _normalize(targetTrack);
    final nTargetArtist = _normalize(targetArtist);
    final nResTrack = _normalize(resTrack);
    final nResArtist = _normalize(resArtist);

    final trackScore = nTargetTrack.similarityTo(nResTrack);
    final artistScore = nTargetArtist.similarityTo(nResArtist);

    // Give track name more weight
    return (trackScore * 0.7) + (artistScore * 0.3);
  }

  String _normalize(String input) {
    return input.toLowerCase()
        .replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '') // Remove anything in parens/brackets
        .replaceAll(RegExp(r' - .*'), '') // Remove everything after dash
        .replaceAll(RegExp(r'feat\.|ft\.|official|audio|video|lyrics|remix|mix|edit', caseSensitive: false), '')
        .replaceAll(RegExp(r'[^\w\s]'), '') // Remove special chars
        .trim();
  }
}
