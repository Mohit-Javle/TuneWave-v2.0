// lib/screen/invite_friends_screen.dart
// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class InviteFriendsScreen extends StatelessWidget {
  const InviteFriendsScreen({super.key});

  static const Color primaryOrange = Color(0xFFFF6600);

  // Native channel for APK sharing
  static const _channel = MethodChannel('com.example.tunewave/apk_share');

  // Sharing method
  Future<void> _shareApp(BuildContext context) async {
    try {
      // Show loading toast
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Preparing APK for sharing... This might take a moment."),
          duration: Duration(seconds: 2),
          backgroundColor: primaryOrange,
        ),
      );

      final String? originalApkPath = await _channel.invokeMethod<String>('getApkPath');
      
      if (originalApkPath != null) {
        final File originalFile = File(originalApkPath);
        
        // Copy to a temporary location with a clean name for better app compatibility (like WhatsApp)
        final tempDir = await getTemporaryDirectory();
        final String fileName = "TuneWave.apk";
        final File tempFile = File("${tempDir.path}/$fileName");
        
        // Only copy if it doesn't exist or if you want to ensure the latest
        await originalFile.copy(tempFile.path);

        // Share the copied APK file
        await Share.shareXFiles(
          [XFile(tempFile.path, name: fileName, mimeType: 'application/vnd.android.package-archive')],
          text: "Hey! Join me on TuneWave. 🎵 Install this app and join the vibe!",
          subject: "TuneWave App Sharing",
        );
      } else {
        throw Exception("Could not find the app's APK path.");
      }
    } catch (e) {
      debugPrint("Error sharing APK: $e");
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Sharing failed: ${e.toString().split(':').last.trim()}"),
            backgroundColor: Colors.red,
          ),
        );
      }

      // Fallback: Share link if file sharing fails
      const String downloadUrl = "https://tunewave.app/download"; 
      await Share.share(
        "Hey! Join me on TuneWave. 🎵 Download the app here: $downloadUrl",
        subject: "Join me on TuneWave!",
      );
    }
  }

  // Dummy data for suggested friends
  final List<Map<String, String>> suggestedFriends = const [
    {
      "name": "Sem Surti",
      "handle": "@sem",
      "imageUrl":
          "https://i.ibb.co/TDx4fd0B/Whats-App-Image-2025-09-02-at-10-25-07-PM.jpg",
    },
    {
      "name": "Nanu Vasava",
      "handle": "@nanu",
      "imageUrl": "https://i.pravatar.cc/150?img=2",
    },
    {
      "name": "Karan Chaurdhary",
      "handle": "@kaluva",
      "imageUrl": "https://i.pravatar.cc/150?img=3",
    },
    {
      "name": "Fatima Al-Sayed",
      "handle": "@fatima_as",
      "imageUrl": "https://i.pravatar.cc/150?img=4",
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textDark = theme.colorScheme.onSurface;
    final textLight = theme.colorScheme.onSurface.withOpacity(0.7);

    const inviteLink = "https://music.app/join/aBcDeFg123";

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 1,
        title: Text(
          'Invite Friends',
          style: TextStyle(color: textDark, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: textDark),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [theme.colorScheme.surface, theme.colorScheme.background],
            stops: const [0.3, 0.7],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 24.0),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const Icon(
                    Icons.group_add_outlined,
                    size: 80,
                    color: primaryOrange,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Share the Vibe',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Invite your friends to join the app and share your favorite music discoveries!',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: textLight,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _shareApp(context),
                          icon: const Icon(Icons.share_rounded, size: 20),
                          label: const Text(
                            'Share App Link',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryOrange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            inviteLink,
                            style: TextStyle(color: textLight, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Clipboard.setData(
                              const ClipboardData(text: inviteLink),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Link copied!'),
                                backgroundColor: primaryOrange,
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy, size: 14),
                          label: const Text('Copy', style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(
                            foregroundColor: primaryOrange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                'Suggestions',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 10),
            ...suggestedFriends.map(
              (friend) => _buildFriendTile(
                context,
                friend['name']!,
                friend['handle']!,
                friend['imageUrl']!,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendTile(
    BuildContext context,
    String name,
    String handle,
    String imageUrl,
  ) {
    final theme = Theme.of(context);
    final textLight = theme.colorScheme.onSurface.withOpacity(0.7);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      leading: CircleAvatar(
        radius: 25,
        backgroundImage: NetworkImage(imageUrl),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(handle, style: TextStyle(color: textLight)),
      trailing: OutlinedButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invite sent to $name!'),
              backgroundColor: Colors.green,
            ),
          );
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryOrange,
          side: const BorderSide(color: primaryOrange),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: const Text('Invite'),
      ),
    );
  }
}
