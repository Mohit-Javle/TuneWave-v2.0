import 'package:flutter/material.dart';
import 'package:clone_mp/services/api_service.dart';
import 'package:clone_mp/models/artist_model.dart';

class ArtistSelectionWidget extends StatefulWidget {
  final List<String> selectedArtists;
  final Function(List<String>) onSelectionChanged;

  const ArtistSelectionWidget({
    super.key,
    required this.selectedArtists,
    required this.onSelectionChanged,
  });

  @override
  State<ArtistSelectionWidget> createState() => _ArtistSelectionWidgetState();
}

class _ArtistSelectionWidgetState extends State<ArtistSelectionWidget> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<ArtistModel> _artists = [];

  // Curated list of popular artists to fetch
  final List<String> _popularArtistNames = [
    'Arijit Singh',
    'Taylor Swift',
    'Drake',
    'The Weeknd',
    'Bad Bunny',
    'BTS',
    'Ed Sheeran',
    'Shreya Ghoshal',
    'Atif Aslam',
    'Diljit Dosanjh',
    'Justin Bieber',
    'Dua Lipa',
  ];

  @override
  void initState() {
    super.initState();
    _loadArtists();
  }

  Future<void> _loadArtists() async {
    List<ArtistModel> loadedArtists = [];
    
    // We will fetch search results for each name in parallel
    // and take the first result if available.
    final futures = _popularArtistNames.map((name) => _apiService.searchArtists(name));
    
    try {
      final results = await Future.wait(futures);
      
      for (var artistList in results) {
        if (artistList.isNotEmpty) {
          loadedArtists.add(artistList.first);
        }
      }

      if (mounted) {
        setState(() {
          _artists = loadedArtists;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading artists: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _toggleArtist(ArtistModel artist) {
    final newSelection = List<String>.from(widget.selectedArtists);
    // We store Artist Names or IDs. Using Names for simplicity in UI, 
    // but typically IDs are better. The prompt asked to save "selected artists".
    // I'll save the Artist Name to verify against the list easily, 
    // or I can save the ID. Let's save the NAME for now as it's easier to display back if needed without fetching.
    // Actually, PersonalizationService signature takes List<String>.
    // Let's use Name.
    if (newSelection.contains(artist.name)) {
      newSelection.remove(artist.name);
    } else {
      newSelection.add(artist.name);
    }
    widget.onSelectionChanged(newSelection);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF6600)),
      );
    }

    if (_artists.isEmpty) {
      return Center(
        child: Text(
          "Could not load artists.\nPlease check your connection.",
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Text(
            "Pick at least 2 artists",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.75, // Adjust for image + text
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: _artists.length,
            itemBuilder: (context, index) {
              final artist = _artists[index];
              final isSelected = widget.selectedArtists.contains(artist.name);

              return GestureDetector(
                onTap: () => _toggleArtist(artist),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected 
                                  ? const Color(0xFFFF6600) 
                                  : Colors.transparent,
                              width: 3,
                            ),
                            boxShadow: [
                              if (isSelected)
                                BoxShadow(
                                  color: const Color(0xFFFF6600).withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.network(
                              artist.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[800],
                                  child: const Icon(Icons.person, color: Colors.white),
                                );
                              },
                            ),
                          ),
                        ),
                        if (isSelected)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF6600),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check, size: 16, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      artist.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isSelected 
                            ? const Color(0xFFFF6600) 
                            : theme.colorScheme.onSurface,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
