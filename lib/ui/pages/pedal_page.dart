import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../logic/app_provider.dart';

// 🔥 IMPORTA LO SLIDER DEDICATO AI PEDALI
import '../widgets/custom_mixer_slider_pedal.dart';

class PedalPage extends StatefulWidget {
  const PedalPage({super.key});

  @override
  State<PedalPage> createState() => _PedalPageState();
}

class _PedalPageState extends State<PedalPage> {
  
  // Mappatura dei colori specifica per ogni pedale
  Map<String, Color> _getPedalColors(String name) {
    switch (name) {
      case "Acoustic IR":
        return {"thumb": const Color(0xFF4FC3F7), "track": const Color(0xFF0288D1)};
      case "Clean":
        return {"thumb": const Color(0xFFFFD54F), "track": const Color(0xFFB8860B)};
      case "Compressor":
        return {"thumb": const Color(0xFFAED581), "track": const Color(0xFF689F38)};
      case "Delay":
        return {"thumb": const Color(0xFFFFB74D), "track": const Color(0xFFF57C00)};
      case "Reverb":
        return {"thumb": const Color(0xFFBA68C8), "track": const Color(0xFF7B1FA2)};
      case "Chorus":
        return {"thumb": const Color(0xFF4DB6AC), "track": const Color(0xFF00796B)};
      case "Tremolo":
        return {"thumb": const Color(0xFFE57373), "track": const Color(0xFFD32F2F)};
      case "Rotary":
        return {"thumb": const Color(0xFFFFF176), "track": const Color(0xFFFBC02D)};
      case "Flanger":
        return {"thumb": const Color(0xFF90A4AE), "track": const Color(0xFF455A64)};
      case "Overdrive":
        return {"thumb": const Color(0xFFFFCC80), "track": const Color(0xFFFB8C00)};
      case "Crunch":
        return {"thumb": const Color(0xFFFFD54F), "track": const Color(0xFFFFA000)};
      case "Distortion":
        return {"thumb": const Color(0xFFFF7043), "track": const Color(0xFFBF360C)};
      case "Noise":
        return {"thumb": const Color(0xFF9575CD), "track": const Color(0xFF512DA8)};
      default:
        return {"thumb": const Color(0xFFFFB366), "track": const Color(0xFF8B5A2B)};
    }
  }

  void _handleSave(AppProvider state) {
    String initialName = state.editingIndex != null 
        ? state.savedPresets[state.editingIndex!].name 
        : "Nuovo Preset";
        
    TextEditingController nameController = TextEditingController(text: initialName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Salva Preset", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: nameController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: "Nome Preset",
            labelStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.red)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annulla", style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () {
              state.saveCurrentAsPreset(nameController.text);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Preset Salvato!"), backgroundColor: Colors.red),
              );
            },
            child: const Text("SALVA", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppProvider>(context);
    
    // CREO LA LISTA ORDINATA
    List<String> pedalNames = state.currentPedals.keys.where((n) => n != "Acoustic IR" && n != "Clean").toList();
    pedalNames.insert(0, "Acoustic IR");
    pedalNames.insert(1, "Clean"); 
    
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: SafeArea(
        child: Column(
          children: [
            _buildBlackHeader(state), 
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // 🔥 più vicino
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: pedalNames.map((name) => _buildPedalRow(state, name)).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔥 HEADER IDENTICO AL MIXER
  Widget _buildBlackHeader(AppProvider state) {
    return Container(
      width: double.infinity,
      height: 60,
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Text(
            "PEDAL",
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _headerButton("Save", () => _handleSave(state), Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _headerButton(String label, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 65,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildPedalRow(AppProvider state, String name) {
    final colors = _getPedalColors(name);
    final value = state.currentPedals[name] ?? 0.0;

    return Container(
      height: 48, // 🔥 ALTEZZA UNIFORMATA AL NUOVO SLIDER
      width: double.infinity,
      color: const Color(0xFF2C3135),
      child: CustomMixerSliderPedal(
        label: name,
        value: value,
        min: 0.0,
        max: 10.0,
        displayValue: value.toStringAsFixed(1),
        backgroundColor: Colors.transparent,
        thumbColor: colors["thumb"]!,
        activeTrackColor: colors["track"]!,
        onChanged: (newValue) {
          state.updatePedal(name, newValue);
        },
      ),
    );
  }
}
