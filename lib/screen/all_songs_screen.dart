import 'package:flutter/material.dart';

class AllSongsScreen extends StatelessWidget {
  const AllSongsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("All Songs")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.album, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text("All Songs library is under construction."),
          ],
        ),
      ),
    );
  }
}
