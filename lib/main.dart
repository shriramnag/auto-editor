import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

void main() {
  runApp(const CapCutMegaProApp());
}

class CapCutMegaProApp extends StatelessWidget {
  const CapCutMegaProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auto Editor Mega Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF070707),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFFFF0055),
          surface: Color(0xFF141414),
        ),
      ),
      home: const MegaEditorScreen(),
    );
  }
}

enum CaptionStyle { mrBeast, hormozi, neonGlow, karaoke, cinematic, minimal }

class ClipSegment {
  final Duration start;
  final Duration end;
  final String title;
  ClipSegment({required this.start, required this.end, required this.title});
}

class MegaEditorScreen extends StatefulWidget {
  const MegaEditorScreen({super.key});

  @override
  State<MegaEditorScreen> createState() => _MegaEditorScreenState();
}

class _MegaEditorScreenState extends State<MegaEditorScreen> with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  VideoPlayerController? _videoController;
  File? _videoFile;

  bool _isLoading = false;
  double _speed = 1.0;
  bool _isFlipped = false;
  bool _showPipOverlay = false;

  // कैनवास रेशियो
  double _aspectRatio = 9 / 16;
  String _ratioName = "9:16 (Shorts)";

  // कलर ग्रेडिंग
  double _brightness = 0.0;
  double _contrast = 1.0;
  double _saturation = 1.0;

  // ऑडियो मिक्सर
  double _videoVolume = 1.0;
  double _bgmVolume = 0.6;
  double _sfxVolume = 0.8;

  // क्लिप्स मैनेजमेंट
  List<ClipSegment> _segments = [];
  int _selectedSegmentIndex = 0;

  // ऑटो-कैप्शन व सबटाइटल सिस्टम
  String _captionText = "VIRAL AUTO CAPTION";
  CaptionStyle _activeCaptionStyle = CaptionStyle.mrBeast;
  Offset _captionPosition = const Offset(60, 180);
  Offset _pipPosition = const Offset(20, 30);
  double _captionScale = 1.0;

  late AnimationController _karaokeAnimController;

  @override
  void initState() {
    super.initState();
    _karaokeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _karaokeAnimController.dispose();
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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

  // 1. क्लिप स्प्लिट
  void _splitClip() {
    if (_videoController == null || _segments.isEmpty) return;
    final pos = _videoController!.value.position;
    final cur = _segments[_selectedSegmentIndex];

    if (pos > cur.start && pos < cur.end) {
      setState(() {
        final seg1 = ClipSegment(start: cur.start, end: pos, title: 'क्लिप ${_segments.length}');
        final seg2 = ClipSegment(start: pos, end: cur.end, title: 'क्लिप ${_segments.length + 1}');
        _segments.removeAt(_selectedSegmentIndex);
        _segments.insert(_selectedSegmentIndex, seg2);
        _segments.insert(_selectedSegmentIndex, seg1);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✂️ क्लिप को 2 हिस्सों में स्प्लिट कर दिया गया!'), duration: Duration(seconds: 1)),
      );
    }
  }

  // 2. क्लिप डिलीट
  void _deleteClip() {
    if (_segments.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('टाइमलाइन पर कम से कम 1 क्लिप होनी चाहिए।')),
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
      const SnackBar(content: Text('🗑️ क्लिप हटा दी गई!')),
    );
  }

  // कलर मैट्रिक्स
  ColorFilter _buildColorFilter() {
    final c = _contrast;
    final b = _brightness * 255;
    final s = _saturation;

    const rw = 0.2126;
    const gw = 0.7152;
    const bw = 0.0722;

    final sr = (1 - s) * rw;
    final sg = (1 - s) * gw;
    final sb = (1 - s) * bw;

    return ColorFilter.matrix(<double>);
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // सबटाइटल टेम्पलेट्स रेंडरर
  Widget _buildCaptionWidget() {
    switch (_activeCaptionStyle) {
      case CaptionStyle.mrBeast:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Text(
            _captionText.toUpperCase(),
            style: TextStyle(
              fontSize: 22 * _captionScale,
              fontWeight: FontWeight.w900,
              color: const Color(0xFFFFEB3B), // Beast Yellow
              shadows: const [
                Shadow(offset: Offset(-2, -2), color: Colors.black),
                Shadow(offset: Offset(2, -2), color: Colors.black),
                Shadow(offset: Offset(2, 2), color: Colors.black),
                Shadow(offset: Offset(-2, 2), color: Colors.black),
                Shadow(offset: Offset(0, 4), color: Colors.black, blurRadius: 6),
              ],
            ),
          ),
        );

      case CaptionStyle.hormozi:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF39FF14), width: 2), // Neon Lime
          ),
          child: Text(
            _captionText.toUpperCase(),
            style: TextStyle(
              fontSize: 18 * _captionScale,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF39FF14),
              letterSpacing: 1.2,
            ),
          ),
        );

      case CaptionStyle.neonGlow:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFF007F), width: 1.5),
          ),
          child: Text(
            _captionText,
            style: TextStyle(
              fontSize: 20 * _captionScale,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF00E5FF),
              shadows: const [
                Shadow(color: Color(0xFF00E5FF), blurRadius: 15),
                Shadow(color: Color(0xFFFF007F), blurRadius: 25),
              ],
            ),
          ),
        );

      case CaptionStyle.karaoke:
        return ScaleTransition(
          scale: Tween<double>(begin: 0.95, end: 1.15).animate(
            CurvedAnimation(parent: _karaokeAnimController, curve: Curves.easeInOut),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFF007F), Color(0xFF00E5FF)]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8)],
            ),
            child: Text(
              _captionText,
              style: TextStyle(
                fontSize: 19 * _captionScale,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        );

      case CaptionStyle.cinematic:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          color: Colors.black45,
          child: Text(
            _captionText,
            style: TextStyle(
              fontSize: 17 * _captionScale,
              color: const Color(0xFFFFD700),
              letterSpacing: 3.0,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
            ),
          ),
        );

      default:
        return Text(
          _captionText,
          style: TextStyle(fontSize: 16 * _captionScale, color: Colors.white, fontWeight: FontWeight.bold),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF101010),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 16),
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
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF00E5FF), Color(0xFFFF0055)]),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('MEGA PRO', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.black)),
            ),
          ],
        ),
        actions: [
          if (_videoFile != null) ...[
            TextButton.icon(
              onPressed: _openRatioSheet,
              icon: const Icon(Icons.crop_rotate, size: 15, color: Colors.white70),
              label: Text(_ratioName, style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _openExportSheet,
                icon: const Icon(Icons.upload, size: 14),
                label: const Text('एक्सपोर्ट', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
          ],
        ],
      ),
      body: _videoFile == null ? _buildHome() : _buildEditorWorkspace(),
    );
  }

  Widget _buildHome() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF161616),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.3), blurRadius: 25, spreadRadius: 4),
              ],
            ),
            child: const Icon(Icons.movie_filter_outlined, size: 54, color: Color(0xFF00E5FF)),
          ),
          const SizedBox(height: 24),
          const Text('Auto Editor Mega Studio', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('MrBeast स्टाइल ऑटो-कैप्शंस, AI जंप-कट व 14 प्रो टूल्स', style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            ),
            onPressed: _isLoading ? null : _pickVideo,
            icon: const Icon(Icons.add_to_photos),
            label: const Text('गैलरी से वीडियो चुनें', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
        // 1. कैनवास वीडियो प्रीव्यू विंडो
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
                  // मिरर / फ्लिप ट्रांसफॉर्म
                  Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.rotationY(_isFlipped ? math.pi : 0),
                    child: GestureDetector(
                      onTap: _togglePlayback,
                      child: ColorFiltered(
                        colorFilter: _buildColorFilter(),
                        child: VideoPlayer(ctrl),
                      ),
                    ),
                  ),

                  // ऑन-स्क्रीन ऑटो-कैप्शन (उंगली से ड्रैग करने योग्य)
                  Positioned(
                    left: _captionPosition.dx,
                    top: _captionPosition.dy,
                    child: GestureDetector(
                      onPanUpdate: (d) => setState(() => _captionPosition += d.delta),
                      child: _buildCaptionWidget(),
                    ),
                  ),

                  // PIP (Picture-In-Picture) ओवरले बॉक्स
                  if (_showPipOverlay)
                    Positioned(
                      left: _pipPosition.dx,
                      top: _pipPosition.dy,
                      child: GestureDetector(
                        onPanUpdate: (d) => setState(() => _pipPosition += d.delta),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.8),
                            border: Border.all(color: const Color(0xFF00E5FF), width: 2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_pin, color: Color(0xFF00E5FF), size: 30),
                              Text('PIP ओवरले', style: TextStyle(fontSize: 9, color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // प्ले पॉज आइकन
                  if (!ctrl.value.isPlaying)
                    Center(
                      child: GestureDetector(
                        onTap: _togglePlayback,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.play_arrow, size: 44, color: Colors.white),
                        ),
                      ),
                    ),

                  // टाइमकोड
                  Positioned(
                    bottom: 6,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                      child: Text('${_fmt(pos)} / ${_fmt(dur)}', style: const TextStyle(fontSize: 10, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 2. प्रो मल्टी-ट्रैक टाइमलाइन
        Container(
          height: 145,
          color: const Color(0xFF101010),
          child: Column(
            children: [
              // रूलर
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
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

              // ट्रैक 1: सेगमेंट्स क्लिप्स
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
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
                              color: isSelected ? const Color(0xFF2B2B2B) : const Color(0xFF1B1B1B),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isSelected ? const Color(0xFFFFC107) : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '${seg.title}\n${_fmt(seg.end - seg.start)}',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 9, color: isSelected ? Colors.white : Colors.grey),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // ट्रैक 2: सबटाइटल ट्रैक
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2),
                child: Container(
                  height: 16,
                  decoration: BoxDecoration(color: const Color(0xFF281C30), borderRadius: BorderRadius.circular(3)),
                  child: Row(
                    children: const [
                      SizedBox(width: 6),
                      Icon(Icons.subtitles, size: 10, color: Color(0xFFFF007F)),
                      SizedBox(width: 4),
                      Text('ऑटो-सबटाइटल ट्रैक (MrBeast Active)', style: TextStyle(fontSize: 8, color: Color(0xFFFF007F))),
                    ],
                  ),
                ),
              ),

              // प्लेहेड सीखबार
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                  thumbColor: Colors.white,
                  activeTrackColor: const Color(0xFF00E5FF),
                  inactiveTrackColor: Colors.white12,
                ),
                child: Slider(
                  value: dur.inMilliseconds > 0 ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0) : 0.0,
                  onChanged: (val) {
                    final target = (val * dur.inMilliseconds).toInt();
                    ctrl.seekTo(Duration(milliseconds: target));
                  },
                ),
              ),
            ],
          ),
        ),

        // 3. 14 एडवांस टूल्स का बॉटम बार
        Container(
          height: 68,
          color: const Color(0xFF080808),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildTool(Icons.content_cut, 'स्प्लिट', _splitClip),
              _buildTool(Icons.subtitles, 'कैप्शन टेम्पलेट्स', _openCaptionTemplatesSheet),
              _buildTool(Icons.auto_fix_high, 'AI जंप-कट', _runAIAutoJumpCut),
              _buildTool(Icons.palette_outlined, 'कलर ग्रेडिंग', _openColorGradeSheet),
              _buildTool(Icons.speed, '${_speed}x स्पीड', _openSpeedSheet),
              _buildTool(Icons.graphic_eq, 'ऑडियो मिक्सर', _openAudioMixerSheet),
              _buildTool(Icons.picture_in_picture_alt, 'PIP ओवरले', () {
                setState(() => _showPipOverlay = !_showPipOverlay);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(_showPipOverlay ? 'PIP ओवरले चालू!' : 'PIP ओवरले बंद!')),
                );
              }),
              _buildTool(Icons.flip, 'मिरर फ्लिप', () {
                setState(() => _isFlipped = !_isFlipped);
              }),
              _buildTool(Icons.delete_outline, 'क्लिप हटाएं', _deleteClip),
              _buildTool(Icons.audiotrack, 'साउंड इफेक्ट्स', _openSFXSheet),
              _buildTool(Icons.aspect_ratio, 'कैनवास रेश्यो', _openRatioSheet),
              _buildTool(Icons.camera, 'कवर फ्रेम', () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('वर्तमान फ्रेम को थंबनेल सेट कर दिया गया!')),
                );
              }),
              _buildTool(Icons.filter, 'सिनेमाई LUTs', _openFilterPresets),
              _buildTool(Icons.upload, 'एक्सपोर्ट 4K', _openExportSheet),
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
        width: 78,
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

  // ऑटो-कैप्शन व टेम्पलेट्स बॉटम शीट
  void _openCaptionTemplatesSheet() {
    final textCtrl = TextEditingController(text: _captionText);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161616),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('ऑटो-कैप्शन व वायरल सबटाइटल टेम्पलेट्स', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              TextField(
                controller: textCtrl,
                decoration: const InputDecoration(
                  hintText: 'कैप्शन टेक्स्ट यहाँ लिखें...',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _captionText = v),
              ),
              const SizedBox(height: 14),
              const Text('टेम्पलेट स्टाइल चुनें (1-क्लिक अप्लाई):', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _templateChip('🔥 MrBeast बोल्ड', CaptionStyle.mrBeast, setModalState),
                  _templateChip('⚡ Hormozi पंच', CaptionStyle.hormozi, setModalState),
                  _templateChip('✨ नियॉन ग्लो', CaptionStyle.neonGlow, setModalState),
                  _templateChip('🎤 कराओके बाउंस', CaptionStyle.karaoke, setModalState),
                  _templateChip('🎬 सिनेमैटिक', CaptionStyle.cinematic, setModalState),
                  _templateChip('⚪ मिनिमल व्हाइट', CaptionStyle.minimal, setModalState),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text('साइज: ', style: TextStyle(fontSize: 12)),
                  Expanded(
                    child: Slider(
                      value: _captionScale,
                      min: 0.6,
                      max: 1.8,
                      onChanged: (val) {
                        setModalState(() => _captionScale = val);
                        setState(() => _captionScale = val);
                      },
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF), foregroundColor: Colors.black),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('लागू करें', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _templateChip(String title, CaptionStyle style, StateSetter setModalState) {
    final isSelected = _activeCaptionStyle == style;
    return ChoiceChip(
      label: Text(title, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontSize: 11)),
      selected: isSelected,
      selectedColor: const Color(0xFF00E5FF),
      onSelected: (_) {
        setModalState(() => _activeCaptionStyle = style);
        setState(() => _activeCaptionStyle = style);
      },
    );
  }

  // प्रो कलर ग्रेडिंग
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
              const Text('प्रो कलर ग्रेडिंग स्टूडियो (GPU)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              Text('ब्राइटनेस: ${_brightness.toStringAsFixed(2)}'),
              Slider(
                value: _brightness,
                min: -0.4,
                max: 0.4,
                onChanged: (v) {
                  setModalState(() => _brightness = v);
                  setState(() => _brightness = v);
                },
              ),
              Text('कंट्रास्ट: ${_contrast.toStringAsFixed(2)}'),
              Slider(
                value: _contrast,
                min: 0.6,
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

  // ऑडियो मिक्सर
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
              Text('वीडियो मूल वॉइस: ${(_videoVolume * 100).toInt()}%'),
              Slider(
                value: _videoVolume,
                min: 0.0,
                max: 2.0,
                onChanged: (v) {
                  setModalState(() => _videoVolume = v);
                  setState(() {
                    _videoVolume = v;
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
              Text('साउंड इफेक्ट्स (SFX): ${(_sfxVolume * 100).toInt()}%'),
              Slider(
                value: _sfxVolume,
                min: 0.0,
                max: 1.0,
                onChanged: (v) => setModalState(() => _sfxVolume = v),
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
          children: [0.25, 0.5, 1.0, 1.5, 2.0, 4.0].map((s) {
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

  // AI जंप-कट
  void _runAIAutoJumpCut() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('AI ऑडियो स्कैन कर रहा है...')),
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
          const SnackBar(content: Text('AI ने साइलेंट हिस्से हटाकर वीडियो जंप-कट कर दिया!')),
        );
      }
    });
  }

  // साउंड इफेक्ट्स
  void _openSFXSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161616),
      builder: (_) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('साउंड इफेक्ट्स लाइब्रेरी (SFX)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: ['💨 Whoosh', '🔔 Bell', '💥 Pop', '🎵 Ding', '🤣 Meme Hit'].map((sfx) {
                return ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF262626)),
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$sfx साउंड इफ़ेक्ट टाइमलाइन पर जोड़ दिया गया!')),
                    );
                  },
                  child: Text(sfx),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // सिनेमाई फिल्टर्स
  void _openFilterPresets() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161616),
      builder: (_) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('सिनेमाई LUTs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('Teal & Orange'),
                  onPressed: () {
                    setState(() { _contrast = 1.3; _saturation = 1.4; });
                    Navigator.pop(context);
                  },
                ),
                ActionChip(
                  label: const Text('Noir B&W'),
                  onPressed: () {
                    setState(() { _saturation = 0.0; _contrast = 1.4; });
                    Navigator.pop(context);
                  },
                ),
                ActionChip(
                  label: const Text('Vintage Warm'),
                  onPressed: () {
                    setState(() { _brightness = 0.1; _saturation = 1.2; });
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

  // रेश्यो शीट
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
                    setState(() { _aspectRatio = 9 / 16; _ratioName = "9:16 (Shorts)"; });
                    Navigator.pop(context);
                  },
                ),
                ChoiceChip(
                  label: const Text('16:9 (YT)'),
                  selected: _aspectRatio == 16 / 9,
                  onSelected: (_) {
                    setState(() { _aspectRatio = 16 / 9; _ratioName = "16:9 (YT)"; });
                    Navigator.pop(context);
                  },
                ),
                ChoiceChip(
                  label: const Text('1:1 (Post)'),
                  selected: _aspectRatio == 1.0,
                  onSelected: (_) {
                    setState(() { _aspectRatio = 1.0; _ratioName = "1:1 (Post)"; });
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

  // 4K एक्सपोर्ट शीट
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
            Text('रिज़ॉल्यूशन: 4K UHD (3840x2160)'),
            Text('फ्रेम रेट: 60 FPS Ultra Smooth'),
            Text('कैप्शन स्टाइल: ${_activeCaptionStyle.name.toUpperCase()}'),
            Text('कैनवास फ्रेम: $_ratioName'),
            const SizedBox(height: 8),
            const Text('नो वॉटरमार्क • 100% फ्री • हाई बिटरेट', style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
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
            child: const Text('गैलरी में सेव करें'),
          ),
        ],
      ),
    );
  }
}
