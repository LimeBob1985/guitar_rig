import 'package:flutter/services.dart';

class AudioManager {
  static const MethodChannel _channel = MethodChannel('audio_channel');

  // Avvio DSP nativo
  static Future<void> start() async {
    await _channel.invokeMethod('start');
  }

  // Gain globale (Master DSP)
  static Future<void> setGain(double value) async {
    await _channel.invokeMethod(
      'setGain',
      {"value": value},
    );
  }

  // Parametri del MIXER (In, Out, Gate, Limit, Volume, Treble, Master)
  static Future<void> setMixer(String name, double value) async {
    await _channel.invokeMethod(
      'setMixer',
      {
        "name": name,
        "value": value,
      },
    );
  }

  // Valore del pedale (0–10)
  static Future<void> setPedal(String name, double value) async {
    await _channel.invokeMethod(
      'setPedal',
      {
        "name": name,
        "value": value,
      },
    );
  }

  // EQ per pedale (Bass/Mid/Treble)
  static Future<void> setPedalEQ(String pedal, String band, double value) async {
    await _channel.invokeMethod(
      'setPedalEQ',
      {
        "pedal": pedal,
        "band": band,
        "value": value,
      },
    );
  }
}
