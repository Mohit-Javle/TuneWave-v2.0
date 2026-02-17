// screen/notification_screen.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  // Re-using the theme colors for consistency
  static const Color primaryOrange = Color(0xFFFF6600);
  static const Color lightestOrange = Color(0xFFFFAF7A);

  // ### REMOVED: Static text/icon colors to use theme colors instead ###

  // A sample list of notifications
  static final List<Map<String, dynamic>> _notifications = const [
    {
      'icon': Icons.music_note,
      'title': 'New Release',
      'body': 'Your favorite artist, The Weeknd, just dropped a new single!',
      'time': '5m ago',
    },
    {
      'icon': Icons.playlist_add_check,
      'title': 'Playlist Updated',
      'body': 'Your "Chill Vibes" playlist has new songs added for you.',
      'time': '1h ago',
    },
    {
      'icon': Icons.podcasts,
      'title': 'New Podcast Episode',
      'body': 'A new episode of "Tech Forward" is now available.',
      'time': '3h ago',
    },
    {
      'icon': Icons.mic,
      'title': 'Artist Live Stream',
      'body': 'Billie Eilish is going live in 15 minutes. Don\'t miss out!',
      'time': 'Yesterday',
    },
  ];

  @override
  Widget build(BuildContext context) {
    // ### ADD: Get the current theme ###
    final theme = Theme.of(context);
    final textDark = theme.colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface, // ### CHANGE ###
        elevation: 1,
        title: Text(
          'Notifications',
          style: TextStyle(
            color: textDark,
            fontWeight: FontWeight.bold,
          ), // ### CHANGE ###
        ),
        iconTheme: IconThemeData(color: textDark), // ### CHANGE ###
      ),
      body: Container(
        // ### CHANGE: Use a conditional gradient based on theme brightness ###
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: theme.brightness == Brightness.light
                ? [Colors.white, const Color.fromARGB(100, 255, 218, 192)]
                : [theme.colorScheme.surface, theme.colorScheme.background],
            stops: const [0.3, 0.7],
          ),
        ),
        child: _notifications.isEmpty
            ? _buildEmptyState(context)
            : _buildNotificationList(context),
      ),
    );
  }

  Widget _buildNotificationList(BuildContext context) {
    final theme = Theme.of(context);
    final textDark = theme.colorScheme.onSurface;
    final textLight = theme.colorScheme.onSurface.withOpacity(0.7);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      itemCount: _notifications.length,
      itemBuilder: (context, index) {
        final notification = _notifications[index];
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(0.8), // ### CHANGE ###
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withOpacity(0.05), // ### CHANGE ###
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: lightestOrange.withOpacity(0.3),
              child: Icon(
                notification['icon'] as IconData,
                color: primaryOrange,
              ),
            ),
            title: Text(
              notification['title'] as String,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: textDark, // ### CHANGE ###
              ),
            ),
            subtitle: Text(
              notification['body'] as String,
              style: TextStyle(color: textLight), // ### CHANGE ###
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              notification['time'] as String,
              style: TextStyle(
                color: textLight,
                fontSize: 12,
              ), // ### CHANGE ###
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final textDark = theme.colorScheme.onSurface;
    final textLight = theme.colorScheme.onSurface.withOpacity(0.7);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 80,
            color: textLight,
          ), // ### CHANGE ###
          const SizedBox(height: 16),
          Text(
            'You\'re all caught up!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textDark, // ### CHANGE ###
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'New notifications will appear here.',
            style: TextStyle(fontSize: 16, color: textLight), // ### CHANGE ###
          ),
        ],
      ),
    );
  }
}
