import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')).toList();

  for (final file in files) {
    if (file.path.contains('search_screen.dart')) continue; // Already manually fixed

    String content = file.readAsStringSync();
    String originalContent = content;

    // Pattern 1: Image.network(X, ... or Image.network(X)
    // We match Image.network(X
    // X can be things like `album.imageUrl`, `artist['image']!`, etc.
    final imageNetworkRegex = RegExp(r'Image\.network\(\s*([^,\)]+)');
    content = content.replaceAllMapped(imageNetworkRegex, (match) {
      final x = match.group(1)!.trim();
      if (x.contains("!= null")) return match.group(0)!; // Already checked
      return '($x != null && $x.isNotEmpty) ? Image.network($x';
    });

    // To handle the errorBuilder replacement:
    // We actually need to close the ternary operator. 
    // This regex approach for Image.network is tricky because we have to insert `: const Icon(Icons.person)` AFTER the closing `)`.
    // Let's use a simple approach: just match the entire Image.network(...) block if possible, but that's hard.
  }
}
