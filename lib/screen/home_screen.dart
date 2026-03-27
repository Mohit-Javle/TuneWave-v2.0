// home_screen.dart
// ignore_for_file: prefer_final_fields, deprecated_member_use, use_build_context_synchronously

import 'package:clone_mp/services/api_service.dart';
import 'package:clone_mp/widgets/spotify_import_sheet.dart';
import 'package:flutter/material.dart';
import 'package:clone_mp/route_names.dart';
import 'package:provider/provider.dart';

import 'package:clone_mp/services/auth_service.dart';
import 'package:clone_mp/models/user_model.dart';
import 'package:clone_mp/services/ui_state_service.dart';
import 'package:clone_mp/services/personalization_service.dart';
import 'package:clone_mp/services/follow_service.dart';
import 'package:clone_mp/services/music_service.dart';
import 'package:clone_mp/services/playlist_service.dart';
import 'package:clone_mp/widgets/avatar_image_provider.dart';
import 'package:clone_mp/widgets/music_toast.dart';
import 'package:clone_mp/models/album_model.dart';

class HomeScreen extends StatefulWidget {
  final Function(SongModel, List<SongModel>, int) onPlaySong;
  final VoidCallback onTogglePlayPause;

  const HomeScreen({
    super.key,
    required this.onPlaySong,
    required this.onTogglePlayPause,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String selectedFilter = "All";
  bool isLoading = true;

  List<Map<String, dynamic>> dynamicFeaturedPlaylists = [];
  Map<String, List<SongModel>> playlistSongsData = {};

  List<SongModel> recentlyPlayed = [];
  List<SongModel> topCharts = [];
  List<Map<String, String>> dynamicPopularArtists = [];

  bool showAllTopCharts = false;

  final List<String> genres = [
    "All",
    "Pop",
    "Hip-Hop",
    "Bollywood",
    "Punjabi",
    "Indie",
  ];

  @override
  void initState() {
    super.initState();
    // Use a post-frame callback to trigger load if needing context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      
      // Listen for follow changes to refresh home feed
      final followService = Provider.of<FollowService>(context, listen: false);
      followService.addListener(_onFollowChanged);
    });
  }

  void _onFollowChanged() {
    if (mounted) {
      _loadData();
    }
  }

  @override
  void dispose() {
    // Safely remove listener if possible, though provider usually handles this
    // but since we added it manually to the service instance:
    try {
      final followService = Provider.of<FollowService>(context, listen: false);
      followService.removeListener(_onFollowChanged);
    } catch (_) {}
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final api = ApiService();
      final currentUser = AuthService.instance.currentUser;
      
      List<SongModel> allRecentSongs = [];
      List<SongModel> allChartSongs = [];
      List<Map<String, String>> artistsList = [];
      List<Map<String, dynamic>> newPlaylists = [];
      final Map<String, List<SongModel>> newPlaylistData = {};

      if (currentUser != null) {
        final personalizationService = Provider.of<PersonalizationService>(context, listen: false);
        final followService = Provider.of<FollowService>(context, listen: false);
        
        final personalData = await personalizationService.getPersonalizationData(currentUser.email);
        final followedArtists = followService.followedArtistsList;

        List<String> userGenres = [];
        List<String> userArtistNames = [];

        if (personalData != null) {
          userGenres = List<String>.from(personalData['genres'] ?? []);
          userArtistNames = List<String>.from(personalData['artists'] ?? []);
        }

        // Build dynamic popular artists list
        // Priority 1: Followed Artists
        // Priority 2: Personalized Artists
        artistsList = List<Map<String, String>>.from(followedArtists);
        
        // --- LAZY METADATA DISCOVERY ---
        // Identify artists with missing info and repair in background
        for (var artist in artistsList) {
          final id = artist['id'] ?? '';
          final name = artist['name'] ?? '';
          if (id.isNotEmpty && (name == 'Unknown' || name == 'Artist' || name.isEmpty)) {
            // Fetch missing info in background (don't await to keep home screen fast)
            api.getArtistDetails(id).then((details) {
              if (details.isNotEmpty && details['name'] != null) {
                followService.updateArtistMetadata(
                  id, 
                  details['name'], 
                  details['image'] ?? ''
                );
              }
            }).catchError((e) {
              debugPrint("Discovery failed for $id: $e");
              return null;
            });
          }
        }

        // Add personalized artists if not already in followed list
        for (var name in userArtistNames) {
          if (!artistsList.any((a) => a['name']?.toLowerCase() == name.toLowerCase())) {
            artistsList.add({
              'id': 'p_${name.hashCode}',
              'name': name,
              'image': 'https://tse2.mm.bing.net/th?q=$name+Artist&w=500&h=500&c=7'
            });
          }
        }

        // --- FETCHING LOGIC ---
        // Fetch top songs for a small random subset (2) to minimize latency
        final fetchPool = List<Map<String, String>>.from(artistsList)..shuffle();
        final selectedPool = fetchPool.take(2).toList();
        final List<Future<List<SongModel>>> songFutures = [];
        
        for (var artist in selectedPool) {
          songFutures.add(api.searchSongs("${artist['name']!} hits"));
        }
        
        // Add genre searches if pool is small
        if (selectedPool.length < 2 && userGenres.isNotEmpty) {
           for (var genre in userGenres.take(2 - selectedPool.length)) {
             songFutures.add(api.searchSongs("$genre hits"));
           }
        }

        final allResults = await Future.wait(songFutures);
        // Collect & Filter songs per source to fill the 10 slots with quality
        final List<String> blacklist = ["dialogue", "mashup", "remix", "slowed", "reverb", "skit", "speech", "loop", "reaction"];
        
        for (int i = 0; i < allResults.length; i++) {
          final results = allResults[i];
          final sourceArtistName = i < selectedPool.length ? selectedPool[i]['name'] : null;
          
          final filtered = results.where((song) {
            final titleLower = song.name.toLowerCase();
            final artistLower = song.artist.toLowerCase();
            
            // 1. Keyword blacklist (filter out cringe content)
            if (blacklist.any((word) => titleLower.contains(word))) return false;
            
            // 2. Artist Integrity (ensure the followed artist is actually on the track)
            if (sourceArtistName != null) {
               final sourceLower = sourceArtistName.toLowerCase();
               // Song's artist metadata must contain the searched artist's name
               if (!artistLower.contains(sourceLower)) return false;
            }
            
            return true;
          }).toList();
          
          allRecentSongs.addAll(filtered.take(8));
        }

        allRecentSongs.shuffle();
        allRecentSongs = allRecentSongs.take(10).toList();

        // Removed Top Charts fetching to heavily optimize home screen load times
        // --- DYNAMIC FEATURED PLAYLISTS ---
        final playlistService = Provider.of<PlaylistService>(context, listen: false);

        // 1. Your Daily Mix (Liked Songs + Followed Artist Songs)
        final dailyMixSongs = [...playlistService.likedSongs, ...allRecentSongs];
        dailyMixSongs.shuffle();
        if (dailyMixSongs.isNotEmpty) {
          final id = 'daily_mix';
          newPlaylists.add({
            'id': id,
            'title': 'Your Daily Mix',
            'subtitle': 'Made just for you',
            'image': 'https://images.unsplash.com/photo-1493225255756-d9584f8606e9?q=80&w=600&auto=format&fit=crop',
            'songCount': dailyMixSongs.length.toString(),
          });
          newPlaylistData[id] = dailyMixSongs;
        }

        // 2. Genre Station (Based on user selection)
        if (userGenres.isNotEmpty) {
          final topGenre = userGenres[0];
          final genreSongs = await api.searchSongs('$topGenre Hits');
          if (genreSongs.isNotEmpty) {
            final id = 'genre_station';
            newPlaylists.add({
              'id': id,
              'title': '$topGenre Station',
              'subtitle': 'The best of $topGenre',
              'image': 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?q=80&w=600&auto=format&fit=crop',
              'songCount': genreSongs.length.toString(),
            });
            newPlaylistData[id] = genreSongs;
          }
        }

        // 3. Indian Hip Hop (Custom requested)
        final hipHopSongs = await api.searchSongs('Indian Hip Hop');
        if (hipHopSongs.isNotEmpty) {
          final id = 'indian_hip_hop';
          newPlaylists.add({
            'id': id,
            'title': 'Indian Hip Hop',
            'subtitle': 'Street fire from India',
            'image': 'https://images.unsplash.com/photo-1546707012-c24c2809da51?q=80&w=600&auto=format&fit=crop',
            'songCount': hipHopSongs.length.toString(),
          });
          newPlaylistData[id] = hipHopSongs;
        }

        if (mounted) {
           // These will be picked up by the final setState
        }
      } else {
        // Guest fallback
        allRecentSongs = await api.searchSongs("Trending Songs");
        artistsList = [
          {"name": "Seedhe Maut", "image": "https://tse2.mm.bing.net/th?q=Seedhe+Maut+Rapper&w=500&h=500&c=7"},
          {"name": "Arijit Singh", "image": "https://tse2.mm.bing.net/th?q=Arijit+Singh+Singer&w=500&h=500&c=7"},
          {"name": "Drake", "image": "https://tse2.mm.bing.net/th?q=Drake+Rapper&w=500&h=500&c=7"},
        ];
        
        newPlaylists = [
           {
            'id': 'trending',
            'title': 'Trending Now',
            'subtitle': 'Global hits',
            'image': 'https://images.unsplash.com/photo-1514525253361-bee8a187449a?q=80&w=600&auto=format&fit=crop',
            'songCount': allRecentSongs.length.toString(),
          }
        ];
        newPlaylistData['trending'] = allRecentSongs;
      }

      if (mounted) {
        setState(() {
          allRecentSongs.shuffle();
          recentlyPlayed = allRecentSongs;
          topCharts = allChartSongs;
          dynamicPopularArtists = artistsList;
          dynamicFeaturedPlaylists = newPlaylists;
          playlistSongsData = newPlaylistData;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
      }
      debugPrint("Error loading personalized home data: $e");
    }
  }

  Future<void> _showImprovedLogoutDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(height: 10),
              const Icon(
                Icons.logout_rounded,
                color: Color(0xFFFF6600),
                size: 50,
              ),
              const SizedBox(height: 20),
              Text(
                'Confirm Sign Out',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Are you sure you want to sign out?',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 25),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        foregroundColor: theme.colorScheme.onSurface,
                        side: BorderSide(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: const Color.fromRGBO(255, 102, 0, 1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Text('Sign Out'),
                      onPressed: () async {
                        await AuthService.instance.logout();
                        if (context.mounted) {
                          Provider.of<PlaylistService>(context, listen: false).clearData();
                          
                          final musicService = Provider.of<MusicService>(context, listen: false);
                          await musicService.pause();
                          await musicService.clearQueue();
                          
                          Provider.of<UiStateService>(context, listen: false).hideMiniPlayer();
                          
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            AppRoutes.login,
                            (route) => false,
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }


  void _showSpotifyImportSheet(BuildContext context) {
    final uiStateService = Provider.of<UiStateService>(context, listen: false);
    uiStateService.setModalActive(true); // This hides the mini player
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SpotifyImportSheet(),
    ).then((_) => uiStateService.setModalActive(false)); // This restores the mini player
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uiStateService = Provider.of<UiStateService>(context);

    if (isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: theme.colorScheme.primary),
        ),
      );
    }

    return Scaffold(
      drawer: _buildAppDrawer(),
      onDrawerChanged: (isOpened) {
        if (isOpened) {
          uiStateService.hideMiniPlayer();
        } else {
          uiStateService.showMiniPlayer();
        }
      },
      body: Container(
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
        child: SafeArea(
          child: Consumer<FollowService>(
            builder: (context, followService, child) {
              // Check if we need to reload data because followed counts changed
              // Simple check: compare current dynamicPopularArtists with followedArtistsList
              // In production we would use internal versioning or comparison
              return CustomScrollView(
                slivers: [
              SliverAppBar(
                backgroundColor: theme.colorScheme.surface,
                surfaceTintColor: theme.colorScheme.surface,
                scrolledUnderElevation: 4.0,
                shadowColor: Colors.black26,
                elevation: 0,
                pinned: true,
                floating: false,
                toolbarHeight: 80,
                expandedHeight: 150,
                leading: Builder(
                  builder: (context) => GestureDetector(
                    onTap: () {
                      Scaffold.of(context).openDrawer();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: StreamBuilder<UserModel?>(
                        stream: AuthService.instance.userStream,
                        initialData: AuthService.instance.currentUser,
                        builder: (context, snapshot) {
                          final user = snapshot.data;
                          final String firstLetter =
                              user != null && user.name.isNotEmpty
                              ? user.name[0].toUpperCase()
                              : 'G';
                          final String placeholderUrl =
                              'https://placehold.co/100x100/FF9D5C/ffffff.png?text=$firstLetter';

                          return CircleAvatar(
                            radius: 60,
                            backgroundImage: getAvatarImageProvider(user?.imageUrl, placeholderUrl),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    _getGreeting(),
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                  titlePadding: const EdgeInsetsDirectional.only(
                    start: 72.0,
                    bottom: 20.0,
                  ),
                  centerTitle: false,
                ),
              ),

              _buildTopGrid(context),
              ..._buildDynamicShelves(context, theme),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    ),
  ),
);
}

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
  }

  Widget _buildTopGrid(BuildContext context) {
    return SliverToBoxAdapter(
      child: Consumer2<MusicService, PlaylistService>(
        builder: (context, musicService, playlistService, _) {
          final List<_GridItem> gridItems = [];
          
          gridItems.add(_GridItem(
            "Liked Songs",
            "assets_or_placeholder",
            () => Navigator.pushNamed(context, AppRoutes.likedSongs),
          ));
          
          final seenTitles = <String>{};
          
          for (final contextItem in musicService.recentContexts) {
            if (gridItems.length >= 6) break;
            final title = contextItem['title'] ?? 'Unknown';
            if (!seenTitles.contains(title)) {
              seenTitles.add(title);
              final bool isActive = musicService.recentContexts.isNotEmpty && 
                                    musicService.recentContexts.first['title'] == title && 
                                    musicService.isPlaying;

              gridItems.add(_GridItem(
                title,
                contextItem['image'] ?? '',
                () {
                   final songListDyn = contextItem['songs'] as List?;
                   if (songListDyn != null && songListDyn.isNotEmpty) {
                      final songs = songListDyn.map((e) => SongModel.fromJson(Map<String, dynamic>.from(e))).toList();
                      if (contextItem['type'] == 'album') {
                          final virtualAlbum = AlbumModel(
                             id: contextItem['id'] ?? '',
                             name: title,
                             imageUrl: contextItem['image'] ?? '',
                             artist: 'Various Artists',
                             year: '',
                          );
                          Navigator.pushNamed(context, AppRoutes.album, arguments: virtualAlbum);
                      } else {
                          final virtualPlaylist = Playlist(
                              id: contextItem['id'] ?? '',
                              name: title,
                              songs: songs,
                          );
                          Navigator.pushNamed(context, AppRoutes.playlist, arguments: virtualPlaylist);
                      }
                   }
                },
                isActive: isActive,
              ));
            }
          }

          // Fallback to history loose songs if context is empty
          if (gridItems.length < 6) {
             final history = musicService.listeningHistory;
             for (final song in history) {
               if (gridItems.length >= 6) break;
               final key = song.album.isNotEmpty && song.album != "Unknown Album" ? song.album : song.name;
               if (!seenTitles.contains(key) && key.isNotEmpty) {
                 seenTitles.add(key);
                 final bool isActive = musicService.currentSong?.album == song.album && musicService.isPlaying;
                 gridItems.add(_GridItem(
                   key,
                   song.imageUrl,
                   () {
                      final virtualAlbum = AlbumModel(
                          id: song.albumId ?? '',
                          name: song.album,
                          imageUrl: song.imageUrl,
                          artist: song.artist,
                          year: '',
                      );
                      Navigator.pushNamed(context, AppRoutes.album, arguments: virtualAlbum);
                   },
                   isActive: isActive,
                 ));
               }
             }
          }

          // User's custom playlists could go here in the future if available.
          // Removed the generic featured playlists populator.

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: GridView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 3.0, 
              ),
              itemCount: gridItems.length,
              itemBuilder: (context, index) {
                final item = gridItems[index];
                return GestureDetector(
                  onTap: item.onTap,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            item.title == "Liked Songs"
                              ? Container(
                                  width: 56,
                                  height: 56,
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Color(0xFF450af5), Color(0xFFc4efd9)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  ),
                                  child: const Icon(Icons.favorite, color: Colors.white, size: 28),
                                )
                              : Image.network(
                                  item.imageUrl, 
                                  width: 56, 
                                  height: 56, 
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(width: 56, height: 56, color: Colors.grey[800]),
                                ),
                            if (item.isActive)
                              Positioned.fill(
                                child: Container(
                                  color: Colors.black54,
                                  child: const Center(
                                    child: Icon(Icons.equalizer, color: Color(0xFFFF6600), size: 24),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.bold, 
                              fontSize: 13,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        }
      ),
    );
  }

  List<Widget> _buildDynamicShelves(BuildContext context, ThemeData theme) {
    List<Widget> slivers = [];
    
    // 1. "More like [Last Listened Artist]" (Grouped into Albums/Playlists)
    final history = Provider.of<MusicService>(context).listeningHistory;
    String sectionTitle = "Recommended Albums";
    List<SongModel> sourceSongs = recentlyPlayed;
    
    if (history.isNotEmpty) {
      final lastArtist = history.first.artist;
      final similar = recentlyPlayed.where((s) => s.artist.contains(lastArtist) || lastArtist.contains(s.artist)).toList();
      if (similar.isNotEmpty) {
        sectionTitle = "More like $lastArtist";
        sourceSongs = similar;
      }
    }

    final Map<String, List<SongModel>> albumGroups = {};
    for (var song in sourceSongs) {
      final key = song.album.isNotEmpty && song.album != "Unknown Album" ? song.album : "Singles by ${song.artist}";
      albumGroups.putIfAbsent(key, () => []).add(song);
    }
    
    final List<Map<String, dynamic>> recommendedAlbums = [];
    for (var entry in albumGroups.entries) {
      if (recommendedAlbums.length >= 8) break;
      final id = 'album_${entry.key.replaceAll(' ', '_')}';
      playlistSongsData[id] = entry.value; 
      recommendedAlbums.add({
        'id': id,
        'title': entry.key,
        'image': entry.value.first.imageUrl,
        'songCount': entry.value.length.toString(),
      });
    }

    if (recommendedAlbums.isNotEmpty) {
      slivers.add(SliverToBoxAdapter(child: _buildSectionHeader(sectionTitle)));
      slivers.add(
        SliverToBoxAdapter(
          child: SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: recommendedAlbums.length,
              itemBuilder: (context, index) => _buildPlaylistCard(recommendedAlbums[index]),
            ),
          ),
        ),
      );
    }

    // 2. Popular Artists
    if (dynamicPopularArtists.isNotEmpty) {
      slivers.add(SliverToBoxAdapter(child: _buildSectionHeader("Your Favorite Artists")));
      slivers.add(
        SliverToBoxAdapter(
          child: SizedBox(
            height: 140, // Height for avatar + text
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: dynamicPopularArtists.length,
              itemBuilder: (context, index) {
                final artist = dynamicPopularArtists[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(context, AppRoutes.artist, arguments: artist);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 16),
                    width: 100,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundImage: NetworkImage(artist["image"] ?? ''),
                          backgroundColor: Colors.grey[800],
                          onBackgroundImageError: (e, s) =>
                              const Icon(Icons.person, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          artist["name"] ?? 'Unknown',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

    // 3. Playlists / Daily Mixes
    if (dynamicFeaturedPlaylists.isNotEmpty) {
      slivers.add(SliverToBoxAdapter(child: _buildSectionHeader("Made For You")));
      slivers.add(
        SliverToBoxAdapter(
          child: SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: dynamicFeaturedPlaylists.length,
              itemBuilder: (context, index) => _buildPlaylistCard(dynamicFeaturedPlaylists[index]),
            ),
          ),
        ),
      );
    }

    return slivers;
  }

  Widget _buildSectionHeader(
    String title, {
    VoidCallback? onSeeAll,
    bool showSeeAll = false, // defaults to false for now
    String seeAllText = "See All",
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (showSeeAll)
            TextButton(
              onPressed: onSeeAll,
              child: Text(
                seeAllText,
                style: const TextStyle(color: Color(0xFFFF781F)),
              ),
            ),
        ],
      ),
    );
  }



  Widget _buildPlaylistCard(
    Map<String, dynamic> playlist, {
    bool useMargin = true,
  }) {
    final theme = Theme.of(context);
    final musicService = Provider.of<MusicService>(context);
    final bool isActive = musicService.recentContexts.isNotEmpty &&
                          musicService.recentContexts.first['id'] == playlist['id'] &&
                          musicService.isPlaying;

    return GestureDetector(
      onTap: () {
        final songs = playlistSongsData[playlist['id']];
        if (songs != null && songs.isNotEmpty) {
           final virtualPlaylist = Playlist(
               id: playlist['id'] ?? '',
               name: playlist['title'] ?? 'Unknown',
               songs: songs,
           );
           Navigator.pushNamed(context, AppRoutes.playlist, arguments: virtualPlaylist);
        } else {
           showMusicToast(context, "No songs in this playlist", type: ToastType.info);
        }
      },
      child: Container(
        width: 160,
        margin: useMargin ? const EdgeInsets.only(right: 16) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    playlist["image"]!,
                    height: 120,
                    width: 160,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        Container(height: 120, width: 160, color: Colors.grey),
                  ),
                ),
                if (isActive)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF6600),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.equalizer, color: Colors.white, size: 16),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              playlist["title"]!,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              "${playlist["songCount"]} songs",
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Reused drawer code, keeping it minimally changed
  Widget _buildAppDrawer() {
    final theme = Theme.of(context);
    final uiStateService = Provider.of<UiStateService>(context, listen: false);

    final Color drawerBackgroundColor = theme.brightness == Brightness.light
        ? const Color(0xFFF1F4F8)
        : const Color(0xFF1E1E1E);
    final Color textColor = theme.colorScheme.onSurface;
    final Color iconColor = theme.unselectedWidgetColor;
    final Color selectedColor = const Color(0xFFFF6600);
    final Color selectedTileColor = const Color(0xFFFF6600).withOpacity(0.1);

    return Drawer(
      backgroundColor: drawerBackgroundColor,
      child: Column(
        children: [
          StreamBuilder<UserModel?>(
            stream: AuthService.instance.userStream,
            initialData: AuthService.instance.currentUser,
            builder: (context, snapshot) {
              final user = snapshot.data;
              final String name = user?.name ?? 'Guest User';
              final String email = user?.email ?? 'Sign in to sync data';
              final String firstLetter = name.isNotEmpty
                  ? name[0].toUpperCase()
                  : 'G';
              final String placeholderUrl =
                  'https://placehold.co/100x100/FF9D5C/ffffff.png?text=$firstLetter';
              return UserAccountsDrawerHeader(
                accountName: Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
                accountEmail: Text(
                  email,
                  style: const TextStyle(color: Colors.white70),
                ),
                currentAccountPicture: GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    if (user != null) {
                      Navigator.pushNamed(context, AppRoutes.profile);
                    } else {
                      Navigator.pushNamed(context, AppRoutes.login);
                    }
                  },
                  child: CircleAvatar(
                    backgroundColor: Colors.white,
                    backgroundImage: getAvatarImageProvider(user?.imageUrl, placeholderUrl),
                  ),
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF6600), Color(0xFFFF9D5C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              );
            },
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  icon: Icons.person_rounded,
                  text: 'Profile',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.profile);
                  },
                  selectedColor: selectedColor,
                  iconColor: iconColor,
                  textColor: textColor,
                  selectedTileColor: selectedTileColor,
                ),
                _buildDrawerItem(
                  icon: Icons.favorite_rounded,
                  text: 'Liked Songs',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.likedSongs);
                  },
                  selectedColor: selectedColor,
                  iconColor: iconColor,
                  textColor: textColor,
                  selectedTileColor: selectedTileColor,
                ),
                _buildDrawerItem(
                  icon: Icons.playlist_add_rounded,
                  text: 'Import Spotify Playlist',
                  onTap: () {
                    Navigator.pop(context); // Close drawer
                    _showSpotifyImportSheet(context);
                  },
                  selectedColor: const Color(0xFF1DB954), // Spotify Green
                  iconColor: const Color(0xFF1DB954),
                  textColor: textColor,
                  selectedTileColor: const Color(0xFF1DB954).withValues(alpha: 0.1),
                ),
                const Divider(),
                _buildDrawerItem(
                  icon: Icons.settings_rounded,
                  text: 'Settings',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.settings);
                  },
                  selectedColor: selectedColor,
                  iconColor: iconColor,
                  textColor: textColor,
                  selectedTileColor: selectedTileColor,
                ),
                _buildDrawerItem(
                  icon: Icons.info_outline_rounded,
                  text: 'About',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.about);
                  },
                  selectedColor: selectedColor,
                  iconColor: iconColor,
                  textColor: textColor,
                  selectedTileColor: selectedTileColor,
                ),
                _buildDrawerItem(
                  icon: Icons.share_rounded,
                  text: 'Invite Friends',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.inviteFriends);
                  },
                  selectedColor: selectedColor,
                  iconColor: iconColor,
                  textColor: textColor,
                  selectedTileColor: selectedTileColor,
                ),
                const Divider(),
                _buildDrawerItem(
                  icon: Icons.logout_rounded,
                  text: 'Sign Out',
                  onTap: () async {
                    Navigator.pop(context); // Close drawer first
                    uiStateService.hideMiniPlayer();
                    await _showImprovedLogoutDialog();
                    uiStateService.showMiniPlayer();
                  },
                  selectedColor: selectedColor,
                  iconColor: Colors.red, // Make logout red
                  textColor: Colors.red,
                  selectedTileColor: selectedTileColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    bool isSelected = false,
    required Color selectedColor,
    required Color iconColor,
    required Color textColor,
    required Color selectedTileColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? selectedTileColor : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(icon, color: isSelected ? selectedColor : iconColor),
        title: Text(text, style: TextStyle(color: textColor)),
        onTap: onTap,
      ),
    );
  }
}

class _GridItem {
  final String title;
  final String imageUrl;
  final VoidCallback onTap;
  final bool isActive;
  _GridItem(this.title, this.imageUrl, this.onTap, {this.isActive = false});
}

