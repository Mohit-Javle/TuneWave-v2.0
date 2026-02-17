// ignore_for_file: avoid_print

import 'dart:io';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final server = await HttpServer.bind(InternetAddress.anyIPv4, 8082);
  print('-------------------------------------------');
  print('Proxy server started on port ${server.port}');
  print('Local address: http://${server.address.address}:${server.port}');
  print('-------------------------------------------');

  await for (HttpRequest request in server) {
    print('\n[${DateTime.now()}] Incoming Request: ${request.method} ${request.uri}');
    
    // Add CORS headers
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', '*');

    if (request.method == 'OPTIONS') {
      print("  Handling OPTIONS preflight");
      request.response.close();
      continue;
    }

    // Check for explicit Stream proxying
    if (request.uri.path == '/stream') {
        final streamUrl = request.uri.queryParameters['url'];
        if (streamUrl != null && streamUrl.isNotEmpty) {
           try {
             print("  Streaming from: $streamUrl");
             final client = http.Client();
             final requestStream = http.Request('GET', Uri.parse(streamUrl));
             requestStream.headers.addAll({
               "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
               "Accept": "*/*",
               "Range": request.headers.value("range") ?? "bytes=0-"
             });

             final streamResponse = await client.send(requestStream);
             
             request.response.statusCode = streamResponse.statusCode;
             request.response.headers.contentType = streamResponse.headers['content-type'] != null 
                                                    ? ContentType.parse(streamResponse.headers['content-type']!)
                                                    : ContentType.binary;
             
             // Forward content-length if available
             if (streamResponse.headers['content-length'] != null) {
                request.response.headers.contentLength = int.parse(streamResponse.headers['content-length']!);
             }
             
             // Forward content-range if available (crucial for seeking)
             if (streamResponse.headers['content-range'] != null) {
                request.response.headers.add("Content-Range", streamResponse.headers['content-range']!);
             }
             
             request.response.headers.add("Accept-Ranges", "bytes");

             await request.response.addStream(streamResponse.stream);
             await request.response.close();
             print("  Stream finished.");
           } catch (e) {
             print("  STREAM ERROR: $e");
             request.response.statusCode = 500;
             request.response.write("Stream Error: $e");
             await request.response.close();
           }
           continue; 
        }
    }

    try {
      // Reconstruct target URL for API
      // Ensure we start with /
      String pathQuery = request.uri.toString();
      if (!pathQuery.startsWith('/')) {
        pathQuery = '/$pathQuery';
      }
      final String targetUrl = "https://www.jiosaavn.com$pathQuery";
      
      print("  Proxying to: $targetUrl");

      final response = await http.get(Uri.parse(targetUrl), headers: {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
        "Accept": "application/json, text/plain, */*"
      });

      print("  Response status: ${response.statusCode}");
      print("  Response length: ${response.body.length} bytes");

      request.response.statusCode = response.statusCode;
      request.response.write(response.body);
    } catch (e) {
      print("  PROXY ERROR: $e");
      request.response.statusCode = 500;
      request.response.write("Proxy Error: $e");
    } finally {
      await request.response.close();
      print("  Request closed.");
    }
  }
}
