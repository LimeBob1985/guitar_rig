class PresetModel {
  String name;
  String date;
  Map<String, double> mixerValues;
  Map<String, double> pedalValues;

  // ⭐ AGGIUNTA EQ PER-PEDALE
  Map<String, Map<String, double>> pedalEQ;

  PresetModel({
    required this.name,
    required this.date,
    required this.mixerValues,
    required this.pedalValues,

    // ⭐ AGGIUNTA EQ PER-PEDALE
    required this.pedalEQ,
  });

  // Crea una copia per evitare di modificare l'originale per errore
  PresetModel copyWith({String? name}) {
    return PresetModel(
      name: name ?? this.name,
      date: this.date,
      mixerValues: Map.from(mixerValues),
      pedalValues: Map.from(pedalValues),

      // ⭐ AGGIUNTA EQ PER-PEDALE
      pedalEQ: {
        for (var entry in pedalEQ.entries)
          entry.key: Map.from(entry.value)
      },
    );
  }

  // --- AGGIUNTI PER LA PERSISTENZA ---

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'date': date,
      'mixerValues': mixerValues,
      'pedalValues': pedalValues,

      // ⭐ AGGIUNTA EQ PER-PEDALE
      'pedalEQ': pedalEQ,
    };
  }

  factory PresetModel.fromMap(Map<String, dynamic> map) {
    // ⭐ RETRO-COMPATIBILITÀ:
    // se un preset vecchio non ha pedalEQ → lo creo vuoto
    Map<String, Map<String, double>> parsedEQ = {};

    if (map.containsKey('pedalEQ')) {
      final raw = map['pedalEQ'] as Map<String, dynamic>;
      raw.forEach((pedal, bands) {
        parsedEQ[pedal] = (bands as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, (v as num).toDouble()),
        );
      });
    } else {
      // preset vecchio → creo EQ vuoto
      parsedEQ = {
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
    }

    return PresetModel(
      name: map['name'] ?? 'Senza nome',
      date: map['date'] ?? '',
      mixerValues: (map['mixerValues'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      ),
      pedalValues: (map['pedalValues'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      ),

      // ⭐ AGGIUNTA EQ PER-PEDALE
      pedalEQ: parsedEQ,
    );
  }
}
