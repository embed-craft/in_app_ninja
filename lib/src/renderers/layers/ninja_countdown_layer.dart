import 'dart:async';
import 'package:flutter/material.dart';
import 'ninja_layer_utils.dart';

class NinjaCountdownLayer extends StatefulWidget {
  final Map<String, dynamic> layer;

  const NinjaCountdownLayer({Key? key, required this.layer}) : super(key: key);

  @override
  State<NinjaCountdownLayer> createState() => _NinjaCountdownLayerState();
}

class _NinjaCountdownLayerState extends State<NinjaCountdownLayer> {
  Timer? _timer;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    final content = widget.layer['content'] as Map<String, dynamic>? ?? {};
    final endTimeStr = content['endTime']?.toString();
    if (endTimeStr == null) return;

    final endTime = DateTime.tryParse(endTimeStr);
    if (endTime == null) return;

    _tick(endTime);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick(endTime));
  }

  void _tick(DateTime endTime) {
    final now = DateTime.now();
    final diff = endTime.difference(now);
    
    if (diff.isNegative) {
      _timer?.cancel();
      setState(() => _timeLeft = Duration.zero);
    } else {
      setState(() => _timeLeft = diff);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d, String format) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(d.inHours);
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));

    if (format == 'MM:SS') {
      // If > 60 mins, logic might vary, but simplified usually just H:M:S or M:S
      final totalMinutes = twoDigits(d.inMinutes);
      return "$totalMinutes:$seconds";
    }
    return "$hours:$minutes:$seconds"; // Default HH:MM:SS
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.layer['content'] as Map<String, dynamic>? ?? {};
    final style = widget.layer['style'] as Map<String, dynamic>? ?? {};

    final format = content['format']?.toString() ?? 'HH:MM:SS';
    final timeString = _formatDuration(_timeLeft, format);

    // Typography
    final fontSize = NinjaLayerUtils.parseDouble(content['fontSize']) ?? 24.0;
    final fontWeight = NinjaLayerUtils.parseFontWeight(content['fontWeight']);
    final textColor = NinjaLayerUtils.parseColor(content['textColor']) ?? Colors.black;

    // Decoration (Optional background for the timer)
    final width = NinjaLayerUtils.parseSize(style['width']);
    final height = NinjaLayerUtils.parseSize(style['height']);
    final bgColor = NinjaLayerUtils.parseColor(style['backgroundColor']);
    final padding = NinjaLayerUtils.parsePadding(style['padding']);
    final radius = NinjaLayerUtils.parseDouble(style['borderRadius']) ?? 0;

    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: bgColor != null 
          ? BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(radius),
              boxShadow: NinjaLayerUtils.parseShadows(style['boxShadow']),
            )
          : null,
      alignment: Alignment.center,
      child: Text(
        timeString,
        style: TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: textColor,
            fontFamily: 'RobotoMono', // Monospace usually looks better for timers
            fontFeatures: const [FontFeature.tabularFigures()], // Fixed width numbers
          ),
      ),
    );
  }
}
