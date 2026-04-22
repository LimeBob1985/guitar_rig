import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../logic/app_provider.dart';
import '../widgets/custom_mixer_slider.dart';

class MixerPage extends StatefulWidget {
  const MixerPage({super.key});

  @override
  State<MixerPage> createState() => _MixerPageState();
}

class _MixerPageState extends State<MixerPage> {
  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: Column(
        children: [
          _buildBlackHeader(state),

          // --- ZONA SUPERIORE: Peak Meter ---
          Expanded(
            flex: 1, 
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: _buildPeakMeter(state),
              ),
            ),
          ),

          // --- ZONA CENTRALE: Input/Output ---
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 5),
            child: Column(
              children: [
                _hRow("Input", state.currentMixer["In"] ?? 0.0,
                    (v) => state.updateMixer("In", v)),
                const SizedBox(height: 6),
                _hRow("Output", state.currentMixer["Out"] ?? 0.0,
                    (v) => state.updateMixer("Out", v)),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              "EQUALIZER & GAIN",
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),

          // --- ZONA INFERIORE: Controlli Verticali ---
          Expanded(
            flex: 4, 
            child: Padding(
              padding: const EdgeInsets.fromLTRB(15, 0, 15, 0), 
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch, 
                children: [
                  _vControl(
                    "Gain",
                    state.currentMixer["Gate"] ?? 0.0,
                    0,
                    10,
                    true,
                    true,
                    (v) => state.updateMixer("Gate", v),
                  ),

                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.5,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.stretch, 
                      children: [
                        _vControl(
                          "Bass",
                          state.currentMixer["Limit"] ?? 0.0,
                          -10,
                          10,
                          false,
                          false,
                          (v) => state.updateMixer("Limit", v),
                        ),
                        _vControl(
                          "Mid",
                          state.currentMixer["Volume"] ?? 0.0,
                          -10,
                          10,
                          false,
                          false,
                          (v) => state.updateMixer("Volume", v),
                        ),
                        _vControl(
                          "Treble",
                          state.currentMixer["Treble"] ?? 0.0,
                          -10,
                          10,
                          false,
                          false,
                          (v) => state.updateMixer("Treble", v),
                        ),
                      ],
                    ),
                  ),

                  _vControl(
                    "Master",
                    state.currentMixer["Master"] ?? 10.0,
                    0,
                    10,
                    true,
                    true,
                    (v) => state.updateMixer("Master", v),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlackHeader(AppProvider state) {
    return Container(
      width: double.infinity,
      height: 60,
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SafeArea( 
        bottom: false,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Text(
              "MIXER",
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: _headerButton(
                "Mute",
                () => state.toggleMute(),
                Colors.red,
                isFilled: state.isMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerButton(String label, VoidCallback onTap, Color color,
      {bool isFilled = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 65,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isFilled ? color : Colors.transparent,
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

  Widget _buildPeakMeter(AppProvider state) {
    return SizedBox(
      height: 50, // Ingrandito proporzionalmente in altezza come richiesto
      child: Row(
        children: List.generate(35, (i) {
          Color color = const Color(0xFF0F0F0F);
          if (i < state.currentPeakLevel) {
            if (i < 22) color = Colors.green;
            else if (i < 30) color = Colors.yellow;
            else color = Colors.red;
          }
          return Expanded(
            child: Container(
              margin: const EdgeInsets.all(0.5),
              color: color,
            ),
          );
        }),
      ),
    );
  }

  Widget _hRow(String label, double val, ValueChanged<double> cb) {
    return CustomMixerSlider(
      label: label,
      value: val,
      min: -10,
      max: 10,
      displayValue: "${val >= 0 ? '+' : ''}${val.toStringAsFixed(2)} dB",
      fillFromBase: false,
      onChanged: cb,
    );
  }

  Widget _vControl(
    String label,
    double val,
    double min,
    double max,
    bool isSpecial,
    bool fromBase,
    ValueChanged<double> cb,
  ) {
    return CustomMixerSlider(
      label: label,
      value: val,
      min: min,
      max: max,
      displayValue: val.toStringAsFixed(1),
      isVertical: true,
      fillFromBase: fromBase,
      backgroundColor: const Color(0xFF2C3135),
      thumbColor: isSpecial ? const Color(0xFFB0B0B0) : const Color(0xFFFFB366),
      activeTrackColor:
          isSpecial ? const Color(0xFF606060) : const Color(0xFF8B5A2B),
      onChanged: cb,
    );
  }
}