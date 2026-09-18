import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import 'catalog.dart';
import 'export_service.dart';
import 'models.dart';

enum EditorTool { none, trim, speed, volume, text, filters, effects, transitions, adjust }

class _ToolBtn {
  final EditorTool tool;
  final IconData icon;
  final String label;
  _ToolBtn(this.tool, this.icon, this.label);
}

class VideoEditorHome extends StatefulWidget {
  const VideoEditorHome({super.key});

  @override
  State<VideoEditorHome> createState() => _VideoEditorHomeState();
}

class _VideoEditorHomeState extends State<VideoEditorHome> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _textCtrl = TextEditingController();

  final List<EditClip> clips = [];
  int currentIndex = -1;
  VideoPlayerController? controller;

  EditorTool activeTool = EditorTool.none;
  final Map<int, String> transitionAfterClip = {}; // clip index i -> transition between i and i+1

  bool isExporting = false;
  Timer? _grainTimer;
  int _grainSeed = 0;
  Size previewSize = Size.zero;

  EditClip get currentClip => clips[currentIndex];

  @override
  void initState() {
    super.initState();
    _grainTimer = Timer.periodic(const Duration(milliseconds: 140), (_) {
      if (mounted && currentIndex != -1 && currentClip.effectIds.contains('grain')) {
        setState(() => _grainSeed++);
      }
    });
  }

  @override
  void dispose() {
    _grainTimer?.cancel();
    controller?.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- data --

  Future<void> _pickVideo() async {
    final XFile? file = await _picker.pickVideo(source: ImageSource.gallery);
    if (file == null) return;
    final vFile = File(file.path);
    final probe = VideoPlayerController.file(vFile);
    await probe.initialize();
    final duration = probe.value.duration;
    await probe.dispose();

    setState(() {
      clips.add(EditClip(file: vFile, duration: duration));
    });
    await _selectClip(clips.length - 1);
  }

  Future<void> _selectClip(int index) async {
    final old = controller;
    final clip = clips[index];
    final newCtrl = VideoPlayerController.file(clip.file);
    await newCtrl.initialize();
    await newCtrl.setPlaybackSpeed(clip.speed);
    await newCtrl.setVolume(clip.muted ? 0 : clip.volume);
    await newCtrl.seekTo(clip.trimStart);
    newCtrl.addListener(() {
      if (mounted) setState(() {});
    });
    setState(() {
      currentIndex = index;
      controller = newCtrl;
      activeTool = EditorTool.none;
    });
    await old?.dispose();
  }

  void _togglePlay() {
    final c = controller;
    if (c == null) return;
    setState(() => c.value.isPlaying ? c.pause() : c.play());
  }

  Future<void> _export() async {
    if (clips.isEmpty) return;
    setState(() => isExporting = true);
    final path = await ExportService.export(
      clips: clips,
      transitionAfterClip: transitionAfterClip,
    );
    if (!mounted) return;
    setState(() => isExporting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          path != null ? 'Export ho gaya:\n$path' : 'Export fail ho gaya, ffmpeg log console mein check karo.',
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    final s = d.inSeconds.abs();
    final m = (s ~/ 60) % 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  // --------------------------------------------------------------- build --

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auto Editor', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          if (clips.isNotEmpty)
            TextButton.icon(
              onPressed: isExporting ? null : _export,
              icon: isExporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent),
                    )
                  : const Icon(Icons.file_download, color: Colors.cyanAccent, size: 18),
              label: Text(
                isExporting ? 'Export ho raha hai' : 'Export',
                style: const TextStyle(color: Colors.cyanAccent),
              ),
            ),
        ],
      ),
      body: clips.isEmpty ? _buildEmptyView() : _buildEditorBody(),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.video_library_outlined, size: 70, color: Colors.cyanAccent),
            const SizedBox(height: 20),
            const Text('वीडियो एडिटर', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('एडिटिंग के लिए मोबाइल गैलरी से वीडियो चुनें', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              onPressed: _pickVideo,
              icon: const Icon(Icons.add),
              label: const Text('वीडियो चुनें', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditorBody() {
    return Column(
      children: [
        Expanded(
          flex: 5,
          child: Container(
            color: Colors.black,
            child: controller != null && controller!.value.isInitialized
                ? LayoutBuilder(
                    builder: (context, constraints) => GestureDetector(
                      onTap: _togglePlay,
                      child: _buildPreviewStack(constraints),
                    ),
                  )
                : const Center(child: CircularProgressIndicator()),
          ),
        ),
        _buildTimeline(),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: activeTool == EditorTool.none ? 0 : 190,
          color: const Color(0xFF1A1A1A),
          child: activeTool == EditorTool.none
              ? null
              : ClipRect(child: SingleChildScrollView(child: _buildActivePanel())),
        ),
        Container(color: const Color(0xFF141414), child: _buildToolbar()),
      ],
    );
  }

  // ------------------------------------------------------------- preview --

  Widget _videoLayer() {
    final ctrl = controller!;
    return AspectRatio(
      aspectRatio: ctrl.value.aspectRatio == 0 ? 16 / 9 : ctrl.value.aspectRatio,
      child: VideoPlayer(ctrl),
    );
  }

  Widget _buildPreviewStack(BoxConstraints constraints) {
    previewSize = constraints.biggest;
    final clip = currentClip;
    final filter = kFilterCatalog.firstWhere(
      (f) => f.id == clip.filterId,
      orElse: () => kFilterCatalog.first,
    );

    Widget base = _videoLayer();

    if (clip.effectIds.contains('blur')) {
      base = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: base,
      );
    }

    if (clip.effectIds.contains('glitch')) {
      base = Stack(
        alignment: Alignment.center,
        children: [
          base,
          Positioned(
            left: -4,
            child: Opacity(
              opacity: 0.55,
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(Colors.redAccent, BlendMode.modulate),
                child: _videoLayer(),
              ),
            ),
          ),
          Positioned(
            left: 4,
            child: Opacity(
              opacity: 0.55,
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(Colors.blueAccent, BlendMode.modulate),
                child: _videoLayer(),
              ),
            ),
          ),
        ],
      );
    }

    final colored = ColorFiltered(
      colorFilter: ColorFilter.matrix(filter.matrix),
      child: ColorFiltered(
        colorFilter: saturationFilter(clip.adjustments.saturation),
        child: ColorFiltered(
          colorFilter: brightnessContrastFilter(clip.adjustments.brightness, clip.adjustments.contrast),
          child: base,
        ),
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        Center(child: colored),
        if (clip.effectIds.contains('vignette'))
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 1.0,
                  colors: [Colors.transparent, Colors.black87],
                  stops: [0.55, 1.0],
                ),
              ),
            ),
          ),
        if (clip.effectIds.contains('grain'))
          IgnorePointer(
            child: Opacity(
              opacity: 0.18,
              child: CustomPaint(painter: GrainPainter(seed: _grainSeed), size: previewSize),
            ),
          ),
        for (final t in clip.textOverlays) _buildDraggableText(t),
        Positioned(
          bottom: 8,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(4)),
            child: Text(
              '${_fmt(controller!.value.position)} / ${_fmt(controller!.value.duration)}',
              style: const TextStyle(fontSize: 12, color: Colors.white),
            ),
          ),
        ),
        if (!controller!.value.isPlaying)
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
              child: const Icon(Icons.play_arrow, size: 44, color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildDraggableText(TextOverlay t) {
    return Positioned(
      left: previewSize.width * t.dx - 40,
      top: previewSize.height * t.dy - 14,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            t.dx = (t.dx + details.delta.dx / previewSize.width).clamp(0.0, 1.0);
            t.dy = (t.dy + details.delta.dy / previewSize.height).clamp(0.0, 1.0);
          });
        },
        child: Text(
          t.text,
          style: TextStyle(
            color: t.color,
            fontSize: t.fontSize,
            fontWeight: FontWeight.bold,
            shadows: const [Shadow(blurRadius: 4, color: Colors.black)],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ timeline --

  Widget _buildTimeline() {
    return SizedBox(
      height: 64,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        children: [
          for (var i = 0; i < clips.length; i++)
            GestureDetector(
              onTap: () => _selectClip(i),
              child: Container(
                width: 70,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: i == currentIndex ? Colors.cyanAccent.withOpacity(0.25) : Colors.white10,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: i == currentIndex ? Colors.cyanAccent : Colors.white24),
                ),
                alignment: Alignment.center,
                child: Text('Clip ${i + 1}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
              ),
            ),
          GestureDetector(
            onTap: _pickVideo,
            child: Container(
              width: 56,
              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(6)),
              alignment: Alignment.center,
              child: const Icon(Icons.add, color: Colors.cyanAccent),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- toolbar --

  Widget _buildToolbar() {
    final tools = [
      _ToolBtn(EditorTool.trim, Icons.content_cut, 'Trim'),
      _ToolBtn(EditorTool.speed, Icons.speed, 'Speed'),
      _ToolBtn(EditorTool.volume, Icons.volume_up, 'Volume'),
      _ToolBtn(EditorTool.text, Icons.title, 'Text'),
      _ToolBtn(EditorTool.filters, Icons.filter_vintage, 'Filters'),
      _ToolBtn(EditorTool.effects, Icons.auto_awesome, 'Effects'),
      _ToolBtn(EditorTool.transitions, Icons.compare_arrows, 'Transitions'),
      _ToolBtn(EditorTool.adjust, Icons.tune, 'Adjust'),
    ];
    return SizedBox(
      height: 78,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: tools.map((t) {
          final active = activeTool == t.tool;
          return InkWell(
            onTap: () => setState(() => activeTool = active ? EditorTool.none : t.tool),
            child: SizedBox(
              width: 72,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(t.icon, color: active ? Colors.cyanAccent : Colors.white70),
                  const SizedBox(height: 4),
                  Text(t.label, style: TextStyle(fontSize: 11, color: active ? Colors.cyanAccent : Colors.white70)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActivePanel() {
    switch (activeTool) {
      case EditorTool.filters:
        return _buildFiltersPanel();
      case EditorTool.effects:
        return _buildEffectsPanel();
      case EditorTool.transitions:
        return _buildTransitionsPanel();
      case EditorTool.adjust:
        return _buildAdjustPanel();
      case EditorTool.text:
        return _buildTextPanel();
      case EditorTool.speed:
        return _buildSpeedPanel();
      case EditorTool.volume:
        return _buildVolumePanel();
      case EditorTool.trim:
        return _buildTrimPanel();
      case EditorTool.none:
        return const SizedBox.shrink();
    }
  }

  // -------------------------------------------------------------- filters --

  Widget _buildFiltersPanel() {
    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        children: kFilterCatalog.map((f) {
          final selected = (currentClip.filterId ?? 'none') == f.id;
          return GestureDetector(
            onTap: () => setState(() => currentClip.filterId = f.id == 'none' ? null : f.id),
            child: Container(
              width: 70,
              margin: const EdgeInsets.only(right: 10),
              child: Column(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: f.swatch,
                      shape: BoxShape.circle,
                      border: Border.all(color: selected ? Colors.cyanAccent : Colors.transparent, width: 3),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    f.name,
                    style: const TextStyle(fontSize: 10, color: Colors.white70),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // -------------------------------------------------------------- effects --

  Widget _buildEffectsPanel() {
    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        children: kEffectCatalog.map((e) {
          final active = currentClip.effectIds.contains(e.id);
          return GestureDetector(
            onTap: () => setState(() {
              if (active) {
                currentClip.effectIds.remove(e.id);
              } else {
                currentClip.effectIds.add(e.id);
              }
            }),
            child: Container(
              width: 74,
              margin: const EdgeInsets.only(right: 10),
              child: Column(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: active ? Colors.cyanAccent.withOpacity(0.25) : Colors.white10,
                      shape: BoxShape.circle,
                      border: Border.all(color: active ? Colors.cyanAccent : Colors.white24, width: 2),
                    ),
                    child: Icon(e.icon, color: active ? Colors.cyanAccent : Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    e.name,
                    style: const TextStyle(fontSize: 10, color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ---------------------------------------------------------- transitions --

  Widget _buildTransitionsPanel() {
    if (clips.length < 2) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'Transition ke liye kam se kam 2 clips add karo (+ timeline se).',
          style: TextStyle(color: Colors.white54),
          textAlign: TextAlign.center,
        ),
      );
    }
    final canApply = currentIndex < clips.length - 1;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            canApply
                ? 'Is clip aur agli clip ke beech transition:'
                : 'Yeh aakhri clip hai, isse aage koi clip nahin.',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ),
        SizedBox(
          height: 90,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            children: kTransitionCatalog.map((t) {
              final selected = transitionAfterClip[currentIndex] == t.id;
              return GestureDetector(
                onTap: canApply
                    ? () {
                        setState(() => transitionAfterClip[currentIndex] = t.id);
                        _previewTransition(t);
                      }
                    : null,
                child: Opacity(
                  opacity: canApply ? 1 : 0.35,
                  child: Container(
                    width: 76,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: selected ? Colors.cyanAccent.withOpacity(0.2) : Colors.white10,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: selected ? Colors.cyanAccent : Colors.white24),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      t.name,
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  void _previewTransition(TransitionDef t) {
    showDialog(
      context: context,
      builder: (_) => _TransitionPreviewDialog(transition: t),
    );
  }

  // ------------------------------------------------------------- adjust --

  Widget _buildAdjustPanel() {
    final adj = currentClip.adjustments;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        children: [
          _slider('Brightness', adj.brightness, -1, 1, (v) => setState(() => adj.brightness = v)),
          _slider('Contrast', adj.contrast, 0, 2, (v) => setState(() => adj.contrast = v)),
          _slider('Saturation', adj.saturation, 0, 2, (v) => setState(() => adj.saturation = v)),
        ],
      ),
    );
  }

  Widget _slider(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(width: 90, child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12))),
        Expanded(
          child: Slider(value: value, min: min, max: max, activeColor: Colors.cyanAccent, onChanged: onChanged),
        ),
      ],
    );
  }

  // --------------------------------------------------------------- text --

  Widget _buildTextPanel() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(hintText: 'Text likho...', hintStyle: TextStyle(color: Colors.white38)),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.cyanAccent),
                onPressed: () {
                  if (_textCtrl.text.trim().isEmpty) return;
                  setState(() {
                    currentClip.textOverlays.add(TextOverlay(text: _textCtrl.text.trim()));
                    _textCtrl.clear();
                  });
                },
              ),
            ],
          ),
          if (currentClip.textOverlays.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: currentClip.textOverlays
                    .map((t) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Chip(
                            label: Text(t.text, style: const TextStyle(fontSize: 11)),
                            onDeleted: () => setState(() => currentClip.textOverlays.remove(t)),
                            backgroundColor: Colors.white12,
                            deleteIconColor: Colors.white70,
                            labelStyle: const TextStyle(color: Colors.white),
                          ),
                        ))
                    .toList(),
              ),
            ),
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('Text ko preview par ungli se drag karke position set karo.',
                style: TextStyle(color: Colors.white38, fontSize: 10)),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- speed --

  Widget _buildSpeedPanel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        children: [
          Text('${currentClip.speed.toStringAsFixed(2)}x',
              style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
          Slider(
            value: currentClip.speed,
            min: 0.5,
            max: 2.0,
            divisions: 15,
            activeColor: Colors.cyanAccent,
            onChanged: (v) {
              setState(() => currentClip.speed = v);
              controller?.setPlaybackSpeed(v);
            },
          ),
          Wrap(
            spacing: 8,
            children: [0.5, 1.0, 1.5, 2.0].map((v) {
              return ActionChip(
                label: Text('${v}x'),
                backgroundColor: Colors.white10,
                labelStyle: const TextStyle(color: Colors.white70),
                onPressed: () {
                  setState(() => currentClip.speed = v);
                  controller?.setPlaybackSpeed(v);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- volume --

  Widget _buildVolumePanel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        children: [
          IconButton(
            icon: Icon(currentClip.muted ? Icons.volume_off : Icons.volume_up, color: Colors.white),
            onPressed: () {
              setState(() => currentClip.muted = !currentClip.muted);
              controller?.setVolume(currentClip.muted ? 0 : currentClip.volume);
            },
          ),
          Expanded(
            child: Slider(
              value: currentClip.volume,
              min: 0,
              max: 1.5,
              activeColor: Colors.cyanAccent,
              onChanged: currentClip.muted
                  ? null
                  : (v) {
                      setState(() => currentClip.volume = v);
                      controller?.setVolume(v);
                    },
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- trim --

  Widget _buildTrimPanel() {
    final dur = currentClip.duration.inMilliseconds.toDouble();
    if (dur <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          Text(
            '${_fmt(currentClip.trimStart)} - ${_fmt(currentClip.trimEnd)}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          RangeSlider(
            values: RangeValues(
              currentClip.trimStart.inMilliseconds.toDouble().clamp(0, dur),
              currentClip.trimEnd.inMilliseconds.toDouble().clamp(0, dur),
            ),
            min: 0,
            max: dur,
            activeColor: Colors.cyanAccent,
            onChanged: (r) {
              setState(() {
                currentClip.trimStart = Duration(milliseconds: r.start.round());
                currentClip.trimEnd = Duration(milliseconds: r.end.round());
              });
              controller?.seekTo(currentClip.trimStart);
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Grain (noise) painter, reused for both the live preview and the dissolve
// transition preview.
class GrainPainter extends CustomPainter {
  final int seed;
  GrainPainter({required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(seed);
    final paint = Paint();
    for (var i = 0; i < 400; i++) {
      final dx = rnd.nextDouble() * size.width;
      final dy = rnd.nextDouble() * size.height;
      paint.color = rnd.nextBool() ? Colors.white : Colors.black;
      canvas.drawCircle(Offset(dx, dy), 0.6, paint);
    }
  }

  @override
  bool shouldRepaint(covariant GrainPainter oldDelegate) => oldDelegate.seed != seed;
}

// ---------------------------------------------------------------------------
// A small looping animation that shows exactly how the selected transition
// will look, using two placeholder clips ("Clip A" / "Clip B").
class _TransitionPreviewDialog extends StatefulWidget {
  final TransitionDef transition;
  const _TransitionPreviewDialog({required this.transition});

  @override
  State<_TransitionPreviewDialog> createState() => _TransitionPreviewDialogState();
}

class _TransitionPreviewDialogState extends State<_TransitionPreviewDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.transition.name,
                style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              width: 220,
              height: 140,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AnimatedBuilder(animation: _c, builder: (context, _) => _buildFrame(_c.value)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Band karo')),
          ],
        ),
      ),
    );
  }

  Widget _buildFrame(double v) {
    const clipA = Color(0xFF26C6DA);
    const clipB = Color(0xFFEF5350);
    switch (widget.transition.id) {
      case 'fade':
        return Stack(children: [
          Container(color: clipA),
          Opacity(opacity: v, child: Container(color: clipB)),
        ]);
      case 'slideleft':
        return Stack(children: [
          Container(color: clipA),
          Transform.translate(offset: Offset(220 * (1 - v), 0), child: Container(color: clipB)),
        ]);
      case 'zoomin':
        return Stack(children: [
          Container(color: clipA),
          Opacity(opacity: v, child: Transform.scale(scale: 0.6 + 0.4 * v, child: Container(color: clipB))),
        ]);
      case 'circleopen':
        return Stack(children: [
          Container(color: clipA),
          ClipPath(clipper: _CircleClipper(v), child: Container(color: clipB)),
        ]);
      case 'dissolve':
        return Stack(children: [
          Container(color: clipA),
          Opacity(
            opacity: v,
            child: CustomPaint(painter: GrainPainter(seed: (v * 100).toInt()), size: const Size(220, 140)),
          ),
          Opacity(opacity: v, child: Container(color: clipB.withOpacity(0.85))),
        ]);
      case 'pixelize':
        return Stack(children: [
          Container(color: clipA),
          Opacity(
            opacity: v,
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 12 * (1 - v), sigmaY: 12 * (1 - v)),
              child: Container(color: clipB),
            ),
          ),
        ]);
      default:
        return Container(color: clipA);
    }
  }
}

class _CircleClipper extends CustomClipper<Path> {
  final double progress;
  _CircleClipper(this.progress);

  @override
  Path getClip(Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.longestSide;
    return Path()..addOval(Rect.fromCircle(center: center, radius: maxRadius * progress));
  }

  @override
  bool shouldReclip(covariant _CircleClipper oldClipper) => oldClipper.progress != progress;
}
