// services/download_service.dart

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/song_model.dart';

class DownloadService extends ChangeNotifier {
  final Dio _dio = Dio();
  final Map<String, double> _downloadProgress = {}; // Track download progress by song ID
  final Map<String, CancelToken> _cancelTokens = {}; // For canceling downloads
  List<SongModel> _downloadedSongs = [];
  
  List<SongModel> get downloadedSongs => _downloadedSongs;
  
  double getDownloadProgress(String songId) {
    return _downloadProgress[songId] ?? 0.0;
  }
  
  bool isDownloading(String songId) {
    return _cancelTokens.containsKey(songId);
  }

  Future<void> init() async {
    await _loadDownloadedSongs();
  }

  /// Load downloaded songs from SharedPreferences
  Future<void> _loadDownloadedSongs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final downloadedJson = prefs.getStringList('downloaded_songs') ?? [];
      _downloadedSongs = downloadedJson
          .map((jsonStr) => SongModel.fromJson(json.decode(jsonStr)))
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading downloaded songs: $e');
    }
  }

  /// Save downloaded songs to SharedPreferences
  Future<void> _saveDownloadedSongs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final downloadedJson = _downloadedSongs
          .map((song) => json.encode(song.toJson()))
          .toList();
      await prefs.setStringList('downloaded_songs', downloadedJson);
    } catch (e) {
      debugPrint('Error saving downloaded songs: $e');
    }
  }

  /// Request storage permission
  Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      // Check SDK version (though in Flutter we usually check permissions directly)
      // For Android 13+ (API 33+), usage of READ_EXTERNAL_STORAGE is replaced by granular media permissions
      
      // Try audio permission first (for Android 13+)
      if (await Permission.audio.status.isGranted) {
        return true;
      }
      
      // Try legacy storage permission
      if (await Permission.storage.status.isGranted) {
        return true;
      }
      
      // Request permissions based on likely SDK level (or just request both, safe to do)
      // On Android 13, storage request might be denied automatically, so we request audio/media
      
      Map<Permission, PermissionStatus> statuses = await [
        Permission.storage,
        Permission.audio, 
      ].request();
      
      if (statuses[Permission.audio]?.isGranted == true || statuses[Permission.storage]?.isGranted == true) {
        return true;
      }
      
      // If we are here, permission is denied.
      // On Android 10+ (API 29+), basic file access in app-specific dirs doesn't actually need 
      // WRITE_EXTERNAL_STORAGE, but we might need it if we were writing to public dirs.
      // Since we use getExternalStorageDirectory() which is app-specific, 
      // we might technically get away without it on newer Androids, 
      // but proper permission handling is good practice.
      
      // One final check: if we can write to the app dir without explicit permission (Android 10+ scoped storage)
      if (await _testFileWrite()) {
        return true;
      }

      return false;
    }
    return true; // iOS doesn't need storage permission for app directory
  }

  Future<bool> _testFileWrite() async {
     try {
       final dir = await getExternalStorageDirectory();
       if (dir == null) return false;
       final testFile = File('${dir.path}/test_perm.txt');
       await testFile.writeAsString('test');
       await testFile.delete();
       return true;
     } catch (e) {
       return false;
     }
  }

  /// Get the downloads directory
  Future<Directory> _getDownloadsDirectory() async {
    if (Platform.isAndroid) {
      // Use app-specific directory (doesn't require permission on Android 10+)
      final dir = await getExternalStorageDirectory();
      final downloadDir = Directory('${dir!.path}/TuneWave/Downloads');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      return downloadDir;
    } else {
      // iOS
      final dir = await getApplicationDocumentsDirectory();
      final downloadDir = Directory('${dir.path}/Downloads');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      return downloadDir;
    }
  }

  /// Download a song
  Future<SongModel?> downloadSong(SongModel song) async {
    try {
      // Check if already downloaded
      if (_downloadedSongs.any((s) => s.id == song.id)) {
        debugPrint('Song already downloaded: ${song.name}');
        return _downloadedSongs.firstWhere((s) => s.id == song.id);
      }

      // Request permission
      final hasPermission = await requestStoragePermission();
      if (!hasPermission) {
        debugPrint('Storage permission denied');
        return null;
      }

      // Get download directory
      final downloadDir = await _getDownloadsDirectory();
      
      // Create safe filename
      final safeFileName = '${song.id}_${_sanitizeFilename(song.name)}.mp3';
      final filePath = '${downloadDir.path}/$safeFileName';

      // Check if download URL is valid
      if (song.downloadUrl.isEmpty) {
        debugPrint('Invalid download URL for: ${song.name}');
        return null;
      }

      // Create cancel token
      final cancelToken = CancelToken();
      _cancelTokens[song.id] = cancelToken;
      _downloadProgress[song.id] = 0.0;
      notifyListeners();

      // Download file
      await _dio.download(
        song.downloadUrl,
        filePath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            _downloadProgress[song.id] = (received / total);
            notifyListeners();
          }
        },
      );

      // Remove from active downloads
      _cancelTokens.remove(song.id);
      _downloadProgress.remove(song.id);

      // Create updated song with local path
      final downloadedSong = SongModel(
        id: song.id,
        name: song.name,
        artist: song.artist,
        album: song.album,
        imageUrl: song.imageUrl,
        downloadUrl: song.downloadUrl,
        hasLyrics: song.hasLyrics,
        isDownloaded: true,
        localFilePath: filePath,
        downloadedAt: DateTime.now(),
      );

      // Add to downloaded list
      _downloadedSongs.add(downloadedSong);
      await _saveDownloadedSongs();
      notifyListeners();

      debugPrint('Successfully downloaded: ${song.name}');
      return downloadedSong;
    } catch (e) {
      debugPrint('Error downloading song: $e');
      _cancelTokens.remove(song.id);
      _downloadProgress.remove(song.id);
      notifyListeners();
      return null;
    }
  }

  /// Cancel an ongoing download
  Future<void> cancelDownload(String songId) async {
    final cancelToken = _cancelTokens[songId];
    if (cancelToken != null) {
      cancelToken.cancel('Download canceled by user');
      _cancelTokens.remove(songId);
      _downloadProgress.remove(songId);
      notifyListeners();
    }
  }

  /// Delete a downloaded song
  Future<bool> deleteSong(String songId) async {
    try {
      final song = _downloadedSongs.firstWhere((s) => s.id == songId);
      
      // Delete file
      if (song.localFilePath != null) {
        final file = File(song.localFilePath!);
        if (await file.exists()) {
          await file.delete();
        }
      }

      // Remove from list
      _downloadedSongs.removeWhere((s) => s.id == songId);
      await _saveDownloadedSongs();
      notifyListeners();

      debugPrint('Successfully deleted: ${song.name}');
      return true;
    } catch (e) {
      debugPrint('Error deleting song: $e');
      return false;
    }
  }

  /// Check if a song is downloaded
  bool isSongDownloaded(String songId) {
    return _downloadedSongs.any((s) => s.id == songId);
  }

  /// Get downloaded version of a song
  SongModel? getDownloadedSong(String songId) {
    try {
      return _downloadedSongs.firstWhere((s) => s.id == songId);
    } catch (e) {
      return null;
    }
  }

  /// Clear all downloads
  Future<void> clearAllDownloads() async {
    try {
      // Delete all files
      for (final song in _downloadedSongs) {
        if (song.localFilePath != null) {
          final file = File(song.localFilePath!);
          if (await file.exists()) {
            await file.delete();
          }
        }
      }

      // Clear list
      _downloadedSongs.clear();
      await _saveDownloadedSongs();
      notifyListeners();

      debugPrint('All downloads cleared');
    } catch (e) {
      debugPrint('Error clearing downloads: $e');
    }
  }

  /// Get total storage used by downloads
  Future<int> getTotalStorageUsed() async {
    int totalBytes = 0;
    for (final song in _downloadedSongs) {
      if (song.localFilePath != null) {
        final file = File(song.localFilePath!);
        if (await file.exists()) {
          totalBytes += await file.length();
        }
      }
    }
    return totalBytes;
  }

  /// Sanitize filename to remove invalid characters
  String _sanitizeFilename(String filename) {
    return filename
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(' ', '_')
        .substring(0, filename.length > 50 ? 50 : filename.length);
  }

  @override
  void dispose() {
    // Cancel all ongoing downloads
    for (final cancelToken in _cancelTokens.values) {
      cancelToken.cancel();
    }
    _cancelTokens.clear();
    super.dispose();
  }
}
