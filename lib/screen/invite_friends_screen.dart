// lib/screen/invite_friends_screen.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class InviteFriendsScreen extends StatelessWidget {
  const InviteFriendsScreen({super.key});

  static const Color primaryOrange = Color(0xFFFF6600);

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
                            style: TextStyle(color: textLight),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            Clipboard.setData(
                              const ClipboardData(text: inviteLink),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Invite link copied!'),
                                backgroundColor: primaryOrange,
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Copy'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryOrange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
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
