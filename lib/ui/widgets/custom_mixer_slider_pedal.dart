import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../logic/app_provider.dart';

class CustomMixerSliderPedal extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final String label;
  final String displayValue;
  final Color backgroundColor;
  final Color thumbColor;
  final Color activeTrackColor;
  final ValueChanged<double> onChanged;

  const CustomMixerSliderPedal({
    super.key,
    required this.value,
    required this.onChanged,
    required this.min,
    required this.max,
    required this.label,
    required this.displayValue,
    this.backgroundColor = const Color(0xFF2C3135),
    this.thumbColor = const Color(0xFFFFB366),
    this.activeTrackColor = const Color(0xFF8B5A2B),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: () => _openPedalEQDialog(context),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double h = constraints.maxHeight;

          return SizedBox(
            height: h,
            width: double.infinity,
            child: Stack(
              children: [
                Container(
                  height: h,
                  width: double.infinity,
                  color: backgroundColor,
                ),

                Positioned.fill(
                  child: CustomPaint(
                    painter: _PedalTrackPainter(
                      value: value,
                      min: min,
                      max: max,
                      trackColor: activeTrackColor,
                    ),
                  ),
                ),

                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: h,
                    activeTrackColor: Colors.transparent,
                    inactiveTrackColor: Colors.transparent,
                    thumbColor: thumbColor,
                    thumbShape: _PedalThumbShape(h),
                    overlayShape: SliderComponentShape.noOverlay,
                  ),
                  child: Slider(
                    value: value,
                    min: min,
                    max: max,
                    onChanged: (newValue) {
                      double snappedValue = newValue;

                      // 🔥 MAGNETE MORBIDO CORRETTO
                      if (newValue.abs() < 0.4 && value != 0.0) {
                        HapticFeedback.lightImpact();
                        snappedValue = 0.0;
                      }

                      onChanged(snappedValue);
                    },
                  ),
                ),

                Positioned.fill(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: Center(child: _label(label)),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Center(child: _label(displayValue)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------
  // 🔥 DIALOG EQ — MINI EQUALIZER + ANIMAZIONE LINE 6
  // ------------------------------------------------------------
  void _openPedalEQDialog(BuildContext context) {
    final state = Provider.of<AppProvider>(context, listen: false);

    double bass = state.pedalEQ[label]!["Bass"]!;
    double mid = state.pedalEQ[label]!["Mid"]!;
    double treble = state.pedalEQ[label]!["Treble"]!;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "EQ",
      barrierColor: Colors.black54,

      transitionDuration: const Duration(milliseconds: 180),
      transitionBuilder: (context, anim, _, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutBack,
        );

        return Opacity(
          opacity: anim.value,
          child: Transform.scale(
            scale: curved.value,
            child: child,
          ),
        );
      },

      pageBuilder: (context, _, __) {
        return Center(
          child: AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),

            insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 200),
            contentPadding: const EdgeInsets.only(top: 10, bottom: 10),

            title: Center(
              child: Text(
                "EQ – $label",
                style: const TextStyle(color: Colors.white),
              ),
            ),

            content: SizedBox(
              width: 220,
              height: 150,
              child: StatefulBuilder(
                builder: (context, setState) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _miniEQSlider(
                        "Bass",
                        bass,
                        (v) {
                          setState(() => bass = v);
                          state.updatePedalEQ(label, "Bass", v);
                        },
                      ),
                      _miniEQSlider(
                        "Mid",
                        mid,
                        (v) {
                          setState(() => mid = v);
                          state.updatePedalEQ(label, "Mid", v);
                        },
                      ),
                      _miniEQSlider(
                        "Treble",
                        treble,
                        (v) {
                          setState(() => treble = v);
                          state.updatePedalEQ(label, "Treble", v);
                        },
                      ),
                    ],
                  );
                },
              ),
            ),

            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Chiudi", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _miniEQSlider(String label, double val, ValueChanged<double> cb) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
        Text(
          val.toStringAsFixed(1),
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
        SizedBox(
          height: 110,
          child: RotatedBox(
            quarterTurns: 3,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 4,
                thumbColor: thumbColor,
                activeTrackColor: activeTrackColor,
                inactiveTrackColor: Colors.white24,
              ),
              child: Slider(
                value: val,
                min: -10,
                max: 10,
                onChanged: cb,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _label(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          fontFamily: 'MyriadPro',
        ),
      ),
    );
  }
}

class _PedalTrackPainter extends CustomPainter {
  final double value, min, max;
  final Color trackColor;

  _PedalTrackPainter({
    required this.value,
    required this.min,
    required this.max,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.fill;

    double percent = (value - min) / (max - min);
    double x = size.width * percent;

    canvas.drawRect(
      Rect.fromLTRB(0, 0, x, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _PedalThumbShape extends SliderComponentShape {
  final double h;
  const _PedalThumbShape(this.h);

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => Size(h, h);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: h, height: h),
        const Radius.circular(4),
      ),
      Paint()..color = sliderTheme.thumbColor!,
    );
  }
}
