// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dart_des/dart_des.dart';

void main() async {
  final String baseUrl = "https://www.jiosaavn.com/api.php";
  final String query = "Arijit";

  print("Searching for $query...");
  
  try {
      final uri = Uri.parse(
          '$baseUrl?__call=search.getResults&p=1&q=$query&_format=json&_marker=0&api_version=4&ctx=web6dot0');

      final response = await http.get(uri, headers: {
        "User-Agent":
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
      });
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] != null) {
           final firstItem = data['results'][0];
           
           String encryptedUrl = firstItem['more_info']['encrypted_media_url'];
           
           if (encryptedUrl.isNotEmpty) {
              String decrypted = decryptUrl(encryptedUrl);
              print("Decrypted URL: $decrypted");
              if (decrypted.startsWith("http")) {
                 print("SUCCESS");
              } else {
                 print("FAILURE: Invalid URL.");
              }
           }
        }
      }
  } catch (e) {
    print("Error: $e");
  }
}

String decryptUrl(String encryptedUrl) {
    try {
      String key = "38346591";
      DES desECB = DES(key: key.codeUnits, mode: DESMode.ECB, paddingType: DESPaddingType.PKCS7);
      
      final encryptedBytes = base64.decode(encryptedUrl);
      final decryptedBytes = desECB.decrypt(encryptedBytes);
      
      return utf8.decode(decryptedBytes);
    } catch (e) {
      print("Decryption Error: $e");
      return "";
    }
}
