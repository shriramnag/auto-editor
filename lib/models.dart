import 'dart:io';
import 'package:flutter/material.dart';

/// One text overlay drawn on top of a clip's preview / export.
class TextOverlay {
  String text;
  double dx; // 0.0 - 1.0, fraction of preview width
  double dy; // 0.0 - 1.0, fraction of preview height
  double fontSize;
  Color color;

  TextOverlay({
    required this.text,
    this.dx = 0.5,
    this.dy = 0.5,
    this.fontSize = 28,
    this.color = Colors.white,
  });
}

/// Brightness / contrast / saturation values for a clip (the "Adjustment" tool).
class ClipAdjustments {
  double brightness; // -1.0 .. 1.0  (0 = no change)
  double contrast; // 0.0 .. 2.0    (1 = no change)
  double saturation; // 0.0 .. 2.0  (1 = no change)

  ClipAdjustments({
    this.brightness = 0.0,
    this.contrast = 1.0,
    this.saturation = 1.0,
  });
}

/// One clip on the timeline with every edit that has been applied to it.
class EditClip {
  final File file;
  final Duration duration;
  Duration trimStart;
  Duration trimEnd;
  double speed; // 0.5 .. 2.0  (matches ffmpeg atempo's supported range)
  double volume; // 0.0 .. 1.5
  bool muted;
  String? filterId; // key into kFilterCatalog, null = no filter
  final Set<String> effectIds; // keys into kEffectCatalog, can be several
  final List<TextOverlay> textOverlays;
  ClipAdjustments adjustments;

  EditClip({required this.file, required this.duration})
      : trimStart = Duration.zero,
        trimEnd = duration,
        speed = 1.0,
        volume = 1.0,
        muted = false,
        filterId = null,
        effectIds = <String>{},
        textOverlays = <TextOverlay>[],
        adjustments = ClipAdjustments();

  Duration get trimmedDuration => trimEnd - trimStart;

  Duration get finalDuration => Duration(
        milliseconds: (trimmedDuration.inMilliseconds / speed).round(),
      );
}
