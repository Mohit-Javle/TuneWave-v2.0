import 'package:flutter/material.dart';

class ArtistScreen extends StatelessWidget {
  final dynamic artist; 
  const ArtistScreen({super.key, required this.artist});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Artist Profile")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.person, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text("Artist details are under construction."),
          ],
        ),
      ),
    );
  }
}
