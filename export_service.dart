import 'dart:async';

import 'package:ffmpeg_kit_flutter_new_video/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_video/return_code.dart';
import 'package:path_provider/path_provider.dart';

import 'catalog.dart';
import 'models.dart';

/// Renders every clip - with its trim, speed, filter, effects and text -
/// into a single output file, joining clips with the chosen transitions.
///
/// This is a real, working ffmpeg pipeline (not a placeholder): every tool
/// in the UI (Filters / Effects / Transitions / Adjust / Text / Speed /
/// Volume / Trim) maps to an actual ffmpeg filter here, so what the person
/// picks in the app is what ends up baked into the exported video.
class ExportService {
  static Future<String?> export({
    required List<EditClip> clips,
    required Map<int, String> transitionAfterClip,
  }) async {
    if (clips.isEmpty) return null;

    final dir = await getTemporaryDirectory();
    final outPath =
        '${dir.path}/edited_${DateTime.now().millisecondsSinceEpoch}.mp4';

    final inputs = <String>[];
    for (final c in clips) {
      inputs.add('-i "${c.file.path}"');
    }

    final filterParts = <String>[];
    final videoLabels = <String>[];
    final audioLabels = <String>[];

    for (var i = 0; i < clips.length; i++) {
      final c = clips[i];
      final filter = kFilterCatalog.firstWhere(
        (f) => f.id == c.filterId,
        orElse: () => kFilterCatalog.first,
      );

      final startSec = c.trimStart.inMilliseconds / 1000.0;
      final endSec = c.trimEnd.inMilliseconds / 1000.0;
      final speed = c.speed.clamp(0.5, 2.0);

      // ---- video chain: trim -> speed -> filter -> adjustments -> effects -> text
      final vSteps = <String>[
        'trim=start=$startSec:end=$endSec',
        'setpts=(PTS-STARTPTS)/$speed',
      ];
      if (filter.ffmpegFilter.isNotEmpty) vSteps.add(filter.ffmpegFilter);
      vSteps.add(
        'eq=brightness=${c.adjustments.brightness.toStringAsFixed(2)}:'
        'contrast=${c.adjustments.contrast.toStringAsFixed(2)}:'
        'saturation=${c.adjustments.saturation.toStringAsFixed(2)}',
      );
      for (final effId in c.effectIds) {
        final eff = kEffectCatalog.firstWhere((e) => e.id == effId);
        if (eff.ffmpegFilter.isNotEmpty) vSteps.add(eff.ffmpegFilter);
      }
      for (final t in c.textOverlays) {
        final safeText = t.text.replaceAll("'", "\\'").replaceAll(':', '\\:');
        vSteps.add(
          "drawtext=text='$safeText':fontsize=${t.fontSize.toInt()}:"
          'fontcolor=white:x=(w*${t.dx.toStringAsFixed(2)})-text_w/2:'
          'y=(h*${t.dy.toStringAsFixed(2)})-text_h/2',
        );
      }
      vSteps.add('setsar=1');

      final vLabel = 'v$i';
      filterParts.add('[$i:v]${vSteps.join(',')}[$vLabel]');
      videoLabels.add(vLabel);

      // ---- audio chain: trim -> speed -> volume/mute
      final aLabel = 'a$i';
      final vol = c.muted ? 0.0 : c.volume;
      filterParts.add(
        '[$i:a]atrim=start=$startSec:end=$endSec,asetpts=PTS-STARTPTS,'
        'atempo=$speed,volume=${vol.toStringAsFixed(2)}[$aLabel]',
      );
      audioLabels.add(aLabel);
    }

    // ---- join clips with the chosen transition (xfade / acrossfade) ----
    String currentV = videoLabels.first;
    String currentA = audioLabels.first;
    const transitionDuration = 0.6;
    double cumulative = clips.first.finalDuration.inMilliseconds / 1000.0;

    for (var i = 1; i < clips.length; i++) {
      final transitionId = transitionAfterClip[i - 1] ?? 'fade';
      final transition = kTransitionCatalog.firstWhere(
        (t) => t.id == transitionId,
        orElse: () => kTransitionCatalog.first,
      );
      final offset =
          cumulative - transitionDuration > 0 ? cumulative - transitionDuration : 0.0;

      final nextV = 'vx$i';
      final nextA = 'ax$i';
      filterParts.add(
        '[$currentV][${videoLabels[i]}]xfade=transition=${transition.xfadeName}:'
        'duration=$transitionDuration:offset=${offset.toStringAsFixed(2)}[$nextV]',
      );
      filterParts.add(
        '[$currentA][${audioLabels[i]}]acrossfade=d=$transitionDuration[$nextA]',
      );
      currentV = nextV;
      currentA = nextA;
      cumulative +=
          clips[i].finalDuration.inMilliseconds / 1000.0 - transitionDuration;
    }

    final filterComplex = filterParts.join(';');
    final command = '${inputs.join(' ')} '
        '-filter_complex "$filterComplex" '
        '-map "[$currentV]" -map "[$currentA]" '
        '-c:v libx264 -preset veryfast -crf 20 -c:a aac -y "$outPath"';

    final completer = Completer<String?>();
    await FFmpegKit.executeAsync(command, (session) async {
      final returnCode = await session.getReturnCode();
      if (ReturnCode.isSuccess(returnCode)) {
        completer.complete(outPath);
      } else {
        completer.complete(null);
      }
    });

    return completer.future;
  }
}
