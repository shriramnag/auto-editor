import 'package:flutter/material.dart';

/// A color-grading filter: [matrix] drives the live preview (ColorFilter.matrix),
/// [ffmpegFilter] is the equivalent ffmpeg video filter used at export time.
class FilterDef {
  final String id;
  final String name;
  final List<double> matrix; // 4x5 color matrix (20 values)
  final Color swatch;
  final String ffmpegFilter; // '' = no filter

  FilterDef({
    required this.id,
    required this.name,
    required this.matrix,
    required this.swatch,
    required this.ffmpegFilter,
  });
}

final List<double> _identity = [
  1, 0, 0, 0, 0, //
  0, 1, 0, 0, 0, //
  0, 0, 1, 0, 0, //
  0, 0, 0, 1, 0,
];

final List<FilterDef> kFilterCatalog = [
  FilterDef(
    id: 'none',
    name: 'Original',
    matrix: _identity,
    swatch: Colors.white,
    ffmpegFilter: '',
  ),
  FilterDef(
    id: 'bw',
    name: 'B&W',
    matrix: [
      0.2126, 0.7152, 0.0722, 0, 0, //
      0.2126, 0.7152, 0.0722, 0, 0, //
      0.2126, 0.7152, 0.0722, 0, 0, //
      0, 0, 0, 1, 0,
    ],
    swatch: Colors.grey,
    ffmpegFilter: 'hue=s=0',
  ),
  FilterDef(
    id: 'vintage',
    name: 'Vintage',
    matrix: [
      0.393, 0.769, 0.189, 0, 0, //
      0.349, 0.686, 0.168, 0, 0, //
      0.272, 0.534, 0.131, 0, 0, //
      0, 0, 0, 1, 0,
    ],
    swatch: const Color(0xFFB08B5A),
    ffmpegFilter: 'curves=preset=vintage',
  ),
  FilterDef(
    id: 'warm',
    name: 'Warm',
    matrix: [
      1.15, 0, 0, 0, 8, //
      0, 1.05, 0, 0, 3, //
      0, 0, 0.80, 0, -12, //
      0, 0, 0, 1, 0,
    ],
    swatch: const Color(0xFFFFA552),
    ffmpegFilter: 'colorbalance=rm=.20:bm=-.20',
  ),
  FilterDef(
    id: 'cool',
    name: 'Cool',
    matrix: [
      0.85, 0, 0, 0, -10, //
      0, 1.0, 0, 0, 0, //
      0, 0, 1.25, 0, 15, //
      0, 0, 0, 1, 0,
    ],
    swatch: const Color(0xFF4FC3F7),
    ffmpegFilter: 'colorbalance=bm=.20:rm=-.15',
  ),
  FilterDef(
    id: 'cyberpunk',
    name: 'Cyberpunk',
    matrix: [
      1.35, -0.15, 0.25, 0, -25, //
      -0.05, 1.05, 0.10, 0, -10, //
      0.20, -0.05, 1.45, 0, 10, //
      0, 0, 0, 1, 0,
    ],
    swatch: const Color(0xFFE040FB),
    ffmpegFilter: 'curves=preset=cross_process,eq=saturation=1.5',
  ),
  FilterDef(
    id: 'faded',
    name: 'Faded',
    matrix: [
      0.9, 0.05, 0.05, 0, 25, //
      0.05, 0.9, 0.05, 0, 20, //
      0.05, 0.05, 0.8, 0, 15, //
      0, 0, 0, 1, 0,
    ],
    swatch: const Color(0xFFD7CCC8),
    ffmpegFilter: 'eq=contrast=0.85:brightness=0.05:saturation=0.8',
  ),
  FilterDef(
    id: 'bluehour',
    name: 'Blue Hour',
    matrix: [
      0.70, 0, 0.10, 0, -20, //
      0, 0.75, 0.15, 0, -15, //
      0.10, 0.10, 1.05, 0, 5, //
      0, 0, 0, 1, 0,
    ],
    swatch: const Color(0xFF1A237E),
    ffmpegFilter: 'colorbalance=bs=.3:bm=.2,eq=brightness=-0.05',
  ),
];

/// A toggle-able overlay effect. [ffmpegFilter] is baked into the export
/// filter graph whenever the effect is active on a clip.
class EffectDef {
  final String id;
  final String name;
  final IconData icon;
  final String ffmpegFilter;

  EffectDef({
    required this.id,
    required this.name,
    required this.icon,
    required this.ffmpegFilter,
  });
}

final List<EffectDef> kEffectCatalog = [
  EffectDef(
    id: 'vignette',
    name: 'Vignette',
    icon: Icons.vignette,
    ffmpegFilter: 'vignette=PI/4',
  ),
  EffectDef(
    id: 'grain',
    name: 'Grain',
    icon: Icons.grain,
    ffmpegFilter: 'noise=alls=20:allf=t+u',
  ),
  EffectDef(
    id: 'blur',
    name: 'Blur',
    icon: Icons.blur_on,
    ffmpegFilter: 'gblur=sigma=6',
  ),
  EffectDef(
    id: 'glitch',
    name: 'RGB Glitch',
    icon: Icons.broken_image,
    ffmpegFilter: 'rgbashift=rh=6:bh=-6',
  ),
];

/// A transition placed between two consecutive clips. [xfadeName] is the
/// exact ffmpeg `xfade` transition name used to bake it into the export.
class TransitionDef {
  final String id;
  final String name;
  final String xfadeName;

  TransitionDef({
    required this.id,
    required this.name,
    required this.xfadeName,
  });
}

final List<TransitionDef> kTransitionCatalog = [
  TransitionDef(id: 'fade', name: 'Fade', xfadeName: 'fade'),
  TransitionDef(id: 'slideleft', name: 'Slide Left', xfadeName: 'slideleft'),
  TransitionDef(id: 'zoomin', name: 'Zoom In', xfadeName: 'zoomin'),
  TransitionDef(id: 'circleopen', name: 'Circle Open', xfadeName: 'circleopen'),
  TransitionDef(id: 'dissolve', name: 'Dissolve', xfadeName: 'dissolve'),
  TransitionDef(id: 'pixelize', name: 'Pixelize', xfadeName: 'pixelize'),
];

/// Live-preview color matrix helpers for the Adjustment sliders
/// (brightness / contrast / saturation). These are combined with the
/// selected filter's matrix by nesting ColorFiltered widgets.
ColorFilter brightnessContrastFilter(double brightness, double contrast) {
  final b = brightness * 255;
  final t = (1 - contrast) * 127.5;
  return ColorFilter.matrix([
    contrast, 0, 0, 0, b + t, //
    0, contrast, 0, 0, b + t, //
    0, 0, contrast, 0, b + t, //
    0, 0, 0, 1, 0,
  ]);
}

ColorFilter saturationFilter(double saturation) {
  const lumR = 0.3086, lumG = 0.6094, lumB = 0.0820;
  final sr = (1 - saturation) * lumR;
  final sg = (1 - saturation) * lumG;
  final sb = (1 - saturation) * lumB;
  return ColorFilter.matrix([
    sr + saturation, sg, sb, 0, 0, //
    sr, sg + saturation, sb, 0, 0, //
    sr, sg, sb + saturation, 0, 0, //
    0, 0, 0, 1, 0,
  ]);
}
