import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/preset_model.dart';
import 'audio_manager.dart';

enum EffectType { dynamic, temporal, modulation, gain }

class GuitarEffect {
  final String name;
  final EffectType type;
  double intensity;
  bool isActive;

  GuitarEffect({
    required this.name,
    required this.type,
    this.intensity = 0.0,
    this.isActive = false,
  });
}

class AppProvider extends ChangeNotifier {
  final AudioManager audioManager = AudioManager();
  int currentPeakLevel = 0;
  Timer? _peakTimer;

  // --- LOGICA TUNER ---
  bool isTunerActive = false;
  double currentFrequency = 0.0;
  String currentNote = "-";

  // ⭐ MUTE SEPARATI
  bool isMuted = false;        
  bool isTunerMuted = false;   

  // OFFSET ACCORDATURA
  int tuningOffset = 0;

  static const List<String> noteOrder = [
    "C", "C#", "D", "D#", "E", "F",
    "F#", "G", "G#", "A", "A#", "B"
  ];

  double _tanh(double x) {
    if (x > 20) return 1.0;
    if (x < -20) return -1.0;
    double exp2x = math.exp(2 * x);
    return (exp2x - 1) / (exp2x + 1);
  }

  String applyTuningOffset(String note, int offset) {
    if (note == "-" || note.isEmpty) return "-";
    int index = noteOrder.indexOf(note);
    if (index == -1) return note;
    int newIndex = (index + offset) % 12;
    if (newIndex < 0) newIndex += 12;
    return noteOrder[newIndex];
  }

  double applyFrequencyOffset(double freq, int offset) {
    return freq * math.pow(2, offset / 12);
  }

  void setTuningOffset(int semitones) {
    tuningOffset = semitones;
    notifyListeners();
  }

  Map<String, double> currentMixer = {
    "In": 0.0,
    "Out": 0.0,
    "Gate": 0.0,
    "Limit": 0.0,
    "Volume": 0.0,
    "Treble": 0.0,
    "Master": 10.0,
  };

  Map<String, double> currentPedals = {
    "Acoustic IR": 0.0,
    "Clean": 0.0,
    "Compressor": 0.0,
    "Delay": 0.0,
    "Reverb": 0.0,
    "Chorus": 0.0,
    "Tremolo": 0.0,
    "Rotary": 0.0,
    "Flanger": 0.0,
    "Overdrive": 0.0,
    "Crunch": 0.0,
    "Distortion": 0.0,
    "Noise": 0.0,
  };

  final Map<String, GuitarEffect> effects = {
    "Acoustic IR": GuitarEffect(name: "Acoustic IR", type: EffectType.dynamic),
    "Clean": GuitarEffect(name: "Clean", type: EffectType.gain),
    "Compressor": GuitarEffect(name: "Compressor", type: EffectType.dynamic),
    "Delay": GuitarEffect(name: "Delay", type: EffectType.temporal),
    "Reverb": GuitarEffect(name: "Reverb", type: EffectType.temporal),
    "Chorus": GuitarEffect(name: "Chorus", type: EffectType.modulation),
    "Tremolo": GuitarEffect(name: "Tremolo", type: EffectType.modulation),
    "Rotary": GuitarEffect(name: "Rotary", type: EffectType.modulation),
    "Flanger": GuitarEffect(name: "Flanger", type: EffectType.modulation),
    "Overdrive": GuitarEffect(name: "Overdrive", type: EffectType.gain),
    "Crunch": GuitarEffect(name: "Crunch", type: EffectType.gain),
    "Distortion": GuitarEffect(name: "Distortion", type: EffectType.gain),
    "Noise": GuitarEffect(name: "Noise", type: EffectType.dynamic),
  };

  List<PresetModel> savedPresets = [];
  int? editingIndex;

  // ⭐ EQ PER-PEDALE
  Map<String, Map<String, double>> pedalEQ = {
    "Acoustic IR": {"Bass": 0.0, "Mid": 0.0, "Treble": 0.0},
    "Clean": {"Bass": 0.0, "Mid": 0.0, "Treble": 0.0},
    "Compressor": {"Bass": 0.0, "Mid": 0.0, "Treble": 0.0},
    "Delay": {"Bass": 0.0, "Mid": 0.0, "Treble": 0.0},
    "Reverb": {"Bass": 0.0, "Mid": 0.0, "Treble": 0.0},
    "Chorus": {"Bass": 0.0, "Mid": 0.0, "Treble": 0.0},
    "Tremolo": {"Bass": 0.0, "Mid": 0.0, "Treble": 0.0},
    "Rotary": {"Bass": 0.0, "Mid": 0.0, "Treble": 0.0},
    "Flanger": {"Bass": 0.0, "Mid": 0.0, "Treble": 0.0},
    "Overdrive": {"Bass": 0.0, "Mid": 0.0, "Treble": 0.0},
    "Crunch": {"Bass": 0.0, "Mid": 0.0, "Treble": 0.0},
    "Distortion": {"Bass": 0.0, "Mid": 0.0, "Treble": 0.0},
    "Noise": {"Bass": 0.0, "Mid": 0.0, "Treble": 0.0},
  };

  AppProvider() {
    _startPeakMeter();
    _loadPresetsFromDisk();
  }

  // --- PERSISTENZA ---
  Future<void> _savePresetsToDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData =
        json.encode(savedPresets.map((p) => p.toMap()).toList());
    await prefs.setString('guitar_presets_permanent', encodedData);
  }

  Future<void> _loadPresetsFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final String? encodedData = prefs.getString('guitar_presets_permanent');

    if (encodedData != null) {
      final List<dynamic> decodedData = json.decode(encodedData);
      savedPresets =
          decodedData.map((item) => PresetModel.fromMap(item)).toList();
      notifyListeners();
    }
  }

  // --- TUNER ---
  void toggleTuner() {
    isTunerActive = !isTunerActive;
    _syncAudio();
    notifyListeners();
  }

  // --- MUTE MIXER ---
  void toggleMute() {
    isMuted = !isMuted;
    _syncAudio();
    notifyListeners();
  }

  // --- MUTE TUNER ---
  void toggleTunerMute() {
    isTunerMuted = !isTunerMuted;
    _syncAudio();
    notifyListeners();
  }

  // --- PEAK METER ---
  void _startPeakMeter() {
    _peakTimer?.cancel();
    _peakTimer =
        Timer.periodic(const Duration(milliseconds: 80), (timer) {
      if (isMuted || isTunerActive || isTunerMuted) {
        currentPeakLevel = 0;
      } else {
        double inFactor = ((currentMixer["In"] ?? 0.0) + 50) / 100;
        double gainStack =
            ((currentPedals["Clean"] ?? 0.0) / 20) +
            ((currentPedals["Overdrive"] ?? 0.0) / 15) +
            ((currentPedals["Crunch"] ?? 0.0) / 12) +
            ((currentPedals["Distortion"] ?? 0.0) / 8);

        double gainFactor =
            1.0 + ((currentMixer["Gate"] ?? 0.0) / 10) + gainStack;
        double signalSwing =
            0.4 + (math.Random().nextDouble() * 0.6);
        double rawLevel =
            35 * inFactor * gainFactor * signalSwing;
        currentPeakLevel = rawLevel.clamp(0, 35).toInt();
      }
      notifyListeners();
    });
  }

  // --- UPDATE PARAMETRI ---
  void updateMixer(String key, double val) {
    currentMixer[key] = val;
    _syncAudio();
    notifyListeners();
  }

  void updatePedal(String key, double val) {
    currentPedals[key] = val;
    if (effects.containsKey(key)) {
      effects[key]!.intensity = val;
      effects[key]!.isActive = val > 0;
    }
    _syncAudio();
    notifyListeners();
  }

  void updatePedalEQ(String pedal, String band, double val) {
    pedalEQ[pedal]?[band] = val;
    notifyListeners();
  }

  // --- DSP ---
  void _syncAudio() {
    // 🔥 NUOVA LOGICA MUTE
    if (isMuted || isTunerMuted || isTunerActive) {
      audioManager.setVolume(0.0);
      return;
    }

    double signal = ((currentMixer["In"] ?? 0.0) + 50) / 100;

    double noiseThreshold = (currentPedals["Noise"] ?? 0.0) / 18;
    if (signal < noiseThreshold) signal = 0;

    double b = currentMixer["Limit"] ?? 0.0;
    double m = currentMixer["Volume"] ?? 0.0;
    double t = currentMixer["Treble"] ?? 0.0;
    double acIR = (currentPedals["Acoustic IR"] ?? 0.0) / 7;
    double toneBalance =
        (t * 1.4 + acIR) - (b * 1.1) + (m * 0.6);
    signal *= (1.0 + (toneBalance / 18.0));

    if ((currentPedals["Compressor"] ?? 0.0) > 0) {
      double ratio =
          1.0 + (currentPedals["Compressor"]! / 5);
      if (signal > 0.4) {
        signal = 0.4 + (signal - 0.4) / ratio;
      }
    }

    if ((currentPedals["Clean"] ?? 0.0) > 0) {
      signal *= (1.0 + (currentPedals["Clean"]! / 7));
    }

    double od = (currentPedals["Overdrive"] ?? 0.0) / 6;
    double crunch = (currentPedals["Crunch"] ?? 0.0) / 5;
    double dist = (currentPedals["Distortion"] ?? 0.0) / 3.5;
    double driveBase = (currentMixer["Gate"] ?? 0.0) / 4.0;

    double totalDrive = driveBase + od + crunch + dist;

    if (totalDrive > 0) {
      double gain = 1.0 + totalDrive * 1.4;
      double driven = signal * gain;
      signal = _tanh(driven);
    }

    // ⭐⭐⭐ EQ REALISTICO PER-PEDALE (HELIX STYLE) ⭐⭐⭐
    double bass = 0.0;
    double mid = 0.0;
    double treble = 0.0;

    currentPedals.forEach((pedal, value) {
      if (value > 0 && pedalEQ.containsKey(pedal)) {
        bass += (pedalEQ[pedal]!["Bass"] ?? 0.0) * (value / 10);
        mid += (pedalEQ[pedal]!["Mid"] ?? 0.0) * (value / 10);
        treble += (pedalEQ[pedal]!["Treble"] ?? 0.0) * (value / 10);
      }
    });

    bass = bass.clamp(-10.0, 10.0);
    mid = mid.clamp(-10.0, 10.0);
    treble = treble.clamp(-10.0, 10.0);

    // Low-shelf (bassi)
    signal *= (1.0 + (bass / 40.0));

    // Peak (medi)
    signal *= (1.0 + (mid / 55.0));

    // High-shelf (alti)
    signal *= (1.0 + (treble / 35.0));
    // ⭐⭐⭐ FINE EQ REALISTICO ⭐⭐⭐

    double time =
        DateTime.now().millisecondsSinceEpoch / 1000.0;

    if ((currentPedals["Chorus"] ?? 0.0) > 0) {
      double depth = currentPedals["Chorus"]! / 12;
      signal *= (1.0 + math.sin(time * 2.5) * depth);
    }

    if ((currentPedals["Flanger"] ?? 0.0) > 0) {
      double depth = currentPedals["Flanger"]! / 10;
      signal *= (1.0 + math.cos(time * 4.0) * depth * 0.8);
    }

    if ((currentPedals["Rotary"] ?? 0.0) > 0) {
      double depth = currentPedals["Rotary"]! / 14;
      signal *= (1.0 + math.sin(time * 7.0) * depth);
    }

    if ((currentPedals["Tremolo"] ?? 0.0) > 0) {
      double depth = (currentPedals["Tremolo"]! / 12).clamp(0.0, 0.9);
      double lfo = (math.sin(time * 8.0) + 1.0) / 2.0;
      signal *= (1.0 - depth * lfo);
    }

    double delayAmt = currentPedals["Delay"] ?? 0.0;
    double reverbAmt = currentPedals["Reverb"] ?? 0.0;
    double space = (delayAmt * 1.4 + reverbAmt * 1.8) / 20;
    signal *= (1.0 + space);

    double finalOutput = (signal *
            (((currentMixer["Out"] ?? 0.0) + 50) / 100) *
            ((currentMixer["Master"] ?? 10.0) / 10))
        .clamp(0.0, 1.0);

    audioManager.setVolume(finalOutput);
  }

  // --- PRESET ---
  void saveCurrentAsPreset(String name) {
    String date =
        "${DateTime.now().day.toString().padLeft(2, '0')}.${DateTime.now().month.toString().padLeft(2, '0')}.${DateTime.now().year.toString().substring(2)}";

    var newPreset = PresetModel(
      name: name,
      date: date,
      mixerValues: Map.from(currentMixer),
      pedalValues: Map.from(currentPedals),
      pedalEQ: Map.from(pedalEQ),
    );

    if (editingIndex != null) {
      savedPresets[editingIndex!] = newPreset;
    } else {
      savedPresets.add(newPreset);
    }

    _savePresetsToDisk();
    notifyListeners();
  }

  void renamePreset(int index, String newName) {
    savedPresets[index].name = newName;
    _savePresetsToDisk();
    notifyListeners();
  }

  void loadPreset(int index) {
    editingIndex = index;
    currentMixer = Map.from(savedPresets[index].mixerValues);
    currentPedals = Map.from(savedPresets[index].pedalValues);
    pedalEQ = Map.from(savedPresets[index].pedalEQ);

    currentPedals.forEach((key, value) {
      if (effects.containsKey(key)) {
        effects[key]!.intensity = value;
        effects[key]!.isActive = value > 0;
      }
    });

    _syncAudio();
    notifyListeners();
  }

  void deletePreset(int index) {
    if (editingIndex == index) editingIndex = null;
    savedPresets.removeAt(index);
    _savePresetsToDisk();
    notifyListeners();
  }

  @override
  void dispose() {
    _peakTimer?.cancel();
    super.dispose();
  }
}
