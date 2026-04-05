import 'package:clone_mp/models/song_model.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ShareCardWidget extends StatelessWidget {
  final SongModel song;
  final Color? accentColor;

  const ShareCardWidget({
    super.key,
    required this.song,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    // Generate a beautiful vertical card for sharing (Instagram/Snapchat style)
    final Color topColor = accentColor?.withValues(alpha: 0.9) ?? const Color(0xFF1DB954);
    final Color bottomColor = accentColor?.withValues(alpha: 0.4) ?? const Color(0xFF191414);

    return Container(
      width: 400, // Fixed width for consistent capture
      height: 700, // Story aspect ratio
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [topColor, bottomColor],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          // Profile/App Identity at top
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
               Image.asset('assets/images/logo.png', width: 24, height: 24, errorBuilder: (_, _, _) => const Icon(Icons.music_note, color: Colors.white, size: 24)),
               const SizedBox(width: 8),
               Text(
                 'TUNEWAVE',
                 style: GoogleFonts.outfit(
                   color: Colors.white,
                   fontSize: 14,
                   fontWeight: FontWeight.bold,
                   letterSpacing: 2,
                 ),
               ),
            ],
          ),
          const Spacer(),
          // Main Artwork
          Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 30,
                  spreadRadius: 5,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                song.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(height: 40),
          // Song Info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              children: [
                Text(
                  song.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  song.artist,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(flex: 2),
          // Footer / Call to action
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.link, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Listen now on TuneWave',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
