// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:dart_des/dart_des.dart';

void main() async {
  final query = "Arijit Singh";
  final String baseUrl = "https://www.jiosaavn.com/api.php";
  
  String decryptUrl(String encryptedUrl) {
    try {
      String key = "38346591";
      DES desECB = DES(key: key.codeUnits, mode: DESMode.ECB, paddingType: DESPaddingType.PKCS7);
      final encryptedBytes = base64.decode(encryptedUrl);
      final decryptedBytes = desECB.decrypt(encryptedBytes);
      return utf8.decode(decryptedBytes);
    } catch (e) {
      return "";
    }
  }

  try {
      final uri = Uri.parse(
          '$baseUrl?__call=search.getResults&p=1&q=$query&_format=json&_marker=0&api_version=4&ctx=web6dot0');

      final response = await http.get(uri, headers: {
        "User-Agent": "Mozilla/5.0"
      });
      
      if (response.statusCode == 200) {
         final data = json.decode(response.body);
         if (data['results'] != null) {
            final List results = data['results'];
            if (results.isNotEmpty) {
               final item = results[0];
               final encrypted = item['more_info']['encrypted_media_url'];
               final decrypted = decryptUrl(encrypted);
               await File('temp_url.txt').writeAsString(decrypted);
               print("Saved to temp_url.txt");
            }
         }
      }
  } catch (e) {
    print("Error: $e");
  }
}
