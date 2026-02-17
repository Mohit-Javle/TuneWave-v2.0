// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dart_des/dart_des.dart';

void main() async {
  final query = "Arijit Singh";
  final String proxyBaseUrl = "http://localhost:8082";
  
  // 1. SEARCH via Proxy
  print("1. Searching via Proxy...");
  final searchUrl = Uri.parse('$proxyBaseUrl/api.php?__call=search.getResults&p=1&q=$query&_format=json&_marker=0&api_version=4&ctx=web6dot0');
  
  try {
    final searchRes = await http.get(searchUrl);
    if (searchRes.statusCode != 200) {
      print("FAIL: Search failed with status ${searchRes.statusCode}");
      return;
    }
    
    final data = json.decode(searchRes.body);
    final results = data['results'] as List;
    if (results.isEmpty) {
      print("FAIL: No results found.");
      return;
    }
    
    print("MATCH: Found ${results.length} results.");
    final firstSong = results[0];
    final encryptedUrl = firstSong['more_info']['encrypted_media_url'];
    print("Song: ${firstSong['title']}");
    
    // 2. DECRYPT
    print("2. Decrypting URL...");
    String decryptedUrl = "";
    try {
      String key = "38346591";
      DES desECB = DES(key: key.codeUnits, mode: DESMode.ECB, paddingType: DESPaddingType.PKCS7);
      final encryptedBytes = base64.decode(encryptedUrl);
      final decryptedBytes = desECB.decrypt(encryptedBytes);
      decryptedUrl = utf8.decode(decryptedBytes);
    } catch (e) {
      print("FAIL: Decryption error: $e");
      return;
    }
    print("Decrypted URL: $decryptedUrl");
    
    // 3. STREAM via Proxy
    print("3. Requesting Stream via Proxy...");
    final encodedUrl = Uri.encodeComponent(decryptedUrl);
    final streamUrl = Uri.parse('$proxyBaseUrl/stream?url=$encodedUrl');
    print("Stream Proxy URL: $streamUrl");
    
    final client = http.Client();
    final request = http.Request('GET', streamUrl);
    // Simulate Browser Headers
    request.headers['Range'] = 'bytes=0-100'; // Request first 100 bytes to test basic connectivity
    
    final streamRes = await client.send(request);
    
    print("Response Status: ${streamRes.statusCode}");
    print("ContentType: ${streamRes.headers['content-type']}");
    print("ContentRange: ${streamRes.headers['content-range']}");
    
    if (streamRes.statusCode == 200 || streamRes.statusCode == 206) {
      print("SUCCESS: Audio stream is accessible via proxy!");
    } else {
      print("FAIL: Proxy returned error.");
      final body = await streamRes.stream.bytesToString();
      print("Body: $body");
    }
    
  } catch (e) {
    print("CRITICAL ERROR: $e");
  }
}
