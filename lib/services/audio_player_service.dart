import 'package:audioplayers/audioplayers.dart';

class AudioPlayerService {
  static final AudioPlayer _player = AudioPlayer();

  static Future<void> playSound(String fileName) async {
    try {
      await _player.play(AssetSource(fileName));
    } catch (e) {
      print("Error reproduciendo sonido: $e");
    }
  }
}
