import 'package:audio_service/audio_service.dart';
import 'package:clone_mp/services/audio_handler.dart';

import 'package:flutter/foundation.dart';

void main() {
  final Object handler = AudioPlayerHandler();
  if (handler is AudioHandler) {
    debugPrint("AudioPlayerHandler IS AudioHandler");
  } else {
    debugPrint("AudioPlayerHandler IS NOT AudioHandler");
  }
}
