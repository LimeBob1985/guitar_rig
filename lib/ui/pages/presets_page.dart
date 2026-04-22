import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../logic/app_provider.dart';

class PresetsPage extends StatefulWidget {
  const PresetsPage({super.key});

  @override
  State<PresetsPage> createState() => _PresetsPageState();
}

class _PresetsPageState extends State<PresetsPage> {
  
  // Funzione per eliminare un preset tramite il Provider
  void _deletePreset(AppProvider state, int index) {
    state.deletePreset(index); // Usiamo il metodo del provider che gestisce anche l'editingIndex
  }

  // Funzione MODIFICA: Carica i dati e permette di rinominare
  void _editPreset(AppProvider state, int index) {
    // Carichiamo i parametri del preset (Mixer + Pedali) nel "cervello" dell'app
    state.loadPreset(index);

    TextEditingController nameController = TextEditingController(
      text: state.savedPresets[index].name
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text(
            "Modifica Preset", 
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Parametri caricati. Puoi rinominare il preset o modificarlo nelle pagine Mixer/Pedal.",
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Nome Preset",
                  labelStyle: TextStyle(color: Colors.white38),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.red)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.red)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annulla", style: TextStyle(color: Colors.white38)),
            ),
            TextButton(
              onPressed: () {
                // Aggiorna il nome nel preset tramite il metodo dedicato
                state.renamePreset(index, nameController.text);
                Navigator.pop(context);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Parametri caricati e nome aggiornato!"),
                    backgroundColor: Colors.red,
                  ),
                );
              },
              child: const Text("Carica e Salva", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Accediamo ai dati centralizzati
    final state = Provider.of<AppProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: SafeArea(
        child: Column(
          children: [
            _buildBlackHeader(),
            Expanded(
              child: state.savedPresets.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: state.savedPresets.length,
                      separatorBuilder: (context, index) => const Divider(color: Colors.white10),
                      itemBuilder: (context, index) {
                        return _buildPresetItem(state, index);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlackHeader() {
    return Container(
      width: double.infinity,
      height: 60,
      color: Colors.black,
      alignment: Alignment.center,
      child: const Text(
        "PRESET",
        style: TextStyle(
          color: Colors.white, 
          fontSize: 13, 
          fontWeight: FontWeight.bold, 
          letterSpacing: 1.5
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Text(
        "Nessun salvataggio effettuato",
        style: TextStyle(color: Colors.white38, fontSize: 14),
      ),
    );
  }

  Widget _buildPresetItem(AppProvider state, int index) {
    final preset = state.savedPresets[index];
    // Se il preset è quello attualmente in modifica, lo evidenziamo leggermente
    bool isCurrent = state.editingIndex == index;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isCurrent ? Colors.white.withOpacity(0.03) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => state.loadPreset(index), // Cliccando sul testo carichi il suono
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preset.name,
                    style: TextStyle(
                      color: isCurrent ? Colors.red : Colors.white, 
                      fontSize: 16, 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    preset.date,
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          // Tasto Modifica (Carica i dati e rinomina)
          IconButton(
            icon: const Icon(Icons.edit_note, color: Colors.white70),
            onPressed: () => _editPreset(state, index),
          ),
          // Tasto Elimina
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () => _deletePreset(state, index),
          ),
        ],
      ),
    );
  }
}