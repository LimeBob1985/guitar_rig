import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/preset_model.dart';
import '../services/audio_manager.dart';
import 'package:flutter/services.dart';

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
  // --- PEAK LEVEL REALE DAL DSP ---
  int currentPeakLevel = 0;

  // --- LOGICA TUNER ---
  bool isTunerActive = false;
  double currentFrequency = 0.0;
  String currentNote = "-";

  // MUTE
  bool isMuted = false;
  bool isTunerMuted = false;

  // OFFSET ACCORDATURA
  int tuningOffset = 0;

  // Gain globale DSP
  double _currentGain = 1.0;

  static const List<String> noteOrder = [
    "C","C#","D","D#","E","F",
    "F#","G","G#","A","A#","B"
  ];

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

  // --- MIXER ---
  Map<String, double> currentMixer = {
    "In": 0.0,
    "Out": 0.0,
    "Gate": 0.0,
    "Limit": 0.0,
    "Volume": 0.0,
    "Treble": 0.0,
    "Master": 10.0,
  };

  // --- PEDALI ---
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

  // --- EQ PER-PEDALE ---
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

  // --- PRESET ---
  List<PresetModel> savedPresets = [];
  int? editingIndex;

  AppProvider() {
    _loadPresetsFromDisk();
    AudioManager.start();

    const MethodChannel("audio_channel").setMethodCallHandler((call) async {
      switch (call.method) {
        case "tunerData":
          currentFrequency = (call.arguments["frequency"] as num).toDouble();
          currentNote = call.arguments["note"] as String;
          notifyListeners();
          break;

        case "meterData":
          final peak = (call.arguments["peak"] as num).toDouble();

          if (isMuted || isTunerActive || isTunerMuted) {
            currentPeakLevel = 0;
          } else {
            currentPeakLevel = (peak * 35).clamp(0, 35).toInt();
          }
          notifyListeners();
          break;
      }
    });
  }

  // --- MUTE ---
  void toggleTuner() {
    isTunerActive = !isTunerActive;
    _syncAudio();
    notifyListeners();
  }

  void toggleMute() {
    isMuted = !isMuted;
    _syncAudio();
    notifyListeners();
  }

  void toggleTunerMute() {
    isTunerMuted = !isTunerMuted;
    _syncAudio();
    notifyListeners();
  }

  // --- SYNC DSP ---
  void _syncAudio() {
    if (isMuted || isTunerMuted || isTunerActive) {
      _currentGain = 0.0;
      AudioManager.setGain(0.0);
      return;
    }

    double master = ((currentMixer["Master"] ?? 10.0) / 10.0)
        .clamp(0.0, 1.0);

    _currentGain = master;
    AudioManager.setGain(master);
  }

  // --- UPDATE PARAMETRI ---
  void updateMixer(String key, double val) {
    currentMixer[key] = val;
    AudioManager.setMixer(key, val);
    notifyListeners();
  }

  void updatePedal(String key, double val) {
    currentPedals[key] = val;

    if (effects.containsKey(key)) {
      effects[key]!.intensity = val;
      effects[key]!.isActive = val > 0;
    }

    AudioManager.setPedal(key, val);
    notifyListeners();
  }

  void updatePedalEQ(String pedal, String band, double val) {
    pedalEQ[pedal]?[band] = val;
    AudioManager.setPedalEQ(pedal, band, val);
    notifyListeners();
  }

  // --- PRESET ---
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
    super.dispose();
  }
}
