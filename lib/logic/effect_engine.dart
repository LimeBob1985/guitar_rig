enum EffectType { gain, temporal, modulation, dynamic }

class GuitarEffect {
  final String name;
  final EffectType type;
  double intensity; // Il valore che l'utente vede (0-10)
  bool isActive;

  GuitarEffect({
    required this.name,
    required this.type,
    this.intensity = 0.0,
    this.isActive = false,
  });

  // Qui avviene la magia: trasformiamo il valore 0-10 in parametri audio reali
  void applyEffect(double inputSignal) {
    if (!isActive || intensity == 0) return;

    switch (name) {
      case "Overdrive":
        // Logica di saturazione del segnale
        break;
      case "Delay":
        // Logica di eco temporale
        break;
      case "Reverb":
        // Logica di riverbero ambientale
        break;
      // ... altri effetti
    }
  }
}