// home_screen.dart
// ignore_for_file: prefer_final_fields, deprecated_member_use, use_build_context_synchronously

import 'package:clone_mp/services/api_service.dart';
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
import 'package:clone_mp/services/download_service.dart';
import 'package:clone_mp/widgets/music_toast.dart';
import 'dart:math';

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

  List<SongModel> recentlyPlayed = [];
  List<SongModel> topCharts = [];

  // Static playlists for UI demo (can be APIified later)
  final List<Map<String, String>> featuredPlaylists = [
    {
      "title": "Today's Top Hits",
      "subtitle": "The biggest songs right now",
      "image": "https://i.ibb.co/B2kSS9B1/download-4.jpg",
      "songCount": "50",
    },
    {
      "title": "Sem Bihari",
      "subtitle": "New music from hip-hop",
      "image":
          "https://i.ibb.co/TDx4fd0B/Whats-App-Image-2025-09-02-at-10-25-07-PM.jpg",
      "songCount": "65",
    },
  ];

  bool showAllTopCharts = false;

  final List<Map<String, String>> popularArtists = [
    {"name": "Seedhe Maut", "image": "https://tse2.mm.bing.net/th?q=Seedhe+Maut+Rapper&w=500&h=500&c=7"},
    {"name": "Arijit Singh", "image": "https://tse2.mm.bing.net/th?q=Arijit+Singh+Singer&w=500&h=500&c=7"},
    {"name": "Drake", "image": "https://tse2.mm.bing.net/th?q=Drake+Rapper&w=500&h=500&c=7"},
    {"name": "Dua Lipa", "image": "https://tse2.mm.bing.net/th?q=Dua+Lipa&w=500&h=500&c=7"},
    {"name": "Billie Eilish", "image": "https://tse2.mm.bing.net/th?q=Billie+Eilish&w=500&h=500&c=7"},
    {"name": "Raftaar", "image": "https://tse2.mm.bing.net/th?q=Raftaar+Rapper&w=500&h=500&c=7"},
    {"name": "Karma", "image": "https://tse2.mm.bing.net/th?q=Karma+Rapper&w=500&h=500&c=7"},
    {"name": "Afkap", "image": "https://tse2.mm.bing.net/th?q=Afkap+Rapper&w=500&h=500&c=7"},
    {"name": "OG Lucifer", "image": "https://tse2.mm.bing.net/th?q=OG+Lucifer+Rapper&w=500&h=500&c=7"},
  ];

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
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final api = ApiService();
      final currentUser = AuthService.instance.currentUser;
      
      String recentQuery = "new hindi songs";
      String chartsQuery = "Desi Hip Hop Hits";

      if (currentUser != null) {
        final personalizationService = Provider.of<PersonalizationService>(context, listen: false);
        final followService = Provider.of<FollowService>(context, listen: false);
        
        final prefs = await personalizationService.getPersonalizationData(currentUser.email);
        final followedArtists = followService.followedArtistIds;

        List<String> userGenres = [];
        List<String> userArtists = [];

        if (prefs != null) {
          userGenres = List<String>.from(prefs['genres'] ?? []);
          userArtists = List<String>.from(prefs['artists'] ?? []);
        }

        // Combine onboarded artists with followed artists for a richer pool
        final allArtists = <String>{...userArtists, ...followedArtists}.toList();

        // Use today's date as a seed to ensure daily freshness
        final now = DateTime.now();
        final int todaySeed = now.year * 1000 + now.month * 100 + now.day;
        final random = Random(todaySeed);

        if (allArtists.isNotEmpty) {
          // Pick a random artist for recently played/trending
          recentQuery = allArtists[random.nextInt(allArtists.length)];
        } else if (userGenres.isNotEmpty) {
          recentQuery = userGenres[random.nextInt(userGenres.length)];
        }

        if (userGenres.isNotEmpty) {
          // Pick a random genre for top charts
          chartsQuery = "${userGenres[random.nextInt(userGenres.length)]} hits";
        } else if (allArtists.isNotEmpty) {
          chartsQuery = "${allArtists[random.nextInt(allArtists.length)]} hits";
        }
      }

      final recent = await api.searchSongs(recentQuery);
      final charts = await api.searchSongs(chartsQuery);

      if (mounted) {
        setState(() {
          // Shuffle results slightly using the daily seed to feel less static 
          // while keeping it consistent throughout the day
          final now = DateTime.now();
          final int todaySeed = now.year * 1000 + now.month * 100 + now.day;
          final currentRandom = Random(todaySeed);
          recent.shuffle(currentRandom);
          charts.shuffle(currentRandom);
          
          recentlyPlayed = recent;
          topCharts = charts;
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
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
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
                          color: theme.colorScheme.onSurface.withOpacity(0.3),
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

  void _showMoreMenu(BuildContext context, SongModel song) {
    final uiStateService = Provider.of<UiStateService>(context, listen: false);
    final musicService = Provider.of<MusicService>(context, listen: false);
    
    uiStateService.setModalActive(true);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Consumer<DownloadService>(
          builder: (context, downloadService, child) {
            final isDownloaded = downloadService.isSongDownloaded(song.id);
            final isDownloading = downloadService.isDownloading(song.id);
            
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        song.imageUrl,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      ),
                    ),
                    title: Text(song.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(song.artist),
                  ),
                  const Divider(),
                  ListTile(
                    leading: Icon(
                      isDownloaded ? Icons.download_done_rounded : Icons.download_rounded, 
                      color: isDownloaded ? Colors.green : const Color(0xFFFF6600)
                    ),
                    title: Text(isDownloading ? "Downloading..." : (isDownloaded ? "Delete Download" : "Download")),
                    onTap: () async {
                      if (isDownloading) return;
                      
                      if (isDownloaded) {
                        Navigator.pop(context);
                        _confirmDelete(context, song, downloadService);
                      } else {
                        Navigator.pop(context);
                        showMusicToast(context, 'Downloading "${song.name}"...', type: ToastType.info);
                        await downloadService.downloadSong(song);
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.playlist_add_rounded, color: Color(0xFFFF6600)),
                    title: const Text("Add to Queue"),
                    onTap: () {
                      musicService.addToQueue(song);
                      Navigator.pop(context);
                      showMusicToast(context, "Added to queue", type: ToastType.success);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded, color: Color(0xFFFF6600)),
                    title: const Text("Song Details"),
                    onTap: () {
                      Navigator.pop(context);
                      _showSongDetails(context, song);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) => uiStateService.setModalActive(false));
  }

  void _confirmDelete(BuildContext context, SongModel song, DownloadService downloadService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Download'),
        content: Text('Are you sure you want to delete "${song.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await downloadService.deleteSong(song.id);
              if (context.mounted) {
                showMusicToast(context, success ? 'Deleted' : 'Failed to delete', type: success ? ToastType.info : ToastType.error);
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showSongDetails(BuildContext context, SongModel song) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Song Details"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Title: ${song.name}"),
            const SizedBox(height: 8),
            Text("Artist: ${song.artist}"),
            const SizedBox(height: 8),
            Text("Album: ${song.album}"),
            if (song.duration != null) ...[
              const SizedBox(height: 8),
              Text("Duration: ${_formatDuration(song.duration)}"),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
        ],
      ),
    );
  }

  String _formatDuration(String? dur) {
    if (dur == null || dur.isEmpty) return "";
    final totalSec = int.tryParse(dur) ?? 0;
    if (totalSec == 0) return "";
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return "$m:${s.toString().padLeft(2, '0')}";
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
          child: CustomScrollView(
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

              SliverToBoxAdapter(
                child: Container(
                  height: 50,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: genres.length,
                    itemBuilder: (context, index) {
                      final genre = genres[index];
                      final isSelected = selectedFilter == genre;
                      return Container(
                        margin: const EdgeInsets.only(right: 12),
                        child: FilterChip(
                          label: Text(genre),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              selectedFilter = genre;
                              // In a real app we would refetch based on genre
                              // _loadData(genre);
                            });
                          },
                          selectedColor: const Color(0xFFFF6600),
                          backgroundColor: theme.colorScheme.surface
                              .withOpacity(0.5),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : theme.colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                          side: BorderSide.none,
                          showCheckmark: false,
                        ),
                      );
                    },
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: _buildSectionHeader("Recently Added / Trending"),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: recentlyPlayed.length,
                    itemBuilder: (context, index) {
                      final song = recentlyPlayed[index];
                      return _buildSongCard(song);
                    },
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: _buildSectionHeader(
                  "Top Charts",
                  showSeeAll: true,
                  seeAllText: showAllTopCharts ? "Show Less" : "See More",
                  onSeeAll: () {
                    setState(() {
                      showAllTopCharts = !showAllTopCharts;
                    });
                  },
                ),
              ),
              topCharts.isEmpty
                  ? SliverToBoxAdapter(
                      child: Container(
                        height: 100,
                        alignment: Alignment.center,
                        child: Text(
                          'Loading songs...',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                            fontSize: 16,
                          ),
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final song = topCharts[index];
                        return _buildSongListTile(context, song, topCharts, theme, index + 1);
                      },
                      childCount: showAllTopCharts
                          ? topCharts.length
                          : (topCharts.length > 5 ? 5 : topCharts.length),
                      ),
                    ),

              // --- Popular Artists Section ---
              SliverToBoxAdapter(
                child: _buildSectionHeader("Your Favorite Artists"),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 140, // Height for avatar + text
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: popularArtists.length,
                    itemBuilder: (context, index) {
                      final artist = popularArtists[index];
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
                                backgroundImage: NetworkImage(artist["image"]!),
                                backgroundColor: Colors.grey[800],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                artist["name"]!,
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

              SliverToBoxAdapter(
                child: _buildSectionHeader("Featured Playlists"),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: featuredPlaylists.length,
                    itemBuilder: (context, index) {
                      final playlist = featuredPlaylists[index];
                      return _buildPlaylistCard(playlist);
                    },
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
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
          Text(
            title,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.bold,
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

  Widget _buildSongCard(SongModel song) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        final index = recentlyPlayed.indexOf(song);
        widget.onPlaySong(song, recentlyPlayed, index);
      },
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    song.imageUrl,
                    height: 120,
                    width: 150,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 120,
                        width: 150,
                        color: Colors.grey[800],
                        child: Icon(
                          Icons.music_note,
                          color: theme.colorScheme.onSurface,
                        ),
                      );
                    },
                  ),
                ),
                Consumer<MusicService>(
                  builder: (context, musicService, child) {
                    final bool isThisSongPlaying = musicService.currentSong?.id == song.id && musicService.isPlaying;
                    return isThisSongPlaying
                        ? Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF6600),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.pause,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          )
                        : const SizedBox.shrink();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              song.name,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              song.artist,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSongListTile(BuildContext context, SongModel song, List<SongModel> playlist, ThemeData theme, int rank) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            song.imageUrl,
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                Container(width: 50, height: 50, color: Colors.grey),
          ),
        ),
        title: Consumer<MusicService>(
          builder: (context, musicService, _) {
            final bool isActive = musicService.isActive(song.id);
            return Text(
              song.name,
              style: TextStyle(
                color: isActive
                    ? const Color(0xFFFF6600)
                    : theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
        subtitle: Text(
          song.artist,
          style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Consumer<PlaylistService>(
              builder: (context, playlistService, _) {
                if (playlistService.isLiked(song)) {
                  return const Padding(
                    padding: EdgeInsets.only(right: 8.0),
                    child: Icon(Icons.favorite, color: Color(0xFFFF6600), size: 22),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            IconButton(
              icon: Icon(Icons.more_vert, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              onPressed: () => _showMoreMenu(context, song),
            ),
          ],
        ),
        onTap: () {
          final index = topCharts.indexOf(song);
          widget.onPlaySong(song, topCharts, index);
        },
      ),
    );
  }

  Widget _buildPlaylistCard(
    Map<String, String> playlist, {
    bool useMargin = true,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Opening ${playlist["title"]}")));
      },
      child: Container(
        width: 160,
        margin: useMargin ? const EdgeInsets.only(right: 16) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                color: theme.colorScheme.onSurface.withOpacity(0.7),
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
