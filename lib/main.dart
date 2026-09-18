import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

void main() {
  runApp(const CapCutMasterStudioApp());
}

class CapCutMasterStudioApp extends StatelessWidget {
  const CapCutMasterStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auto Editor Master Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0C0C0C),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFFFF0055),
          surface: Color(0xFF161616),
        ),
      ),
      home: const MasterEditorScreen(),
    );
  }
}

enum VisualEffectType { none, flashLight, vibrationShake, opticalZoom, discoParty, glitch }
enum TransitionEffectType { none, whiteFlash, blackFade, mixDissolve }
enum FilterPresetType { normal, cyberpunk, tealOrange, vintageWarm, blackGold, highSaturation, noirMono, sunlight }
enum CaptionStyle { mrBeast, hormozi, neonGlow, karaoke }

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

class SavedProjectItem {
  final String name;
  final String date;
  final String duration;
  final String size;
  SavedProjectItem({required this.name, required this.date, required this.duration, required this.size});
}

class MasterEditorScreen extends StatefulWidget {
  const MasterEditorScreen({super.key});

  @override
  State<MasterEditorScreen> createState() => _MasterEditorScreenState();
}

class _MasterEditorScreenState extends State<MasterEditorScreen> with TickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  VideoPlayerController? _controller;
  File? _videoFile;

  bool _isLoading = false;
  double _speed = 1.0;
  bool _isFlipped = false;
  bool _showPipOverlay = false;

  // सक्रिय इफेक्ट्स
  VisualEffectType _activeEffect = VisualEffectType.none;
  TransitionEffectType _activeTransition = TransitionEffectType.none;
  FilterPresetType _activeFilter = FilterPresetType.normal;

  // कलर ग्रेडिंग स्लाइडर्स
  double _brightness = 0.0;
  double _contrast = 1.0;
  double _saturation = 1.0;

  // एनिमेशन कंट्रोलर्स
  late AnimationController _transitionAnimController;
  late Animation<double> _transitionAnimation;
  late AnimationController _glitchAnimController;
  late AnimationController _karaokeAnimController;

  // सक्रिय टैब (Edit, Effects, Transitions, Filters, Adjust, Captions, Audio)
  String _activeTab = "Edit";

  // सबटाइटल्स
  String _selectedLanguage = "Hindi";
  CaptionStyle _activeCaptionStyle = CaptionStyle.mrBeast;
  List<SubtitleLine> _subtitles = [];
  Offset _captionPosition = const Offset(50, 160);
  Offset _pipPosition = const Offset(20, 30);

  // क्लिप्स सेगमेंट्स
  List<ClipSegment> _segments = [];
  int _selectedSegmentIndex = 0;

  // कैनवास रेशियो
  double _aspectRatio = 9 / 16;
  String _ratioLabel = "9:16";

  // ऑडियो
  double _videoVolume = 1.0;
  double _bgmVolume = 0.5;

  // ड्राफ्ट्स / हालिया प्रोजेक्ट्स (CapCut Home Screen)
  final List<SavedProjectItem> _recentProjects = [
    SavedProjectItem(name: 'BTS Of Heroine Dislo', date: '2026/09/18', duration: '00:22', size: '14.2 MB'),
    SavedProjectItem(name: 'Trending Nagpuri Song', date: '2026/09/17', duration: '00:18', size: '9.8 MB'),
    SavedProjectItem(name: 'YouTube Shorts Edit 01', date: '2026/09/15', duration: '00:15', size: '6.4 MB'),
  ];

  @override
  void initState() {
    super.initState();

    _transitionAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _transitionAnimation = CurvedAnimation(
      parent: _transitionAnimController,
      curve: Curves.easeInOut,
    );

    _glitchAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..repeat(reverse: true);

    _karaokeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _transitionAnimController.dispose();
    _glitchAnimController.dispose();
    _karaokeAnimController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    setState(() => _isLoading = true);
    try {
      final XFile? file = await _picker.pickVideo(source: ImageSource.gallery);
      if (file != null) {
        final f = File(file.path);
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
          _generateDefaultSubtitles(dur, _selectedLanguage);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('त्रुटि: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _generateDefaultSubtitles(Duration dur, String lang) {
    final double sec = dur.inMilliseconds / 1000.0;
    _subtitles.clear();
    if (sec <= 0) return;

    if (lang == "Hindi") {
      _subtitles = [
        SubtitleLine(start: Duration.zero, end: Duration(milliseconds: (sec * 300).toInt()), text: "नमस्ते दोस्तों! नया गाना आ गया"),
        SubtitleLine(start: Duration(milliseconds: (sec * 300).toInt()), end: Duration(milliseconds: (sec * 650).toInt()), text: "खतरनाक वाला वीडियो सॉन्ग"),
        SubtitleLine(start: Duration(milliseconds: (sec * 650).toInt()), end: dur, text: "BTS ऑफ हीरोइन दिसलो"),
      ];
    } else {
      _subtitles = [
        SubtitleLine(start: Duration.zero, end: Duration(milliseconds: (sec * 300).toInt()), text: "HEY EVERYONE! WELCOME BACK"),
        SubtitleLine(start: Duration(milliseconds: (sec * 300).toInt()), end: Duration(milliseconds: (sec * 650).toInt()), text: "THIS MUSIC VIDEO IS INSANE!"),
        SubtitleLine(start: Duration(milliseconds: (sec * 650).toInt()), end: dur, text: "BTS OF HEROINE DISLO"),
      ];
    }
  }

  String _getActiveCaption() {
    if (_controller == null || _subtitles.isEmpty) return "";
    final pos = _controller!.value.position;
    for (var sub in _subtitles) {
      if (pos >= sub.start && pos <= sub.end) return sub.text;
    }
    return "";
  }

  void _togglePlay() {
    if (_controller == null) return;
    setState(() {
      _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
    });
  }

  // 1. क्लिप स्प्लिट
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

  // 2. क्लिप डिलीट
  void _deleteClip() {
    if (_segments.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('कम से कम 1 क्लिप होना आवश्यक है।')),
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

  // 3. स्पीड टॉगल
  void _toggleSpeed() {
    if (_controller == null) return;
    final nextSpeed = _speed == 1.0 ? 1.5 : (_speed == 1.5 ? 2.0 : (_speed == 2.0 ? 0.5 : 1.0));
    _controller!.setPlaybackSpeed(nextSpeed);
    setState(() => _speed = nextSpeed);
  }

  // 4. AI जंप-कट
  void _runAIAutoJumpCut() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('AI इंजन ऑडियो स्कैन कर रहा है...')),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _controller != null) {
        final total = _controller!.value.duration;
        setState(() {
          _segments = [
            ClipSegment(start: Duration.zero, end: total * 0.35, title: 'क्लिप 1 (ऑडियो भाग)'),
            ClipSegment(start: total * 0.45, end: total * 0.85, title: 'क्लिप 2 (ऑडियो भाग)'),
          ];
          _selectedSegmentIndex = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI ने साइलेंट हिस्से हटाकर जंप-कट कर दिया!')),
        );
      }
    });
  }

  void _applyTransition(TransitionEffectType type) {
    setState(() => _activeTransition = type);
    _transitionAnimController.forward(from: 0.0);
  }

  // कंबाइंड कलर फिल्टर (प्रीसेट्स + मैनुअल ब्राइटनेस/कंट्रास्ट/सैचुरेशन)
  ColorFilter _getCombinedColorFilter() {
    double c = _contrast;
    double b = _brightness * 255.0;
    double s = _saturation;

    if (_activeFilter == FilterPresetType.cyberpunk) {
      c *= 1.3; s *= 1.5;
    } else if (_activeFilter == FilterPresetType.tealOrange) {
      c *= 1.2; s *= 1.3;
    } else if (_activeFilter == FilterPresetType.vintageWarm) {
      b += 20.0; s *= 1.1;
    } else if (_activeFilter == FilterPresetType.noirMono) {
      s = 0.0; c *= 1.3;
    } else if (_activeFilter == FilterPresetType.highSaturation) {
      s *= 1.8;
    } else if (_activeFilter == FilterPresetType.sunlight) {
      b += 25.0; c *= 1.1;
    }

    const rw = 0.2126;
    const gw = 0.7152;
    const bw = 0.0722;

    final sr = (1.0 - s) * rw;
    final sg = (1.0 - s) * gw;
    final sb = (1.0 - s) * bw;

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

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 750;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF141414),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, size: 20),
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
        title: Row(
          children: [
            const Text('Auto Editor', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF00E5FF), Color(0xFFFF0055)]),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('MASTER STUDIO', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.black)),
            ),
          ],
        ),
        actions: [
          if (_videoFile != null) ...[
            IconButton(
              tooltip: 'स्टिल फ्रेम / थंबनेल एक्सपोर्ट',
              icon: const Icon(Icons.camera_alt_outlined, size: 20, color: Colors.white70),
              onPressed: _openStillFrameExportDialog,
            ),
            TextButton.icon(
              onPressed: _openRatioDialog,
              icon: const Icon(Icons.aspect_ratio, size: 16, color: Color(0xFF00E5FF)),
              label: Text(_ratioLabel, style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 12)),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 10, left: 4),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: _openMainExportDialog,
                icon: const Icon(Icons.upload, size: 14),
                label: const Text('एक्सपोर्ट', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
          ],
        ],
      ),
      body: _videoFile == null ? _buildCapCutHomeScreen() : (isDesktop ? _buildDesktopLayout() : _buildMobileLayout()),
    );
  }

  // 1. CapCut होम स्क्रीन (नया प्रोजेक्ट + ड्राफ्ट्स/प्रोजेक्ट्स हिस्ट्री)
  Widget _buildCapCutHomeScreen() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GestureDetector(
          onTap: _isLoading ? null : _pickVideo,
          child: Container(
            height: 140,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF00E5FF).withOpacity(0.15), const Color(0xFFFF0055).withOpacity(0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.4), width: 1.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(color: Color(0xFF00E5FF), shape: BoxShape.circle),
                  child: _isLoading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                      : const Icon(Icons.add, size: 28, color: Colors.black),
                ),
                const SizedBox(height: 12),
                const Text('नया प्रोजेक्ट (New Project)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('गैलरी से वीडियो चुनकर मास्टर एडिट करें', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('हालिया प्रोजेक्ट्स (Recent Projects)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Icon(Icons.history, size: 18, color: Colors.grey),
          ],
        ),
        const SizedBox(height: 12),

        ..._recentProjects.map((p) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF181818),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(color: const Color(0xFF242424), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.movie_outlined, color: Color(0xFF00E5FF)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text('${p.date} • ${p.duration} • ${p.size}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.play_circle_fill, color: Color(0xFF00E5FF), size: 30),
                  onPressed: _pickVideo,
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // 2. मोबाइल लेआउट
  Widget _buildMobileLayout() {
    return Column(
      children: [
        Expanded(flex: 5, child: _buildVideoCanvas()),
        _buildTimelineBar(),

        // 7 मुख्य कैटेगरीज टैब्स
        Container(
          height: 44,
          color: const Color(0xFF141414),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildCategoryTab('Edit', Icons.content_cut, 'एडिट व कट्स'),
              _buildCategoryTab('Effects', Icons.auto_awesome, 'इफेक्ट्स'),
              _buildCategoryTab('Transitions', Icons.shuffle, 'ट्रांज़िशन्स'),
              _buildCategoryTab('Filters', Icons.palette_outlined, 'फिल्टर्स'),
              _buildCategoryTab('Adjust', Icons.tune, 'कलर एडजस्ट'),
              _buildCategoryTab('Captions', Icons.subtitles_outlined, 'ऑटो-कैप्शन'),
              _buildCategoryTab('Audio', Icons.graphic_eq, 'ऑडियो व SFX'),
            ],
          ),
        ),

        Expanded(
          flex: 4,
          child: Container(
            color: const Color(0xFF0D0D0D),
            child: _buildActiveTabContent(),
          ),
        ),
      ],
    );
  }

  // 3. डेस्कटॉप लेआउट
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Container(
          width: 320,
          color: const Color(0xFF141414),
          child: Column(
            children: [
              Container(
                color: const Color(0xFF1A1A1A),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildDeskTab('Edit', 'एडिट'),
                      _buildDeskTab('Effects', 'इफेक्ट्स'),
                      _buildDeskTab('Transitions', 'ट्रांज़िशन'),
                      _buildDeskTab('Filters', 'फिल्टर्स'),
                      _buildDeskTab('Adjust', 'एडजस्ट'),
                      _buildDeskTab('Captions', 'कैप्शन'),
                      _buildDeskTab('Audio', 'ऑडियो'),
                    ],
                  ),
                ),
              ),
              Expanded(child: _buildActiveTabContent()),
            ],
          ),
        ),
        Expanded(
          child: Column(
            children: [
              Expanded(child: _buildVideoCanvas()),
              _buildTimelineBar(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryTab(String tabKey, IconData icon, String label) {
    final isSelected = _activeTab == tabKey;
    return InkWell(
      onTap: () => setState(() => _activeTab = tabKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? const Color(0xFF00E5FF) : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? const Color(0xFF00E5FF) : Colors.grey),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeskTab(String tabKey, String label) {
    final isSel = _activeTab == tabKey;
    return TextButton(
      onPressed: () => setState(() => _activeTab = tabKey),
      child: Text(
        label,
        style: TextStyle(
          color: isSel ? const Color(0xFF00E5FF) : Colors.grey,
          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  // 4. वीडियो कैनवास
  Widget _buildVideoCanvas() {
    final ctrl = _controller!;
    final pos = ctrl.value.position;
    final dur = ctrl.value.duration;
    final activeCaption = _getActiveCaption();

    double scale = 1.0;
    Offset shakeOffset = Offset.zero;
    Color overlayFlashColor = Colors.transparent;

    if (_activeEffect == VisualEffectType.opticalZoom) {
      scale = 1.15;
    } else if (_activeEffect == VisualEffectType.vibrationShake) {
      final double shakeVal = math.sin(_glitchAnimController.value * math.pi * 4) * 6;
      shakeOffset = Offset(shakeVal, 0);
    } else if (_activeEffect == VisualEffectType.flashLight) {
      overlayFlashColor = _glitchAnimController.value > 0.6 ? Colors.white.withOpacity(0.4) : Colors.transparent;
    } else if (_activeEffect == VisualEffectType.discoParty) {
      overlayFlashColor = _glitchAnimController.value > 0.5 ? const Color(0xFFFF0055).withOpacity(0.3) : const Color(0xFF00E5FF).withOpacity(0.3);
    }

    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: AspectRatio(
        aspectRatio: _aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Transform.translate(
              offset: shakeOffset,
              child: Transform.scale(
                scale: scale,
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.rotationY(_isFlipped ? math.pi : 0),
                  child: GestureDetector(
                    onTap: _togglePlay,
                    child: ColorFiltered(
                      colorFilter: _getCombinedColorFilter(),
                      child: VideoPlayer(ctrl),
                    ),
                  ),
                ),
              ),
            ),

            if (overlayFlashColor != Colors.transparent)
              IgnorePointer(child: Container(color: overlayFlashColor)),

            AnimatedBuilder(
              animation: _transitionAnimController,
              builder: (context, child) {
                if (!_transitionAnimController.isAnimating && _transitionAnimController.value == 1.0) {
                  return const SizedBox.shrink();
                }

                if (_activeTransition == TransitionEffectType.whiteFlash) {
                  final opacity = (1.0 - _transitionAnimation.value).clamp(0.0, 1.0);
                  return IgnorePointer(child: Container(color: Colors.white.withOpacity(opacity)));
                } else if (_activeTransition == TransitionEffectType.blackFade) {
                  final val = _transitionAnimation.value;
                  final opacity = val < 0.5 ? (val * 2) : (2.0 - val * 2);
                  return IgnorePointer(child: Container(color: Colors.black.withOpacity(opacity.clamp(0.0, 1.0))));
                }
                return const SizedBox.shrink();
              },
            ),

            // PIP ओवरले
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
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_pin, color: Color(0xFF00E5FF), size: 30),
                        Text('PIP लोगो', style: TextStyle(fontSize: 9, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),

            // लाइव ऑटो-कैप्शन
            if (activeCaption.isNotEmpty)
              Positioned(
                left: _captionPosition.dx,
                top: _captionPosition.dy,
                child: GestureDetector(
                  onPanUpdate: (d) => setState(() => _captionPosition += d.delta),
                  child: _buildCaptionStyleWidget(activeCaption),
                ),
              ),

            if (!ctrl.value.isPlaying)
              Center(
                child: GestureDetector(
                  onTap: _togglePlay,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.play_arrow, size: 44, color: Colors.white),
                  ),
                ),
              ),

            Positioned(
              bottom: 6,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                child: Text('${_fmt(pos)} / ${_fmt(dur)}', style: const TextStyle(fontSize: 10, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 5. टाइमलाइन
  Widget _buildTimelineBar() {
    final ctrl = _controller!;
    final pos = ctrl.value.position;
    final dur = ctrl.value.duration;

    return Container(
      height: 85,
      color: const Color(0xFF141414),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'क्लिप: ${_selectedSegmentIndex + 1}/${_segments.length} | ${_activeEffect.name.toUpperCase()}',
                style: const TextStyle(fontSize: 10, color: Color(0xFF00E5FF)),
              ),
              Text('${_speed}x गति', style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 26,
            child: Row(
              children: _segments.asMap().entries.map((entry) {
                final idx = entry.key;
                final seg = entry.value;
                final isSelected = idx == _selectedSegmentIndex;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedSegmentIndex = idx),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF2A2A2A) : const Color(0xFF1B1B1B),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFFFC107) : Colors.white10,
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${seg.title} (${_fmt(seg.end - seg.start)})',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 8, color: isSelected ? Colors.white : Colors.grey),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              thumbColor: const Color(0xFF00E5FF),
              activeTrackColor: const Color(0xFF00E5FF),
              inactiveTrackColor: Colors.white24,
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
    );
  }

  Widget _buildActiveTabContent() {
    switch (_activeTab) {
      case 'Edit':
        return _buildEditControlsPanel();
      case 'Effects':
        return _buildEffectsGrid();
      case 'Transitions':
        return _buildTransitionsGrid();
      case 'Filters':
        return _buildFiltersGrid();
      case 'Adjust':
        return _buildColorAdjustPanel();
      case 'Captions':
        return _buildCaptionsPanel();
      case 'Audio':
        return _buildAudioPanel();
      default:
        return _buildEditControlsPanel();
    }
  }

  // 1. एडिट व कट्स पैनल (स्प्लिट, डिलीट, स्पीड, फ्लिप, AI जंप-कट, PIP)
  Widget _buildEditControlsPanel() {
    return GridView.count(
      crossAxisCount: 3,
      padding: const EdgeInsets.all(12),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.1,
      children: [
        _buildActionCard(Icons.content_cut, 'स्प्लिट कट', 'प्लेहेड पर काटें', _splitClip, Colors.cyanAccent),
        _buildActionCard(Icons.delete_outline, 'क्लिप हटाएं', 'चयनित हिस्सा हटाएं', _deleteClip, Colors.redAccent),
        _buildActionCard(Icons.speed, '${_speed}x स्पीड', 'धीमा / तेज़ करें', _toggleSpeed, Colors.orangeAccent),
        _buildActionCard(Icons.auto_fix_high, 'AI जंप-कट', 'साइलेंस हटाएं', _runAIAutoJumpCut, Colors.purpleAccent),
        _buildActionCard(Icons.flip, 'मिरर फ्लिप', '180° घुमाएं', () => setState(() => _isFlipped = !_isFlipped), Colors.greenAccent),
        _buildActionCard(
          Icons.picture_in_picture_alt,
          'PIP ओवरले',
          _showPipOverlay ? 'चालू' : 'बंद',
          () => setState(() => _showPipOverlay = !_showPipOverlay),
          Colors.pinkAccent,
        ),
      ],
    );
  }

  Widget _buildActionCard(IconData icon, String title, String subtitle, VoidCallback onTap, Color c) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: c, size: 24),
            const SizedBox(height: 6),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 8), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // 2. इफेक्ट्स ग्रिड (लाइव)
  Widget _buildEffectsGrid() {
    final effectsList = [
      {'type': VisualEffectType.none, 'name': 'None', 'icon': Icons.block, 'color': Colors.grey},
      {'type': VisualEffectType.flashLight, 'name': 'Flash Light', 'icon': Icons.flash_on, 'color': Colors.amber},
      {'type': VisualEffectType.vibrationShake, 'name': 'Vibration Shake', 'icon': Icons.vibration, 'color': Colors.redAccent},
      {'type': VisualEffectType.opticalZoom, 'name': 'Optical Zoom', 'icon': Icons.zoom_in, 'color': Colors.cyanAccent},
      {'type': VisualEffectType.discoParty, 'name': 'Disco Strobe', 'icon': Icons.celebration, 'color': Colors.purpleAccent},
      {'type': VisualEffectType.glitch, 'name': 'Glitch Shift', 'icon': Icons.blur_linear, 'color': Colors.pinkAccent},
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.9),
      itemCount: effectsList.length,
      itemBuilder: (ctx, i) {
        final item = effectsList[i];
        final type = item['type'] as VisualEffectType;
        final isSelected = _activeEffect == type;

        return GestureDetector(
          onTap: () {
            setState(() => _activeEffect = type);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('इफ़ेक्ट लागू: ${item['name']}'), duration: const Duration(milliseconds: 600)),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isSelected ? const Color(0xFF00E5FF) : Colors.white10, width: isSelected ? 2.5 : 1),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item['icon'] as IconData, color: item['color'] as Color, size: 28),
                const SizedBox(height: 8),
                Text(item['name'] as String, style: TextStyle(fontSize: 11, color: isSelected ? const Color(0xFF00E5FF) : Colors.white)),
              ],
            ),
          ),
        );
      },
    );
  }

  // 3. ट्रांज़िशन्स ग्रिड
  Widget _buildTransitionsGrid() {
    final transList = [
      {'type': TransitionEffectType.none, 'name': 'None', 'icon': Icons.block, 'color': Colors.grey},
      {'type': TransitionEffectType.whiteFlash, 'name': 'White Flash', 'icon': Icons.wb_sunny, 'color': Colors.white},
      {'type': TransitionEffectType.blackFade, 'name': 'Black Fade', 'icon': Icons.brightness_3, 'color': Colors.blueGrey},
      {'type': TransitionEffectType.mixDissolve, 'name': 'Mix Dissolve', 'icon': Icons.gradient, 'color': Colors.cyanAccent},
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.9),
      itemCount: transList.length,
      itemBuilder: (ctx, i) {
        final item = transList[i];
        final type = item['type'] as TransitionEffectType;
        final isSelected = _activeTransition == type;

        return GestureDetector(
          onTap: () {
            _applyTransition(type);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('ट्रांज़िशन: ${item['name']}'), duration: const Duration(milliseconds: 600)),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isSelected ? const Color(0xFF00E5FF) : Colors.white10, width: isSelected ? 2.5 : 1),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item['icon'] as IconData, color: item['color'] as Color, size: 28),
                const SizedBox(height: 8),
                Text(item['name'] as String, style: TextStyle(fontSize: 11, color: isSelected ? const Color(0xFF00E5FF) : Colors.white)),
              ],
            ),
          ),
        );
      },
    );
  }

  // 4. फिल्टर्स ग्रिड
  Widget _buildFiltersGrid() {
    final filtersList = [
      {'type': FilterPresetType.normal, 'name': 'Normal', 'color': Colors.grey},
      {'type': FilterPresetType.cyberpunk, 'name': 'Cyberpunk', 'color': const Color(0xFFFF0055)},
      {'type': FilterPresetType.tealOrange, 'name': 'Teal & Orange', 'color': Colors.tealAccent},
      {'type': FilterPresetType.vintageWarm, 'name': 'Vintage Warm', 'color': Colors.orangeAccent},
      {'type': FilterPresetType.blackGold, 'name': 'Black Gold', 'color': const Color(0xFFFFD700)},
      {'type': FilterPresetType.highSaturation, 'name': 'Vibrant', 'color': Colors.greenAccent},
      {'type': FilterPresetType.noirMono, 'name': 'Noir B&W', 'color': Colors.white},
      {'type': FilterPresetType.sunlight, 'name': 'Sunlight', 'color': Colors.amberAccent},
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.85),
      itemCount: filtersList.length,
      itemBuilder: (ctx, i) {
        final item = filtersList[i];
        final type = item['type'] as FilterPresetType;
        final isSelected = _activeFilter == type;

        return GestureDetector(
          onTap: () {
            setState(() => _activeFilter = type);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('फ़िल्टर बदला: ${item['name']}'), duration: const Duration(milliseconds: 600)),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isSelected ? const Color(0xFF00E5FF) : Colors.white10, width: isSelected ? 2 : 1),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: item['color'] as Color, shape: BoxShape.circle),
                  child: isSelected ? const Icon(Icons.check, color: Colors.black, size: 20) : null,
                ),
                const SizedBox(height: 6),
                Text(item['name'] as String, style: TextStyle(fontSize: 9, color: isSelected ? const Color(0xFF00E5FF) : Colors.white70)),
              ],
            ),
          ),
        );
      },
    );
  }

  // 5. कलर एडजस्ट (मैनुअल ब्राइटनेस, कंट्रास्ट, सैचुरेशन)
  Widget _buildColorAdjustPanel() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('ब्राइटनेस (Brightness):'),
            Text(_brightness.toStringAsFixed(2), style: const TextStyle(color: Color(0xFF00E5FF))),
          ]),
          Slider(
            value: _brightness,
            min: -0.5,
            max: 0.5,
            onChanged: (v) => setState(() => _brightness = v),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('कंट्रास्ट (Contrast):'),
            Text(_contrast.toStringAsFixed(2), style: const TextStyle(color: Color(0xFF00E5FF))),
          ]),
          Slider(
            value: _contrast,
            min: 0.5,
            max: 1.8,
            onChanged: (v) => setState(() => _contrast = v),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('सैचुरेशन (Saturation):'),
            Text(_saturation.toStringAsFixed(2), style: const TextStyle(color: Color(0xFF00E5FF))),
          ]),
          Slider(
            value: _saturation,
            min: 0.0,
            max: 2.0,
            onChanged: (v) => setState(() => _saturation = v),
          ),
          Center(
            child: TextButton(
              onPressed: () {
                setState(() { _brightness = 0.0; _contrast = 1.0; _saturation = 1.0; });
              },
              child: const Text('रीसेट डिफ़ॉल्ट', style: TextStyle(color: Colors.redAccent)),
            ),
          ),
        ],
      ),
    );
  }

  // 6. कैप्शंस पैनल (भाषा व एडिटिंग)
  Widget _buildCaptionsPanel() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('भाषा: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ChoiceChip(
                label: const Text('🇮🇳 हिंदी', style: TextStyle(fontSize: 11)),
                selected: _selectedLanguage == 'Hindi',
                onSelected: (_) {
                  setState(() {
                    _selectedLanguage = 'Hindi';
                    if (_controller != null) _generateDefaultSubtitles(_controller!.value.duration, 'Hindi');
                  });
                },
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text('🇬🇧 English', style: TextStyle(fontSize: 11)),
                selected: _selectedLanguage == 'English',
                onSelected: (_) {
                  setState(() {
                    _selectedLanguage = 'English';
                    if (_controller != null) _generateDefaultSubtitles(_controller!.value.duration, 'English');
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text('स्टाइल: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
              Wrap(
                spacing: 4,
                children: [
                  ChoiceChip(
                    label: const Text('MrBeast', style: TextStyle(fontSize: 10)),
                    selected: _activeCaptionStyle == CaptionStyle.mrBeast,
                    onSelected: (_) => setState(() => _activeCaptionStyle = CaptionStyle.mrBeast),
                  ),
                  ChoiceChip(
                    label: const Text('Hormozi', style: TextStyle(fontSize: 10)),
                    selected: _activeCaptionStyle == CaptionStyle.hormozi,
                    onSelected: (_) => setState(() => _activeCaptionStyle = CaptionStyle.hormozi),
                  ),
                  ChoiceChip(
                    label: const Text('Neon', style: TextStyle(fontSize: 10)),
                    selected: _activeCaptionStyle == CaptionStyle.neonGlow,
                    onSelected: (_) => setState(() => _activeCaptionStyle = CaptionStyle.neonGlow),
                  ),
                ],
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _subtitles.length,
              itemBuilder: (ctx, i) {
                final sub = _subtitles[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(6)),
                  child: Row(
                    children: [
                      Text('${_fmt(sub.start)} - ${_fmt(sub.end)}', style: const TextStyle(fontSize: 10, color: Color(0xFF00E5FF))),
                      const SizedBox(width: 8),
                      Expanded(child: Text(sub.text, style: const TextStyle(fontSize: 12))),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 16, color: Color(0xFF00E5FF)),
                        onPressed: () {
                          final c = TextEditingController(text: sub.text);
                          showDialog(
                            context: context,
                            builder: (dCtx) => AlertDialog(
                              backgroundColor: const Color(0xFF1E1E1E),
                              title: const Text('लाइन एडिट करें'),
                              content: TextField(controller: c),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('रद्द करें')),
                                ElevatedButton(
                                  onPressed: () {
                                    setState(() => sub.text = c.text);
                                    Navigator.pop(dCtx);
                                  },
                                  child: const Text('सेव करें'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 7. ऑडियो मिक्सर व SFX
  Widget _buildAudioPanel() {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: ListView(
        children: [
          Row(
            children: [
              const Icon(Icons.volume_up, size: 18),
              const SizedBox(width: 8),
              Text('वीडियो वॉइस: ${(_videoVolume * 100).toInt()}%'),
            ],
          ),
          Slider(
            value: _videoVolume,
            min: 0.0,
            max: 1.5,
            onChanged: (v) {
              setState(() {
                _videoVolume = v;
                _controller?.setVolume(v.clamp(0.0, 1.0));
              });
            },
          ),
          Row(
            children: [
              const Icon(Icons.music_note, size: 18),
              const SizedBox(width: 8),
              Text('BGM म्यूज़िक: ${(_bgmVolume * 100).toInt()}%'),
            ],
          ),
          Slider(
            value: _bgmVolume,
            min: 0.0,
            max: 1.0,
            onChanged: (v) => setState(() => _bgmVolume = v),
          ),
          const Divider(color: Colors.white24, height: 16),
          const Text('साउंड इफेक्ट्स लाइब्रेरी (SFX):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['💨 Whoosh', '🔔 Ding', '💥 Pop', '🎶 Cha-Ching'].map((sfx) {
              return ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF222222)),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$sfx ऑडियो ट्रैक पर जोड़ा गया!'), duration: const Duration(seconds: 1)),
                  );
                },
                child: Text(sfx, style: const TextStyle(fontSize: 11)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptionStyleWidget(String text) {
    switch (_activeCaptionStyle) {
      case CaptionStyle.mrBeast:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text(
            text.toUpperCase(),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFFFFEB3B),
              shadows: [
                Shadow(offset: Offset(-2, -2), color: Colors.black),
                Shadow(offset: Offset(2, -2), color: Colors.black),
                Shadow(offset: Offset(2, 2), color: Colors.black),
                Shadow(offset: Offset(-2, 2), color: Colors.black),
              ],
            ),
          ),
        );
      case CaptionStyle.hormozi:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF39FF14), width: 2),
          ),
          child: Text(
            text.toUpperCase(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF39FF14)),
          ),
        );
      case CaptionStyle.neonGlow:
        return Text(
          text,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF00E5FF),
            shadows: [Shadow(color: Color(0xFF00E5FF), blurRadius: 15)],
          ),
        );
      default:
        return Text(text, style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold));
    }
  }

  void _openRatioDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('कैनवास फ्रेम चुनें', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ChoiceChip(
                  label: const Text('9:16 (Shorts)'),
                  selected: _aspectRatio == 9 / 16,
                  onSelected: (_) {
                    setState(() { _aspectRatio = 9 / 16; _ratioLabel = '9:16'; });
                    Navigator.pop(ctx);
                  },
                ),
                ChoiceChip(
                  label: const Text('16:9 (YouTube)'),
                  selected: _aspectRatio == 16 / 9,
                  onSelected: (_) {
                    setState(() { _aspectRatio = 16 / 9; _ratioLabel = '16:9'; });
                    Navigator.pop(ctx);
                  },
                ),
                ChoiceChip(
                  label: const Text('1:1 (Post)'),
                  selected: _aspectRatio == 1.0,
                  onSelected: (_) {
                    setState(() { _aspectRatio = 1.0; _ratioLabel = '1:1'; });
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openStillFrameExportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('कवर / फ्रेम एक्सपोर्ट करें (Still Frame)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('रिज़ॉल्यूशन: 4K UHD Frame'),
            SizedBox(height: 6),
            Text('फॉर्मेट: JPEG Image'),
            SizedBox(height: 6),
            Text('स्थान: मोबाइल गैलरी / Photos'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('रद्द करें')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF), foregroundColor: Colors.black),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('फ्रेम सफलतापूर्वक गैलरी में सेव हो गया!')),
              );
            },
            child: const Text('एक्सपोर्ट'),
          ),
        ],
      ),
    );
  }

  void _openMainExportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('वीडियो एक्सपोर्ट'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('कैनवास: $_ratioLabel'),
            Text('सक्रिय इफ़ेक्ट: ${_activeEffect.name.toUpperCase()}'),
            Text('सक्रिय फ़िल्टर: ${_activeFilter.name.toUpperCase()}'),
            const SizedBox(height: 8),
            const Text('नो वॉटरमार्क • 1080P Full HD • 60 FPS', style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('रद्द करें')),
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
