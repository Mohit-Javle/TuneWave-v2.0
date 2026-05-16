import 'dart:io';

void main() {
  final files = Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart') && !f.path.contains('search_screen.dart')).toList();

  for (final file in files) {
    String content = file.readAsStringSync();
    if (!content.contains('Image.network(') && !content.contains('NetworkImage(')) continue;

    bool modified = false;

    // 1. NetworkImage(...)
    final networkImageRegex = RegExp(r'NetworkImage\s*\(\s*([^,\)]+)\s*\)');
    content = content.replaceAllMapped(networkImageRegex, (match) {
      final x = match.group(1)!.trim();
      if (x.contains('!= null') || x.contains('isNotEmpty')) return match.group(0)!;
      modified = true;
      return '($x != null && $x.isNotEmpty) ? NetworkImage($x) : null';
    });

    // 2. Image.network(...)
    int startIndex = 0;
    while (true) {
      final index = content.indexOf('Image.network(', startIndex);
      if (index == -1) break;

      // Ensure it's not already prefixed with a null check
      int prefixIndex = content.lastIndexOf('?', index);
      int newlineIndex = content.lastIndexOf('\n', index);
      if (prefixIndex > newlineIndex) {
         // Might be already checked
         startIndex = index + 14;
         continue;
      }

      int openParens = 1;
      int endIndex = index + 14;
      while (endIndex < content.length && openParens > 0) {
        if (content[endIndex] == '(') openParens++;
        else if (content[endIndex] == ')') openParens--;
        endIndex++;
      }

      // Extract the first argument X
      final match = RegExp(r'Image\.network\(\s*([^,\)]+)').firstMatch(content.substring(index, endIndex));
      if (match != null) {
        final x = match.group(1)!.trim();
        if (x.contains('!= null') || x.contains('isNotEmpty')) {
            startIndex = endIndex;
            continue;
        }
        final block = content.substring(index, endIndex);
        final replacement = '($x != null && $x.isNotEmpty) ? $block : const Icon(Icons.person)';
        content = content.replaceRange(index, endIndex, replacement);
        startIndex = index + replacement.length;
        modified = true;
      } else {
        startIndex = endIndex;
      }
    }

    if (modified) {
      file.writeAsStringSync(content);
      print('Fixed ${file.path}');
    }
  }
}
