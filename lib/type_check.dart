import 'package:audio_service/audio_service.dart';
import 'package:clone_mp/services/audio_handler.dart';

void main() {
  final handler = AudioPlayerHandler();
  if (handler is AudioHandler) {
    print("AudioPlayerHandler IS AudioHandler");
  } else {
    print("AudioPlayerHandler IS NOT AudioHandler");
  }
}
