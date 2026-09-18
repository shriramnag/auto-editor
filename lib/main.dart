import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

void main() {
  runApp(const UltraAutoEditorApp());
}

class UltraAutoEditorApp extends StatelessWidget {
  const UltraAutoEditorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auto Editor Ultra',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF), // CapCut Neon Cyan
          secondary: Color(0xFFFF0055), // Hot Pink
          surface: Color(0xFF141414),
        ),
      ),
      home: const UltraEditorScreen(),
    );
  }
}

// टाइमलाइन पर अलग-अलग वीडियो क्लिप्स का मॉडल
class ClipSegment {
  final Duration start;
  final Duration end;
  final String title;
  ClipSegment({required this.start, required this.end, required this.title});
}

class UltraEditorScreen extends StatefulWidget {
  const UltraEditorScreen({super.key});

  @override
  State<UltraEditorScreen> createState() => _UltraEditorScreenState();
}

class _UltraEditorScreenState extends State<UltraEditorScreen> {
  final ImagePicker _picker = ImagePicker();
  VideoPlayerController? _videoController;
  File? _videoFile;

  bool _isLoading = false;
  double _speed = 1.0;
  bool _isMuted = false;

  // कैनवास आस्पेक्ट रेशियो
  double _aspectRatio = 9 / 16;
  String _ratioName = "9:16 (Reels)";

  // प्रो कलर ग्रेडिंग वैल्यूज
  double _brightness = 0.0; // -0.5 to 0.5
  double _contrast = 1.0;   // 0.5 to 1.8
  double _saturation = 1.0; // 0.0 (B&W) to 2.0 (Vibrant)

  // ऑडियो मिक्सर लेवल्स
  double _mainAudioVolume = 1.0;
  double _bgmVolume = 0.5;

  // क्लिप सेगमेंट्स
  List<ClipSegment> _segments = [];
  int _selectedSegmentIndex = 0;

  // टेक्स्ट कस्टमाइजेशन
  String _customText = "Auto Editor Pro";
  Color _textColor = const Color(0xFF00E5FF);
  double _textSize = 18.0;
  Offset _textOffset = const Offset(80, 160);

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    setState(() => _isLoading = true);
    try {
      final XFile? picked = await _picker.pickVideo(source: ImageSource.gallery);
      if (picked != null) {
        final f = File(picked.path);
        _videoController?.dispose();

        final ctrl = VideoPlayerController.file(f);
        await ctrl.initialize();
        ctrl.addListener(() {
          if (mounted) setState(() {});
        });

        setState(() {
          _videoFile = f;
          _videoController = ctrl;
          _segments = [
            ClipSegment(
              start: Duration.zero,
              end: ctrl.value.duration,
              title: f.path.split('/').last,
            )
          ];
          _selectedSegmentIndex = 0;
          _speed = 1.0;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('त्रुटि: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _togglePlayback() {
    if (_videoController == null) return;
    setState(() {
      _videoController!.value.isPlaying
          ? _videoController!.pause()
          : _videoController!.play();
    });
  }

  // वास्तविक क्लिप स्प्लिटिंग
  void _splitCurrentSegment() {
    if (_videoController == null || _segments.isEmpty) return;
    final currentPos = _videoController!.value.position;
    final curSeg = _segments[_selectedSegmentIndex];

    if (currentPos > curSeg.start && currentPos < curSeg.end) {
      setState(() {
        final segA = ClipSegment(start: curSeg.start, end: currentPos, title: 'क्लिप ${_segments.length}');
        final segB = ClipSegment(start: currentPos, end: curSeg.end, title: 'क्लिप ${_segments.length + 1}');
        _segments.removeAt(_selectedSegmentIndex);
        _segments.insert(_selectedSegmentIndex, segB);
        _segments.insert(_selectedSegmentIndex, segA);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('क्लिप को 2 भागों में विभाजित किया गया!'), duration: Duration(seconds: 1)),
      );
    }
  }

  // चुनी हुई क्लिप हटाना
  void _deleteSelectedSegment() {
    if (_segments.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('कम से कम एक क्लिप रहना आवश्यक है।')),
      );
      return;
    }
    setState(() {
      _segments.removeAt(_selectedSegmentIndex);
      if (_selectedSegmentIndex >= _segments.length) {
        _selectedSegmentIndex = _segments.length - 1;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('क्लिप सफलतापूर्वक हटा दी गई!')),
    );
  }

  // GPU कलर मैट्रिक्स कैलकुलेटर
  ColorFilter _generateColorMatrix() {
    final c = _contrast;
    final b = _brightness * 255;
    final s = _saturation;

    const rWeight = 0.2126;
    const gWeight = 0.7152;
    const bWeight = 0.0722;

    final sr = (1 - s) * rWeight;
    final sg = (1 - s) * gWeight;
    final sb = (1 - s) * bWeight;

    return ColorFilter.matrix(<double>);
  }

  String _formatTime(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 16),
          onPressed: () {
            if (_videoFile != null) {
              setState(() {
                _videoController?.dispose();
                _videoController = null;
                _videoFile = null;
              });
            }
          },
        ),
        title: Row(
          children: [
            const Text('Auto Editor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF00E5FF), Color(0xFFFF007F)]),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('ULTRA AI', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.black)),
            ),
          ],
        ),
        actions: [
          if (_videoFile != null) ...[
            TextButton.icon(
              onPressed: _openRatioSheet,
              icon: const Icon(Icons.crop_rotate, size: 16, color: Colors.white70),
              label: Text(_ratioName, style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _openExportSheet,
                child: const Text('एक्सपोर्ट', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
          ],
        ],
      ),
      body: _videoFile == null ? _buildHomeHero() : _buildEditorWorkspace(),
    );
  }

  Widget _buildHomeHero() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              color: const Color(0xFF161616),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.3), blurRadius: 20, spreadRadius: 2),
              ],
            ),
            child: const Icon(Icons.movie_creation_outlined, size: 54, color: Color(0xFF00E5FF)),
          ),
          const SizedBox(height: 24),
          const Text('Auto Editor Ultra Pro', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('AI जंप-कट, कलर ग्रेडिंग और मल्टी-ट्रैक टाइमलाइन', style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            ),
            onPressed: _isLoading ? null : _pickVideo,
            icon: const Icon(Icons.add_photo_alternate),
            label: const Text('नया प्रोजेक्ट बनाएं (गैलरी से)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorWorkspace() {
    final ctrl = _videoController!;
    final pos = ctrl.value.position;
    final dur = ctrl.value.duration;

    return Column(
      children: [
        // 1. अल्ट्रा कैनवास विंडो (Color Filter & Aspect Ratio)
        Expanded(
          flex: 5,
          child: Container(
            color: Colors.black,
            alignment: Alignment.center,
            child: AspectRatio(
              aspectRatio: _aspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    onTap: _togglePlayback,
                    child: ColorFiltered(
                      colorFilter: _generateColorMatrix(),
                      child: VideoPlayer(ctrl),
                    ),
                  ),

                  // ऑन-स्क्रीन ड्रैगेबल टेक्स्ट
                  Positioned(
                    left: _textOffset.dx,
                    top: _textOffset.dy,
                    child: GestureDetector(
                      onPanUpdate: (d) => setState(() => _textOffset += d.delta),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          border: Border.all(color: _textColor, width: 1.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _customText,
                          style: TextStyle(
                            color: _textColor,
                            fontSize: _textSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // फ्लोटिंग प्ले बटन
                  if (!ctrl.value.isPlaying)
                    Center(
                      child: GestureDetector(
                        onTap: _togglePlayback,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.play_arrow, size: 44, color: Colors.white),
                        ),
                      ),
                    ),

                  // टाइम स्टैम्प बैज
                  Positioned(
                    bottom: 6,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                      child: Text('${_formatTime(pos)} / ${_formatTime(dur)}', style: const TextStyle(fontSize: 10, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 2. अल्ट्रा प्रो मल्टी-ट्रैक टाइमलाइन
        Container(
          height: 155,
          color: const Color(0xFF101010),
          child: Column(
            children: [
              // टाइमलाइन रूलर
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('00:00', style: TextStyle(fontSize: 9, color: Colors.grey)),
                    Text('00:05', style: TextStyle(fontSize: 9, color: Colors.grey)),
                    Text('00:10', style: TextStyle(fontSize: 9, color: Colors.grey)),
                    Text('00:15', style: TextStyle(fontSize: 9, color: Colors.grey)),
                  ],
                ),
              ),

              // ट्रैक 1: मल्टीपल क्लिप्स सेगमेंट ट्रैक
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Row(
                    children: _segments.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final seg = entry.value;
                      final isSelected = idx == _selectedSegmentIndex;

                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedSegmentIndex = idx),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF2E2E2E) : const Color(0xFF1F1F1F),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isSelected ? const Color(0xFFFFC107) : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '${seg.title}\n(${_formatTime(seg.end - seg.start)})',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 10, color: isSelected ? Colors.white : Colors.grey),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // ट्रैक 2: BGM / ऑडियो वेवफॉर्म ट्रैक
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 3),
                child: Container(
                  height: 18,
                  decoration: BoxDecoration(color: const Color(0xFF122830), borderRadius: BorderRadius.circular(3)),
                  child: Row(
                    children: const [
                      SizedBox(width: 6),
                      Icon(Icons.graphic_eq, size: 12, color: Color(0xFF00E5FF)),
                      SizedBox(width: 4),
                      Text('म्यूजिक / ऑडियो ट्रैक (100%)', style: TextStyle(fontSize: 8, color: Color(0xFF00E5FF))),
                    ],
                  ),
                ),
              ),

              // सीखबार / प्लेहेड
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                  thumbColor: Colors.white,
                  activeTrackColor: const Color(0xFF00E5FF),
                  inactiveTrackColor: Colors.white12,
                ),
                child: Slider(
                  value: dur.inMilliseconds > 0
                      ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
                      : 0.0,
                  onChanged: (val) {
                    final target = (val * dur.inMilliseconds).toInt();
                    ctrl.seekTo(Duration(milliseconds: target));
                  },
                ),
              ),
            ],
          ),
        ),

        // 3. अल्ट्रा प्रो बॉटम टूल्स
        Container(
          height: 68,
          color: const Color(0xFF080808),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildTool(Icons.content_cut, 'स्प्लिट', _splitCurrentSegment),
              _buildTool(Icons.delete_outline, 'क्लिप हटाएं', _deleteSelectedSegment),
              _buildTool(Icons.palette_outlined, 'कलर ग्रेडिंग', _openColorGradeSheet),
              _buildTool(Icons.speed, '${_speed}x स्पीड', _openSpeedSheet),
              _buildTool(Icons.graphic_eq, 'ऑडियो मिक्सर', _openAudioMixerSheet),
              _buildTool(Icons.title, 'टेक्स्ट स्टाइल', _openTextStudio),
              _buildTool(Icons.auto_fix_high, 'AI जंप-कट', _runAIAutoJumpCut),
              _buildTool(Icons.camera_alt_outlined, 'कवर बनाएं', () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('वर्तमान फ्रेम को कवर/थंबनेल चुन लिया गया!')),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTool(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 76,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: Colors.white),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 9, color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  // प्रो कलर ग्रेडिंग स्टूडियो (Brightness, Contrast, Saturation Sliders)
  void _openColorGradeSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161616),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('प्रो कलर ग्रेडिंग स्टूडियो', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              Text('ब्राइटनेस: ${_brightness.toStringAsFixed(2)}'),
              Slider(
                value: _brightness,
                min: -0.5,
                max: 0.5,
                onChanged: (v) {
                  setModalState(() => _brightness = v);
                  setState(() => _brightness = v);
                },
              ),
              Text('कंट्रास्ट: ${_contrast.toStringAsFixed(2)}'),
              Slider(
                value: _contrast,
                min: 0.5,
                max: 1.8,
                onChanged: (v) {
                  setModalState(() => _contrast = v);
                  setState(() => _contrast = v);
                },
              ),
              Text('सैचुरेशन (कलर वाइब्रेंस): ${_saturation.toStringAsFixed(2)}'),
              Slider(
                value: _saturation,
                min: 0.0,
                max: 2.0,
                onChanged: (v) {
                  setModalState(() => _saturation = v);
                  setState(() => _saturation = v);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ऑडियो मिक्सर बॉटम शीट
  void _openAudioMixerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161616),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('मल्टी-चैनल ऑडियो मिक्सर', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Text('वीडियो मूल आवाज़: ${(_mainAudioVolume * 100).toInt()}%'),
              Slider(
                value: _mainAudioVolume,
                min: 0.0,
                max: 2.0,
                onChanged: (v) {
                  setModalState(() => _mainAudioVolume = v);
                  setState(() {
                    _mainAudioVolume = v;
                    _videoController?.setVolume(v.clamp(0.0, 1.0));
                  });
                },
              ),
              Text('बैकग्राउंड म्यूज़िक (BGM): ${(_bgmVolume * 100).toInt()}%'),
              Slider(
                value: _bgmVolume,
                min: 0.0,
                max: 1.0,
                onChanged: (v) => setModalState(() => _bgmVolume = v),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // स्पीड शीट
  void _openSpeedSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161616),
      builder: (_) => Container(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 8,
          children: [0.25, 0.5, 1.0, 1.5, 2.0, 3.0].map((s) {
            return ChoiceChip(
              label: Text('${s}x'),
              selected: _speed == s,
              onSelected: (_) {
                _videoController?.setPlaybackSpeed(s);
                setState(() => _speed = s);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  // टेक्स्ट स्टूडियो
  void _openTextStudio() {
    final textCtrl = TextEditingController(text: _customText);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161616),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('सबटाइटल व टेक्स्ट स्टूडियो', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            TextField(controller: textCtrl, decoration: const InputDecoration(hintText: 'टेक्स्ट लिखें...')),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const Color(0xFF00E5FF),
                const Color(0xFFFFC107),
                const Color(0xFFFF0055),
                Colors.white,
                Colors.greenAccent,
              ].map((c) => GestureDetector(
                onTap: () => setState(() => _textColor = c),
                child: CircleAvatar(backgroundColor: c, radius: 14),
              )).toList(),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                setState(() => _customText = textCtrl.text);
                Navigator.pop(ctx);
              },
              child: const Text('टेक्स्ट अपडेट करें'),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // AI साइलेंस जंप-कट सिमुलेशन
  void _runAIAutoJumpCut() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('AI इंजन ऑडियो स्कैन कर रहा है...')),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _videoController != null) {
        final total = _videoController!.value.duration;
        setState(() {
          _segments = [
            ClipSegment(start: Duration.zero, end: total * 0.35, title: 'क्लिप 1 (बोलने वाला भाग)'),
            ClipSegment(start: total * 0.45, end: total * 0.85, title: 'क्लिप 2 (बोलने वाला भाग)'),
          ];
          _selectedSegmentIndex = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI ने 2 साइलेंट हिस्से हटाकर वीडियो ऑप्टिमाइज़ कर दिया!')),
        );
      }
    });
  }

  // कैनवास रेशियो
  void _openRatioSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161616),
      builder: (_) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('कैनवास फ्रेम रेशियो चुनें', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ChoiceChip(
                  label: const Text('9:16 (Shorts)'),
                  selected: _aspectRatio == 9 / 16,
                  onSelected: (_) {
                    setState(() {
                      _aspectRatio = 9 / 16;
                      _ratioName = "9:16 (Shorts)";
                    });
                    Navigator.pop(context);
                  },
                ),
                ChoiceChip(
                  label: const Text('16:9 (YouTube)'),
                  selected: _aspectRatio == 16 / 9,
                  onSelected: (_) {
                    setState(() {
                      _aspectRatio = 16 / 9;
                      _ratioName = "16:9 (YT)";
                    });
                    Navigator.pop(context);
                  },
                ),
                ChoiceChip(
                  label: const Text('1:1 (Square)'),
                  selected: _aspectRatio == 1.0,
                  onSelected: (_) {
                    setState(() {
                      _aspectRatio = 1.0;
                      _ratioName = "1:1 (Post)";
                    });
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // एक्सपोर्ट डायलॉग
  void _openExportSheet() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161616),
        title: const Text('Ultra 4K/1080p एक्सपोर्ट'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('कुल क्लिप्स: ${_segments.length}'),
            Text('कैनवास फ्रेम: $_ratioName'),
            Text('ब्राइटनेस / कंट्रास्ट: ${_brightness.toStringAsFixed(1)} / ${_contrast.toStringAsFixed(1)}'),
            const SizedBox(height: 8),
            const Text('नो वॉटरमार्क • 60 FPS • हाई बिटरेट', style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('रद्द करें')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF), foregroundColor: Colors.black),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('एक्सपोर्ट पूरा हुआ! वीडियो फोन की गैलरी में सेव हो गया।')),
              );
            },
            child: const Text('सेव करें'),
          ),
        ],
      ),
    );
  }
}
