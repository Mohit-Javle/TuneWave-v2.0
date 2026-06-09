import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/spotify_import_service.dart';

class SpotifyImportSheet extends StatefulWidget {
  const SpotifyImportSheet({super.key});

  @override
  State<SpotifyImportSheet> createState() => _SpotifyImportSheetState();
}

class _SpotifyImportSheetState extends State<SpotifyImportSheet> {
  final TextEditingController _linkController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final service = Provider.of<SpotifyImportService>(context, listen: false);
    final status = service.progressNotifier.value.status;
    if (status == ImportStatus.complete || status == ImportStatus.error) {
      service.reset();
    }
  }

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final importService = Provider.of<SpotifyImportService>(context);
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: ValueListenableBuilder<ImportProgress>(
            valueListenable: importService.progressNotifier,
            builder: (context, progress, child) {
              switch (progress.status) {
                case ImportStatus.initial:
                  return _buildInstructionView(context, importService, theme);
                case ImportStatus.picking:
                case ImportStatus.parsing:
                case ImportStatus.searching:
                case ImportStatus.saving:
                  return _buildProgressView(context, progress, theme);
                case ImportStatus.complete:
                  return _buildCompleteView(context, progress, theme);
                case ImportStatus.error:
                  return _buildErrorView(context, progress, theme, importService);
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionView(BuildContext context, SpotifyImportService service, ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1DB954).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.playlist_add_rounded, color: Color(0xFF1DB954), size: 32),
            ),
            const SizedBox(width: 16),
            Text(
              "Import from Spotify",
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _linkController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: "Paste Spotify playlist link...",
            prefixIcon: const Icon(Icons.link_rounded),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF1DB954), width: 2),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          "Supports open.spotify.com and spotify.link URLs",
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              final url = _linkController.text.trim();
              if (url.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please paste a Spotify playlist link")),
                );
                return;
              }
              service.startImport(url);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1DB954),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: const Text(
              "Import from Spotify",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildProgressView(BuildContext context, ImportProgress progress, ThemeData theme) {
    String statusText = "Preparing...";
    if (progress.status == ImportStatus.picking) statusText = "Resolving Spotify link...";
    if (progress.status == ImportStatus.parsing) statusText = "Fetching Spotify playlist...";
    if (progress.status == ImportStatus.searching) statusText = "Searching songs on Tunewave...";
    if (progress.status == ImportStatus.saving) statusText = "Saving playlist to Cloud...";

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Color(0xFF1DB954))),
        const SizedBox(height: 24),
        Text(
          statusText,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        if (progress.total > 0) ...[
          const SizedBox(height: 12),
          Text(
            "Song ${progress.current} of ${progress.total}",
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.current / progress.total,
              backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF1DB954)),
              minHeight: 8,
            ),
          ),
          if (progress.currentSongName.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              "Current: ${progress.currentSongName}",
              textAlign: TextAlign.center,
              style: const TextStyle(fontStyle: FontStyle.italic),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
        const SizedBox(height: 32),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Continue in background"),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCompleteView(BuildContext context, ImportProgress progress, ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        const Icon(Icons.check_circle_rounded, color: Colors.green, size: 80),
        const SizedBox(height: 24),
        const Text(
          "Import Complete!",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          "Successfully imported ${progress.current} songs to your library.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
        ),
        const SizedBox(height: 40),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => progress.status == ImportStatus.complete ? Provider.of<SpotifyImportService>(context, listen: false).reset() : null,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text("Import Another"),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  Provider.of<SpotifyImportService>(context, listen: false).reset();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6600),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text("Done"),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildErrorView(BuildContext context, ImportProgress progress, ThemeData theme, SpotifyImportService service) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        const Icon(Icons.error_outline_rounded, color: Colors.red, size: 64),
        const SizedBox(height: 24),
        const Text(
          "Import Failed",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          progress.errorMessage ?? "An unexpected error occurred.",
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  service.reset();
                  Navigator.pop(context);
                },
                child: const Text("Close"),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: () => service.reset(),
                child: const Text("Try Again"),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
