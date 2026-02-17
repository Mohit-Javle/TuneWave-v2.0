// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final headers = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
    "Accept": "application/json, text/javascript, */*; q=0.01",
  };

  final String officialUrl = "https://www.jiosaavn.com/api.php?__call=search.getResults&p=1&q=Arijit&_format=json&_marker=0&api_version=4&ctx=web6dot0";
  
  print("Fetching Official Data...");
  try {
     final response = await http.get(Uri.parse(officialUrl), headers: headers);
     if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] != null && (data['results'] as List).isNotEmpty) {
           final firstItem = (data['results'] as List)[0];
           print("DATA_START");
           print(json.encode(firstItem));
           print("DATA_END");
        }
     }
  } catch (e) {
    print("Error: $e");
  }
}
