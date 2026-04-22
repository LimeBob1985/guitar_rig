import 'package:audioplayers/audioplayers.dart';

class AudioManager {
  final AudioPlayer _player = AudioPlayer();

  Future<void> init() async {
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setSource(AssetSource('audio/guitar_test.mp3'));
    } catch (e) {
      print("Errore caricamento audio: $e");
    }
  }

  // Accetta un booleano per decidere se suonare o fermarsi
  void togglePlay(bool shouldPlay) {
    if (shouldPlay) {
      _player.resume();
    } else {
      _player.pause();
    }
  }

  // Metodo per impostare il volume da 0.0 a 1.0
  void setVolume(double volume) {
    _player.setVolume(volume.clamp(0.0, 1.0));
  }
}