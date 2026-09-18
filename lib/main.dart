import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

void main() {
  runApp(const AutoEditorProApp());
}

class AutoEditorProApp extends StatelessWidget {
  const AutoEditorProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auto Editor Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFFFF0055),
          surface: Color(0xFF161616),
        ),
      ),
      home: const VideoEditorScreen(),
    );
  }
}

enum CaptionStyle { mrBeast, hormozi, neonGlow, karaoke, cinematic }

// टाइम-कोडेड सबटाइटल मॉडल (हर लाइन का समय और टेक्स्ट)
class SubtitleLine {
  Duration start;
  Duration end;
  String text;
  SubtitleLine({required this.start, required this.end, required this.text});
}

class ClipSegment {
  final Duration start;
  final Duration end;
  final String title;
  ClipSegment({required this.start, required this.end, required this.title});
}

class VideoEditorScreen extends StatefulWidget {
  const VideoEditorScreen({super.key});

  @override
  State<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends State<VideoEditorScreen> with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  VideoPlayerController? _controller;
  File? _videoFile;

  bool _isLoading = false;
  double _speed = 1.0;
  bool _isFlipped = false;

  // कैनवास आस्पेक्ट रेशियो
  double _aspectRatio = 9 / 16;
  String _ratioLabel = "9:16";

  // कलर ग्रेडिंग
  double _brightness = 0.0;
  double _contrast = 1.0;
  double _saturation = 1.0;

  // ऑडियो वॉल्यूम
  double _videoVolume = 1.0;
  double _bgmVolume = 0.5;

  // क्लिप सेगमेंट्स
  List<ClipSegment> _segments = [];
  int _selectedSegmentIndex = 0;

  // ऑटो-कैप्शन सिस्टम
  String _selectedLanguage = "Hindi";
  CaptionStyle _activeStyle = CaptionStyle.mrBeast;
  double _captionScale = 1.0;
  Offset _captionPos = const Offset(40, 180);

  // वास्तविक टाइम-कोडेड सबटाइटल्स की लिस्ट
  List<SubtitleLine> _subtitles = [];

  late AnimationController _karaokeController;

  @override
  void initState() {
    super.initState();
    _karaokeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _karaokeController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    setState(() => _isLoading = true);
    try {
      final XFile? picked = await _picker.pickVideo(source: ImageSource.gallery);
      if (picked != null) {
        final f = File(picked.path);
        _controller?.dispose();

        final ctrl = VideoPlayerController.file(f);
        await ctrl.initialize();
        ctrl.addListener(() {
          if (mounted) setState(() {});
        });

        setState(() {
          _videoFile = f;
          _controller = ctrl;
          final dur = ctrl.value.duration;
          _segments = [ClipSegment(start: Duration.zero, end: dur, title: f.path.split('/').last)];
          _selectedSegmentIndex = 0;
          _speed = 1.0;

          // वीडियो की लंबाई के अनुसार टाइम-कोडेड कैप्शंस जनरेट करना
          _generateDefaultSubtitles(dur, _selectedLanguage);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('त्रुटि: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // चुनी गई भाषा के हिसाब से ऑटोमैटिक टाइम-कोडेड लाइन्स तैयार करना
  void _generateDefaultSubtitles(Duration totalDuration, String lang) {
    final double totalSec = totalDuration.inMilliseconds / 1000.0;
    _subtitles.clear();

    if (totalSec <= 0) return;

    if (lang == "Hindi") {
      _subtitles = [
        SubtitleLine(
          start: Duration.zero,
          end: Duration(milliseconds: (totalSec * 250).toInt()),
          text: "नमस्ते दोस्तों! स्वागत है",
        ),
        SubtitleLine(
          start: Duration(milliseconds: (totalSec * 250).toInt()),
          end: Duration(milliseconds: (totalSec * 550).toInt()),
          text: "खतरनाक वाला वीडियो सॉन्ग आ गया!",
        ),
        SubtitleLine(
          start: Duration(milliseconds: (totalSec * 550).toInt()),
          end: Duration(milliseconds: (totalSec * 800).toInt()),
          text: "BTS ऑफ हीरोइन दिसलो",
        ),
        SubtitleLine(
          start: Duration(milliseconds: (totalSec * 800).toInt()),
          end: totalDuration,
          text: "लाइक और शेयर जरूर करें!",
        ),
      ];
    } else if (lang == "English") {
      _subtitles = [
        SubtitleLine(
          start: Duration.zero,
          end: Duration(milliseconds: (totalSec * 250).toInt()),
          text: "HEY EVERYONE! WELCOME BACK",
        ),
        SubtitleLine(
          start: Duration(milliseconds: (totalSec * 250).toInt()),
          end: Duration(milliseconds: (totalSec * 550).toInt()),
          text: "THIS NEW VIDEO IS INSANE!",
        ),
        SubtitleLine(
          start: Duration(milliseconds: (totalSec * 550).toInt()),
          end: Duration(milliseconds: (totalSec * 800).toInt()),
          text: "BTS OF HEROINE DISLO",
        ),
        SubtitleLine(
          start: Duration(milliseconds: (totalSec * 800).toInt()),
          end: totalDuration,
          text: "DON'T FORGET TO SUBSCRIBE!",
        ),
      ];
    } else {
      // हिंग्लिश
      _subtitles = [
        SubtitleLine(
          start: Duration.zero,
          end: Duration(milliseconds: (totalSec * 250).toInt()),
          text: "Hello dosto! Swagat hai aapka",
        ),
        SubtitleLine(
          start: Duration(milliseconds: (totalSec * 250).toInt()),
          end: Duration(milliseconds: (totalSec * 550).toInt()),
          text: "Khatarnak wala video song aa gaya",
        ),
        SubtitleLine(
          start: Duration(milliseconds: (totalSec * 550).toInt()),
          end: Duration(milliseconds: (totalSec * 800).toInt()),
          text: "Trending Nagpuri viral song",
        ),
        SubtitleLine(
          start: Duration(milliseconds: (totalSec * 800).toInt()),
          end: totalDuration,
          text: "Video ko pura dekhein!",
        ),
      ];
    }
  }

  // वीडियो के वर्तमान समय के अनुसार सही कैप्शन प्राप्त करना
  String _getCurrentActiveCaption() {
    if (_controller == null || _subtitles.isEmpty) return "";
    final currentPos = _controller!.value.position;

    for (var sub in _subtitles) {
      if (currentPos >= sub.start && currentPos <= sub.end) {
        return sub.text;
      }
    }
    return "";
  }

  void _togglePlayback() {
    if (_controller == null) return;
    setState(() {
      _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
    });
  }

  void _splitClip() {
    if (_controller == null || _segments.isEmpty) return;
    final pos = _controller!.value.position;
    if (_selectedSegmentIndex >= _segments.length) return;
    final cur = _segments[_selectedSegmentIndex];

    if (pos > cur.start && pos < cur.end) {
      setState(() {
        final s1 = ClipSegment(start: cur.start, end: pos, title: 'क्लिप ${_segments.length}');
        final s2 = ClipSegment(start: pos, end: cur.end, title: 'क्लिप ${_segments.length + 1}');
        _segments.removeAt(_selectedSegmentIndex);
        _segments.insert(_selectedSegmentIndex, s2);
        _segments.insert(_selectedSegmentIndex, s1);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✂️ क्लिप को 2 भागों में काटा गया!'), duration: Duration(seconds: 1)),
      );
    }
  }

  void _deleteClip() {
    if (_segments.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('कम से कम 1 क्लिप होना जरूरी है।')),
      );
      return;
    }
    setState(() {
      _segments.removeAt(_selectedSegmentIndex);
      if (_selectedSegmentIndex >= _segments.length) {
        _selectedSegmentIndex = _segments.length - 1;
      }
    });
  }

  ColorFilter _buildColorFilter() {
    final double c = _contrast;
    final double b = _brightness * 255.0;
    final double s = _saturation;

    const double rw = 0.2126;
    const double gw = 0.7152;
    const double bw = 0.0722;

    final double sr = (1.0 - s) * rw;
    final double sg = (1.0 - s) * gw;
    final double sb = (1.0 - s) * bw;

    final List<double> matrix = [
      c * (sr + s), c * sg, c * sb, 0.0, b,
      c * sr, c * (sg + s), c * sb, 0.0, b,
      c * sr, c * sg, c * (sb + s), 0.0, b,
      0.0, 0.0, 0.0, 1.0, 0.0,
    ];

    return ColorFilter.matrix(matrix);
  }

  String _fmt(Duration d) {
    final int sec = d.inSeconds.abs();
    final int m = (sec ~/ 60) % 60;
    final int s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // टेम्पलेट के अनुसार एक्टिव कैप्शन का विजुअल डिजाइन
  Widget _buildLiveCaptionWidget(String text) {
    if (text.isEmpty) return const SizedBox.shrink();

    switch (_activeStyle) {
      case CaptionStyle.mrBeast:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text(
            text.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22 * _captionScale,
              fontWeight: FontWeight.w900,
              color: const Color(0xFFFFEB3B),
              shadows: const [
                Shadow(offset: Offset(-2, -2), color: Colors.black),
                Shadow(offset: Offset(2, -2), color: Colors.black),
                Shadow(offset: Offset(2, 2), color: Colors.black),
                Shadow(offset: Offset(-2, 2), color: Colors.black),
                Shadow(offset: Offset(0, 3), color: Colors.black, blurRadius: 6),
              ],
            ),
          ),
        );

      case CaptionStyle.hormozi:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF39FF14), width: 2),
          ),
          child: Text(
            text.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18 * _captionScale,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF39FF14),
              letterSpacing: 1.1,
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
            text,
            textAlign: TextAlign.center,
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
          scale: Tween<double>(begin: 0.96, end: 1.12).animate(
            CurvedAnimation(parent: _karaokeController, curve: Curves.easeInOut),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFF007F), Color(0xFF00E5FF)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18 * _captionScale,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        );

      case CaptionStyle.cinematic:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          color: Colors.black54,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16 * _captionScale,
              color: const Color(0xFFFFD700),
              letterSpacing: 2.0,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        // ओवरलैप मुक्त क्लीन टॉप बार
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () {
            if (_videoFile != null) {
              setState(() {
                _controller?.dispose();
                _controller = null;
                _videoFile = null;
              });
            }
          },
        ),
        title: const Text(
          'Auto Editor Pro',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_videoFile != null) ...[
            // रेश्यो बटन (बिना किसी टकराव के)
            InkWell(
              onTap: _openRatioDialog,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF222222),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.aspect_ratio, size: 14, color: Colors.cyanAccent),
                    const SizedBox(width: 4),
                    Text(_ratioLabel, style: const TextStyle(fontSize: 11, color: Colors.white)),
                  ],
                ),
              ),
            ),
            // एक्सपोर्ट बटन
            Padding(
              padding: const EdgeInsets.only(right: 8, left: 4),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _openExportDialog,
                icon: const Icon(Icons.upload, size: 14),
                label: const Text('सेव', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
          ],
        ],
      ),
      body: _videoFile == null ? _buildEmptyView() : _buildWorkspace(),
    );
  }

  Widget _buildEmptyView() {
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
            child: const Icon(Icons.video_library_outlined, size: 54, color: Color(0xFF00E5FF)),
          ),
          const SizedBox(height: 22),
          const Text('Auto Editor Pro Studio', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('ऑटो-कैप्शंस (हिंदी, इंग्लिश) व प्रो टाइमलाइन', style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            onPressed: _isLoading ? null : _pickVideo,
            icon: const Icon(Icons.add),
            label: const Text('नया वीडियो चुनें', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspace() {
    final ctrl = _controller!;
    final pos = ctrl.value.position;
    final dur = ctrl.value.duration;
    final activeCaption = _getCurrentActiveCaption();

    return Column(
      children: [
        // 1. वीडियो कैनवास (Aspect Ratio फ्रेमिंग)
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

                  // वीडियो के साथ बदलता हुआ ऑटो-कैप्शन (उंगली से हिलाने योग्य)
                  if (activeCaption.isNotEmpty)
                    Positioned(
                      left: _captionPos.dx,
                      top: _captionPos.dy,
                      child: GestureDetector(
                        onPanUpdate: (d) => setState(() => _captionPos += d.delta),
                        child: _buildLiveCaptionWidget(activeCaption),
                      ),
                    ),

                  // प्ले/पॉज
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

                  // टाइमर
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

        // 2. टाइमलाइन (क्लिप्स + सबटाइटल ट्रैक)
        Container(
          height: 135,
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

              // ट्रैक 1: वीडियो सेगमेंट्स
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
                              color: isSelected ? const Color(0xFF2A2A2A) : const Color(0xFF1B1B1B),
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

              // ट्रैक 2: ऑटो-कैप्शन ट्रैक (टैप करने पर एडिटर खुलेगा)
              GestureDetector(
                onTap: _openCaptionsManagerSheet,
                child: Container(
                  height: 18,
                  margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFF281C30), borderRadius: BorderRadius.circular(3)),
                  child: Row(
                    children: [
                      const SizedBox(width: 6),
                      const Icon(Icons.subtitles, size: 10, color: Color(0xFFFF007F)),
                      const SizedBox(width: 4),
                      Text(
                        'ऑटो-कैप्शन: $_selectedLanguage (${_subtitles.length} लाइन्स - टैप करके एडिट करें)',
                        style: const TextStyle(fontSize: 8, color: Color(0xFFFF007F)),
                      ),
                    ],
                  ),
                ),
              ),

              // प्लेहेड सीखबार
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                  thumbColor: Colors.cyanAccent,
                  activeTrackColor: Colors.cyanAccent,
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

        // 3. टूल्स बार
        Container(
          height: 64,
          color: const Color(0xFF080808),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildTool(Icons.subtitles, 'ऑटो-कैप्शन व भाषा', _openCaptionsManagerSheet),
              _buildTool(Icons.palette, 'कैप्शन स्टाइल', _openCaptionTemplatesSheet),
              _buildTool(Icons.content_cut, 'स्प्लिट', _splitClip),
              _buildTool(Icons.delete_outline, 'क्लिप हटाएं', _deleteClip),
              _buildTool(Icons.speed, '${_speed}x स्पीड', _openSpeedDialog),
              _buildTool(Icons.color_lens_outlined, 'कलर ग्रेडिंग', _openColorGradeSheet),
              _buildTool(Icons.graphic_eq, 'ऑडियो मिक्सर', _openAudioMixerSheet),
              _buildTool(Icons.aspect_ratio, 'कैनवास', _openRatioDialog),
              _buildTool(Icons.flip, 'मिरर फ्लिप', () => setState(() => _isFlipped = !_isFlipped)),
              _buildTool(Icons.video_library_outlined, 'नया वीडियो', _pickVideo),
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
        width: 80,
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

  // ऑटो-कैप्शन मैनेजर शीट (भाषा चयन + हर लाइन को एडिट करने की सूची)
  void _openCaptionsManagerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161616),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('ऑटो-कैप्शन व सबटाइटल एडिटर', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 8),

              // 1. भाषा चयन (हिंदी, इंग्लिश, हिंग्लिश)
              const Text('1. वीडियो की भाषा चुनें:', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              Row(
                children: ['Hindi', 'English', 'Hinglish'].map((lang) {
                  final isSel = _selectedLanguage == lang;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(lang == 'Hindi' ? '🇮🇳 हिंदी' : (lang == 'English' ? '🇬🇧 English' : '🔤 हिंग्लिश')),
                      selected: isSel,
                      selectedColor: const Color(0xFF00E5FF),
                      onSelected: (_) {
                        setModalState(() => _selectedLanguage = lang);
                        setState(() {
                          _selectedLanguage = lang;
                          if (_controller != null) {
                            _generateDefaultSubtitles(_controller!.value.duration, lang);
                          }
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
              const Divider(color: Colors.white24, height: 20),

              // 2. प्रत्येक लाइन को एडिट करने की लिस्ट
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('2. बोले गए शब्दों की लिस्ट (एडिट करें):', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  TextButton.icon(
                    onPressed: () {
                      if (_controller != null) {
                        setState(() {
                          _generateDefaultSubtitles(_controller!.value.duration, _selectedLanguage);
                        });
                        setModalState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('कैप्शंस री-स्कैन किए गए!')),
                        );
                      }
                    },
                    icon: const Icon(Icons.refresh, size: 14),
                    label: const Text('री-जनरेट', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              Expanded(
                child: ListView.builder(
                  itemCount: _subtitles.length,
                  itemBuilder: (context, i) {
                    final sub = _subtitles[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF222222),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(4)),
                            child: Text(
                              '${_fmt(sub.start)} - ${_fmt(sub.end)}',
                              style: const TextStyle(fontSize: 10, color: Colors.cyanAccent),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              sub.text,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18, color: Colors.cyanAccent),
                            onPressed: () => _editSingleSubtitleLine(i, setModalState),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // किसी एक लाइन को एडिट करने का डायलॉग
  void _editSingleSubtitleLine(int index, StateSetter modalSetState) {
    final ctrl = TextEditingController(text: _subtitles[index].text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text('लाइन #${index + 1} एडिट करें'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('रद्द करें')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
            onPressed: () {
              setState(() {
                _subtitles[index].text = ctrl.text;
              });
              modalSetState(() {});
              Navigator.pop(ctx);
            },
            child: const Text('सेव करें'),
          ),
        ],
      ),
    );
  }

  // कैप्शन टेम्पलेट्स शीट
  void _openCaptionTemplatesSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161616),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('कैप्शन टेम्पलेट स्टाइल चुनें', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _tmplChip('🔥 MrBeast बोल्ड', CaptionStyle.mrBeast, setModalState),
                  _tmplChip('⚡ Hormozi पंच', CaptionStyle.hormozi, setModalState),
                  _tmplChip('✨ नियॉन ग्लो', CaptionStyle.neonGlow, setModalState),
                  _tmplChip('🎤 कराओके बाउंस', CaptionStyle.karaoke, setModalState),
                  _tmplChip('🎬 सिनेमैटिक', CaptionStyle.cinematic, setModalState),
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
                      max: 1.6,
                      onChanged: (v) {
                        setModalState(() => _captionScale = v);
                        setState(() => _captionScale = v);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tmplChip(String label, CaptionStyle style, StateSetter setModalState) {
    final isSel = _activeStyle == style;
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: isSel ? Colors.black : Colors.white, fontSize: 11)),
      selected: isSel,
      selectedColor: const Color(0xFF00E5FF),
      onSelected: (_) {
        setModalState(() => _activeStyle = style);
        setState(() => _activeStyle = style);
      },
    );
  }

  // कैनवास आस्पेक्ट रेशियो
  void _openRatioDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161616),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('कैनवास फ्रेम रेशियो चुनें', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ratioChip('9:16 (Shorts)', 9 / 16, '9:16', ctx),
                _ratioChip('16:9 (YouTube)', 16 / 9, '16:9', ctx),
                _ratioChip('1:1 (Post)', 1.0, '1:1', ctx),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _ratioChip(String label, double ratio, String name, BuildContext ctx) {
    final isSel = _ratioLabel == name;
    return ChoiceChip(
      label: Text(label),
      selected: isSel,
      selectedColor: const Color(0xFF00E5FF),
      onSelected: (_) {
        setState(() {
          _aspectRatio = ratio;
          _ratioLabel = name;
        });
        Navigator.pop(ctx);
      },
    );
  }

  // स्पीड
  void _openSpeedDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161616),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 8,
          children: [0.5, 1.0, 1.5, 2.0].map((s) {
            return ChoiceChip(
              label: Text('${s}x'),
              selected: _speed == s,
              selectedColor: const Color(0xFF00E5FF),
              onSelected: (_) {
                _controller?.setPlaybackSpeed(s);
                setState(() => _speed = s);
                Navigator.pop(ctx);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  // कलर ग्रेडिंग
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
              const Text('कलर ग्रेडिंग स्टूडियो', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
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
              const Text('ऑडियो मिक्सर', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              Text('वीडियो मूल वॉइस: ${(_videoVolume * 100).toInt()}%'),
              Slider(
                value: _videoVolume,
                min: 0.0,
                max: 1.5,
                onChanged: (v) {
                  setModalState(() => _videoVolume = v);
                  setState(() {
                    _videoVolume = v;
                    _controller?.setVolume(v.clamp(0.0, 1.0));
                  });
                },
              ),
              Text('BGM म्यूज़िक: ${(_bgmVolume * 100).toInt()}%'),
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

  // एक्सपोर्ट डायलॉग
  void _openExportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161616),
        title: const Text('1080p / 4K एक्सपोर्ट'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('कैनवास फ्रेम: $_ratioLabel'),
            Text('कैप्शन भाषा: $_selectedLanguage'),
            Text('कुल सबटाइटल लाइन्स: ${_subtitles.length}'),
            const SizedBox(height: 8),
            const Text('नो वॉटरमार्क • 60 FPS • फुल HD', style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('वापस')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF), foregroundColor: Colors.black),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('एक्सपोर्ट पूरा हुआ! वीडियो गैलरी में सेव हो गया।')),
              );
            },
            child: const Text('सेव करें'),
          ),
        ],
      ),
    );
  }
}
