// ignore_for_file: avoid_print

import 'package:http/http.dart' as http;

void main() async {
  final streamUrl = "http://localhost:8082/stream?url=https://aac.saavncdn.com/example.mp3";
  print("Hitting: $streamUrl");
  try {
    final response = await http.get(Uri.parse(streamUrl));
    print("Response: ${response.statusCode}");
  } catch (e) {
    print("Error: $e");
  }
}
