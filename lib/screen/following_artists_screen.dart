import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/follow_service.dart';
import '../route_names.dart';

class FollowingArtistsScreen extends StatelessWidget {
  const FollowingArtistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textDark = theme.colorScheme.onSurface;
    final textLight = theme.colorScheme.onSurface.withValues(alpha: 0.7);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Following', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Consumer<FollowService>(
        builder: (context, followService, child) {
          final artists = followService.followedArtistsList;

          if (artists.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_add_outlined, size: 80, color: textLight.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text(
                    'Not following any artists yet',
                    style: TextStyle(color: textLight, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: artists.length,
            itemBuilder: (context, index) {
              final artist = artists[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    radius: 30,
                    backgroundImage: artist['image'] != null && artist['image']!.isNotEmpty
                        ? NetworkImage(artist['image']!.replaceAll(RegExp(r'(?:150x150|50x50)'), '500x500'))
                        : null,
                    child: (artist['image'] == null || artist['image']!.isEmpty)
                        ? Icon(Icons.person, color: textLight)
                        : null,
                  ),
                  title: Text(
                    artist['name'] ?? 'Unknown Artist',
                    style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Text(
                    'Artist',
                    style: TextStyle(color: textLight, fontSize: 13),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.artist,
                      arguments: {
                        'id': artist['id']!,
                        'name': artist['name']!,
                        'image': artist['image'] ?? '',
                      },
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
