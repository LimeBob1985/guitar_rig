import 'dart:async';

class AudioTestService {
  // Questo simulerà l'invio di segnale audio clean per i tuoi test
  bool isTesting = false;

  void startCleanLoop() {
    isTesting = true;
    print("Simulatore Audio: In riproduzione loop chitarra clean...");
    // Qui integreremo il caricamento del file audio che userai come test
  }

  void stopCleanLoop() {
    isTesting = false;
    print("Simulatore Audio: Stop.");
  }
}