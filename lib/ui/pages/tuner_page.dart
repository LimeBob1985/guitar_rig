import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../logic/app_provider.dart';

class TunerPage extends StatefulWidget {
  const TunerPage({super.key});

  @override
  State<TunerPage> createState() => _TunerPageState();
}

class _TunerPageState extends State<TunerPage> {
  String selectedReference = "440 Hz";
  String selectedTuning = "Standard";

  bool wasTuned = false; // Per vibrazione una sola volta

  void _showTuningMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "CONFIGURAZIONE ACCORDATORE",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const Divider(color: Colors.white24),

              ListTile(
                title: const Text("Riferimento A4", style: TextStyle(color: Colors.white70, fontSize: 14)),
                trailing: DropdownButton<String>(
                  dropdownColor: const Color(0xFF1A1A1A),
                  value: selectedReference,
                  underline: const SizedBox(),
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  items: ["432 Hz", "440 Hz", "442 Hz", "444 Hz"].map((String value) {
                    return DropdownMenuItem<String>(value: value, child: Text(value));
                  }).toList(),
                  onChanged: (val) {
                    setState(() => selectedReference = val!);
                    Navigator.pop(context);
                  },
                ),
              ),

              ListTile(
                title: const Text("Accordatura", style: TextStyle(color: Colors.white70, fontSize: 14)),
                trailing: DropdownButton<String>(
                  dropdownColor: const Color(0xFF1A1A1A),
                  value: selectedTuning,
                  underline: const SizedBox(),
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  items: [
                    "Standard",
                    "Mezzo Tono Sotto",
                    "Un Tono Sotto",
                    "Mezzo Tono Sopra",
                    "Un Tono Sopra",
                  ].map((String value) {
                    return DropdownMenuItem<String>(value: value, child: Text(value));
                  }).toList(),
                  onChanged: (val) {
                    setState(() => selectedTuning = val!);
                    Navigator.pop(context);
                  },
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppProvider>(context);

    double tuningStatus = (state.currentFrequency % 10) / 10;
    if (tuningStatus > 0.5) tuningStatus -= 1.0;

    bool isTuned = state.currentNote != "-" && tuningStatus.abs() < 0.05;

    // Vibrazione solo quando si entra nello stato "accordato"
    if (isTuned && !wasTuned) {
      HapticFeedback.mediumImpact();
    }
    wasTuned = isTuned;

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: SafeArea(
        child: Column(
          children: [
            _buildBlackHeader(state),

            // NOTA CENTRALE STILE LINE 6
            Expanded(
              flex: 3,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    state.currentNote,
                    style: TextStyle(
                      fontSize: 150,
                      fontWeight: FontWeight.bold,
                      color: isTuned ? Colors.green : Colors.white,
                      fontFamily: 'MyriadPro',
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.6),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    selectedTuning.toUpperCase(),
                    style: const TextStyle(color: Colors.white38, fontSize: 12, letterSpacing: 2),
                  ),
                ],
              ),
            ),

            // BARRETTE GRADIENTE STILE LINE 6
            Expanded(
              flex: 2,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: List.generate(31, (index) {
                      int centerIndex = 15;
                      int distance = (index - centerIndex).abs();
                      double intensity = (distance / 15).clamp(0.0, 1.0);

                      // Gradiente rosso → arancione → giallo → verde
                      Color gradientColor = Color.lerp(
                        Colors.green,
                        Colors.red,
                        intensity,
                      )!;

                      bool isActive = false;

                      if (tuningStatus < 0) {
                        int targetIndex = centerIndex + (tuningStatus * 15).toInt();
                        if (index >= targetIndex && index < centerIndex) isActive = true;
                      } else if (tuningStatus > 0) {
                        int targetIndex = centerIndex + (tuningStatus * 15).toInt();
                        if (index <= targetIndex && index > centerIndex) isActive = true;
                      }

                      Color barColor;
                      if (index == centerIndex) {
                        barColor = isTuned ? Colors.green : Colors.white;
                      } else if (isActive) {
                        barColor = gradientColor;
                      } else {
                        barColor = const Color(0xFF0F0F0F);
                      }

                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: barColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
            ),

            // Footer
            Container(
              height: 60,
              width: double.infinity,
              color: Colors.black,
              alignment: Alignment.center,
              child: Text(
                "INPUT SIGNAL ACTIVE • REF: $selectedReference",
                style: const TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlackHeader(AppProvider state) {
    return Container(
      width: double.infinity,
      height: 60,
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: _showTuningMenu,
              child: Text(
                selectedReference,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          const Text(
            "TUNER",
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5),
          ),

          Align(
            alignment: Alignment.centerRight,
            child: _muteButton(state),
          ),
        ],
      ),
    );
  }

  // 🔥 MUTE DEL TUNER — indipendente dal MIXER
  Widget _muteButton(AppProvider state) {
    return GestureDetector(
      onTap: () => state.toggleTunerMute(),
      child: Container(
        width: 65,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: state.isTunerMuted ? Colors.red : Colors.transparent,
          border: Border.all(color: Colors.red, width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          "Mute",
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
