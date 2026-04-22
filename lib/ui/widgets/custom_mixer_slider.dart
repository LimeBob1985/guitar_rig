import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomMixerSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final String label;
  final String displayValue;
  final bool isVertical;
  final bool fillFromBase;
  final Color backgroundColor;
  final Color thumbColor;
  final Color activeTrackColor;
  final ValueChanged<double> onChanged;

  const CustomMixerSlider({
    super.key,
    required this.value,
    required this.onChanged,
    required this.min,
    required this.max,
    required this.label,
    required this.displayValue,
    this.isVertical = false,
    this.fillFromBase = false,
    this.backgroundColor = const Color(0xFF2C3135),
    this.thumbColor = const Color(0xFFFFB366),
    this.activeTrackColor = const Color(0xFF8B5A2B),
  });

  @override
  Widget build(BuildContext context) {
    const double verticalWidth = 60;
    const double horizontalHeight = 55;

    return SizedBox(
      width: isVertical ? verticalWidth : double.infinity,
      height: isVertical ? double.infinity : horizontalHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [

          Container(
            width: isVertical ? verticalWidth : double.infinity,
            height: isVertical ? double.infinity : horizontalHeight,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(3),
            ),
          ),

          Positioned.fill(
            child: CustomPaint(
              painter: SliderTrackPainter(
                value: value,
                min: min,
                max: max,
                isVertical: isVertical,
                fillFromBase: fillFromBase,
                trackColor: activeTrackColor,
              ),
            ),
          ),

          RotatedBox(
            quarterTurns: isVertical ? 3 : 0,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 0,
                activeTrackColor: Colors.transparent,
                inactiveTrackColor: Colors.transparent,
                thumbColor: thumbColor,
                thumbShape: CustomRectThumbShape(
                  side: isVertical ? verticalWidth : horizontalHeight,
                ),
                overlayShape: SliderComponentShape.noOverlay,
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                onChanged: (newValue) {
                  double snappedValue = newValue;

                  // 🔥 MAGNETE MORBIDO SOLO SE fillFromBase = false
                  if (!fillFromBase && newValue.abs() < 0.25) {
                    if (value != 0.0) HapticFeedback.lightImpact();
                    snappedValue = 0.0;
                  }

                  onChanged(snappedValue);
                },
              ),
            ),
          ),

          Positioned(
            left: isVertical ? null : 10,
            bottom: isVertical ? 12 : null,
            child: _buildInsideLabel(label, isVertical, isName: true),
          ),

          Positioned(
            right: isVertical ? null : 10,
            top: isVertical ? 12 : null,
            child: _buildInsideLabel(displayValue, isVertical, isName: false),
          ),
        ],
      ),
    );
  }

  Widget _buildInsideLabel(String text, bool vertical, {required bool isName}) {
    if (text.isEmpty) return const SizedBox.shrink();

    bool rotate = vertical && isName;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(2),
      ),
      child: RotatedBox(
        quarterTurns: rotate ? 3 : 0,
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            fontFamily: 'MyriadPro',
          ),
        ),
      ),
    );
  }
}

class SliderTrackPainter extends CustomPainter {
  final double value, min, max;
  final bool isVertical, fillFromBase;
  final Color trackColor;

  SliderTrackPainter({
    required this.value,
    required this.min,
    required this.max,
    required this.isVertical,
    required this.fillFromBase,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.fill;

    double origin = fillFromBase ? 0.0 : (0.0 - min) / (max - min);
    double val = (value - min) / (max - min);

    if (isVertical) {
      double y0 = size.height * (1 - origin);
      double y1 = size.height * (1 - val);
      canvas.drawRect(Rect.fromLTRB(0, y1, size.width, y0), paint);
    } else {
      double x0 = size.width * origin;
      double x1 = size.width * val;
      canvas.drawRect(Rect.fromLTRB(x0, 0, x1, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class CustomRectThumbShape extends SliderComponentShape {
  final double side;

  const CustomRectThumbShape({required this.side});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => Size(side, side);

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
        Rect.fromCenter(center: center, width: side, height: side),
        const Radius.circular(4),
      ),
      Paint()..color = sliderTheme.thumbColor!,
    );
  }
}
