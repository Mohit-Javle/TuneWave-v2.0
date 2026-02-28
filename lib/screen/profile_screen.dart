// lib/screen/profile_screen.dart
// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'package:clone_mp/widgets/avatar_image_provider.dart';
import 'package:clone_mp/widgets/music_toast.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:clone_mp/services/auth_service.dart';
import 'package:clone_mp/models/user_model.dart';
import 'package:provider/provider.dart';
import 'package:clone_mp/services/playlist_service.dart';
import 'package:clone_mp/services/follow_service.dart';
import 'package:clone_mp/screen/listening_history_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color primaryOrange = Color(0xFFFF6600);
  final TextEditingController _nameController = TextEditingController();

  // ✨ FIX: Added missing commas to the list of image URLs
  final List<String> avatarImages = [
    "https://i.pinimg.com/564x/bf/de/bf/bfdebf22776f6d49e480288dd2100388.jpg",
    "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTLNrG7Hjwm56E3LfKdPXewt0OMVOK-K3fN1jYRspIUDlKT-U4f7mKB6E3ysN91gVOy0ws&usqp=CAU",
    "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTpXthi8obr761HuSzpELjr7qAFiH_C1eswR-xMLsU4wAupA_5Bc8jOSSN4ubWaImqym_k&usqp=CAU",
    "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQwA-3vvOzQ4-u_7cWo8TLa2I6x26ooKSyZ05BmmJN6bXhCAlF1Bhg8dFpPkmKNnH2HOUU&usqp=CAU",
    'https://placehold.co/200x200/FF5733/ffffff.png?text=A',
    'https://placehold.co/200x200/33FF57/ffffff.png?text=B',
    'https://placehold.co/200x200/3357FF/ffffff.png?text=C',
    'https://placehold.co/200x200/FF33A1/ffffff.png?text=D',
    'https://placehold.co/200x200/A133FF/ffffff.png?text=E',
    'https://placehold.co/200x200/33FFF3/ffffff.png?text=F',
    'https://placehold.co/200x200/F3FF33/ffffff.png?text=G',
    'https://placehold.co/200x200/FF8C33/ffffff.png?text=H',
    'https://placehold.co/200x200/8C33FF/ffffff.png?text=I',
    'https://placehold.co/200x200/33FF8C/ffffff.png?text=J',
    'https://placehold.co/200x200/FF3333/ffffff.png?text=K',
    'https://placehold.co/200x200/33A1FF/ffffff.png?text=L',
    'https://placehold.co/200x200/A1FF33/ffffff.png?text=M',
    'https://placehold.co/200x200/E67E22/ffffff.png?text=N',
    'https://placehold.co/200x200/2ECC71/ffffff.png?text=O',
    'https://placehold.co/200x200/9B59B6/ffffff.png?text=P',
    'https://placehold.co/200x200/F1C40F/ffffff.png?text=Q',
    'https://placehold.co/200x200/3498DB/ffffff.png?text=R',
    'https://placehold.co/200x200/E74C3C/ffffff.png?text=S',
    'https://placehold.co/200x200/1ABC9C/ffffff.png?text=T',
    'https://placehold.co/200x200/27AE60/ffffff.png?text=U',
    'https://placehold.co/200x200/8E44AD/ffffff.png?text=V',
    'https://placehold.co/200x200/F39C12/ffffff.png?text=W',
    'https://placehold.co/200x200/2980B9/ffffff.png?text=X',
    'https://placehold.co/200x200/C0392B/ffffff.png?text=Y',
    'https://placehold.co/200x200/16A085/ffffff.png?text=Z',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _showEditNameSheet(BuildContext context, UserModel currentUser) {
    final theme = Theme.of(context);
    _nameController.text = currentUser.name;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Change Name',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              style: TextStyle(color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Name',
                labelStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryOrange),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
              onPressed: () {
                AuthService.instance.updateUserProfile(
                  newName: _nameController.text,
                );
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  final ImagePicker _picker = ImagePicker();
  bool _isUploadingImage = false;

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 256,   // Reduced from 512
        maxHeight: 256,  // Reduced from 512 
        imageQuality: 50, // Reduced from 75 to keep Base64 safely under 1MB Firestore limit
      );

      if (pickedFile == null) return;
      
      setState(() {
        _isUploadingImage = true;
      });

      final bytes = await pickedFile.readAsBytes();
      if (bytes.isEmpty) throw Exception("Selected image file is empty.");

      final email = AuthService.instance.currentUser?.email;
      if (email == null) throw Exception("User missing email context");

      // Generate a base64 string and save it directly to Firestore to bypass broken Firebase Storage
      final String base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      
      await AuthService.instance.updateUserProfile(
        newName: AuthService.instance.currentUser!.name,
        newImageUrl: base64Image,
      );

      if (mounted) {
        showMusicToast(context, "Profile picture updated successfully!", type: ToastType.success);
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        showMusicToast(context, "Firestore Error: ${e.code} - ${e.message}", type: ToastType.error);
      }
    } catch (e) {
      if (mounted) {
        showMusicToast(context, "Failed to update profile picture: $e", type: ToastType.error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  void _showImageSelectionSheet(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_camera, color: theme.colorScheme.primary),
              title: Text('Take a photo', style: TextStyle(color: theme.colorScheme.onSurface)),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: theme.colorScheme.primary),
              title: Text('Choose from gallery', style: TextStyle(color: theme.colorScheme.onSurface)),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditOptions(BuildContext context, UserModel user) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.person_outline, color: theme.colorScheme.primary),
              title: Text('Edit Name', style: TextStyle(color: theme.colorScheme.onSurface)),
              onTap: () {
                Navigator.pop(context);
                _showEditNameSheet(context, user);
              },
            ),
            ListTile(
              leading: Icon(Icons.image_outlined, color: theme.colorScheme.primary),
              title: Text('Change Profile Picture', style: TextStyle(color: theme.colorScheme.onSurface)),
              onTap: () {
                Navigator.pop(context);
                _showImageSelectionSheet(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textDark = theme.colorScheme.onSurface;
    final textLight = theme.colorScheme.onSurface.withOpacity(0.7);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Profile',
          style: TextStyle(color: textDark, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: textDark),
      ),
      body: StreamBuilder<UserModel?>(
        stream: AuthService.instance.userStream,
        initialData: AuthService.instance.currentUser,
        builder: (context, snapshot) {
          final user = snapshot.data;
          if (user == null) {
            return const Center(child: Text('No user logged in.'));
          }

          final String firstLetter = user.name.isNotEmpty
              ? user.name[0].toUpperCase()
              : '?';
          final String placeholderUrl =
              'https://placehold.co/200x200/FF9D5C/ffffff.png?text=$firstLetter';

          return Container(
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
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 20.0,
                ),
                children: [
                  const SizedBox(height: 20),
                  Center(
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 500),
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: child,
                            );
                          },
                          child: CircleAvatar(
                            key: ValueKey(user.imageUrl),
                            radius: 60,
                            backgroundImage: getAvatarImageProvider(user.imageUrl, placeholderUrl),
                            child: _isUploadingImage 
                                ? Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black45,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(color: primaryOrange),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _showEditOptions(context, user),
                          child: Container(
                            padding: const EdgeInsets.all(6.0),
                            decoration: const BoxDecoration(
                              color: primaryOrange,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      user.name,
                      style: TextStyle(
                        color: textDark,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      user.email,
                      style: TextStyle(color: textLight, fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Divider(),
                  const SizedBox(height: 10),
                  const SizedBox(height: 10),
                  Consumer<PlaylistService>(
                    builder: (context, playlistService, child) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatColumn(
                            'Playlists',
                            playlistService.playlists.length.toString(),
                          ),
                          _buildStatColumn(
                            'Liked Songs',
                            playlistService.likedSongs.length.toString(),
                          ),
                          Consumer<FollowService>(
                            builder: (context, followService, child) {
                              return _buildStatColumn(
                                'Following',
                                followService.followingCount.toString(),
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 20),
                  ListTile(
                    leading: Icon(Icons.music_note_outlined, color: textLight),
                    title: Text(
                      'My Playlists',
                      style: TextStyle(color: textDark),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: textLight,
                    ),
                    onTap: () {},
                  ),
                  ListTile(
                    leading: Icon(Icons.bar_chart_outlined, color: textLight),
                    title: Text(
                      'Listening Activity',
                      style: TextStyle(color: textDark),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: textLight,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ListeningHistoryScreen()),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.person_add_alt_1_outlined,
                      color: textLight,
                    ),
                    title: Text(
                      'Find Friends',
                      style: TextStyle(color: textDark),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: textLight,
                    ),
                    onTap: () {},
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }



  Column _buildStatColumn(String title, String count) {
    final theme = Theme.of(context);
    final textDark = theme.colorScheme.onSurface;
    final textLight = theme.colorScheme.onSurface.withOpacity(0.7);

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          count,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: textDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(title, style: TextStyle(fontSize: 15, color: textLight)),
      ],
    );
  }
}
