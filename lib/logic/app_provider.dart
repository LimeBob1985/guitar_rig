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

  // Gain globale calcolato dal DSP (0–1)
  double _currentGain = 1.0;

  static const List<String> noteOrder = [
    "C", "C#", "D", "D#", "E", "F",
    "F#", "G", "G#", "A", "A#", "B"
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
    _loadPresetsFromDisk();
    AudioManager.start();

    // ⭐ LISTENER TUNER NATIVO
    const MethodChannel("audio_channel").setMethodCallHandler((call) async {
      if (call.method == "tunerData") {
        currentFrequency = (call.arguments["frequency"] as num).toDouble();
        currentNote = call.arguments["note"] as String;
        notifyListeners();
      }
    });
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

  // --- AUDIO INPUT REALE ---
  void _processAudioInput(List<double> samples) {
    if (isMuted || isTunerMuted || isTunerActive) {
      currentPeakLevel = 0;
      notifyListeners();
      return;
    }

    double peak = 0.0;
    for (final s in samples) {
      double v = (s * _currentGain).abs();
      if (v > peak) peak = v;
    }
    currentPeakLevel = (peak * 35).clamp(0, 35).toInt();

    notifyListeners();
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

  // --- DSP (ora delegato al DSP nativo) ---
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
