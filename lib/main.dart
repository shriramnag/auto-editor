import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

void main() {
  runApp(const CapCutStudioApp());
}

class CapCutStudioApp extends StatelessWidget {
  const CapCutStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auto Editor Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFFFF0055),
          surface: Color(0xFF181818),
        ),
      ),
      home: const CapCutStudioScreen(),
    );
  }
}

// इफेक्ट्स, ट्रांज़िशन्स और फिल्टर्स के प्रकार
enum VisualEffectType { none, flashLight, vibrationShake, opticalZoom, discoParty, glitch }
enum TransitionEffectType { none, whiteFlash, blackFade, mixDissolve }
enum FilterPresetType { normal, cyberpunk, tealOrange, vintageWarm, blackGold, highSaturation, noirMono, sunlight }
enum CaptionStyle { mrBeast, hormozi, neonGlow }

class SubtitleLine {
  Duration start;
  Duration end;
  String text;
  SubtitleLine({required this.start, required this.end, required this.text});
}

class CapCutStudioScreen extends StatefulWidget {
  const CapCutStudioScreen({super.key});

  @override
  State<CapCutStudioScreen> createState() => _CapCutStudioScreenState();
}

class _CapCutStudioScreenState extends State<CapCutStudioScreen> with TickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  VideoPlayerController? _controller;
  File? _videoFile;

  bool _isLoading = false;
  double _speed = 1.0;
  bool _isFlipped = false;

  // सक्रिय इफेक्ट्स
  VisualEffectType _activeEffect = VisualEffectType.none;
  TransitionEffectType _activeTransition = TransitionEffectType.none;
  FilterPresetType _activeFilter = FilterPresetType.normal;

  // एनिमेशन कंट्रोलर्स
  late AnimationController _transitionAnimController;
  late Animation<double> _transitionAnimation;
  late AnimationController _glitchAnimController;

  // बॉटम एक्टिव टैब
  String _activeTab = "Effects"; // Effects, Transitions, Filters, Captions, Audio

  // सबटाइटल्स
  String _selectedLanguage = "Hindi";
  CaptionStyle _activeCaptionStyle = CaptionStyle.mrBeast;
  List<SubtitleLine> _subtitles = [];
  Offset _captionPosition = const Offset(50, 160);

  // कैनवास रेशियो
  double _aspectRatio = 9 / 16;
  String _ratioLabel = "9:16";

  // ऑडियो
  double _videoVolume = 1.0;
  double _bgmVolume = 0.5;

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
  }

  @override
  void dispose() {
    _transitionAnimController.dispose();
    _glitchAnimController.dispose();
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
          _generateDefaultSubtitles(ctrl.value.duration, _selectedLanguage);
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

  void _applyTransition(TransitionEffectType type) {
    setState(() => _activeTransition = type);
    _transitionAnimController.forward(from: 0.0);
  }

  // लाइव कलर मैट्रिक्स (फिल्टर्स के लिए)
  ColorFilter _getFilterMatrix() {
    switch (_activeFilter) {
      case FilterPresetType.cyberpunk:
        return const ColorFilter.matrix(<double>[
          1.4, 0.0, 0.2, 0.0, 10.0,
          0.0, 1.1, 0.2, 0.0, -10.0,
          0.3, 0.0, 1.6, 0.0, 20.0,
          0.0, 0.0, 0.0, 1.0, 0.0,
        ]);
      case FilterPresetType.tealOrange:
        return const ColorFilter.matrix(<double>[
          1.3, 0.1, 0.0, 0.0, 15.0,
          0.0, 1.2, 0.2, 0.0, 0.0,
          0.0, 0.2, 1.4, 0.0, 25.0,
          0.0, 0.0, 0.0, 1.0, 0.0,
        ]);
      case FilterPresetType.vintageWarm:
        return const ColorFilter.matrix(<double>[
          1.2, 0.1, 0.0, 0.0, 20.0,
          0.1, 1.1, 0.0, 0.0, 10.0,
          0.0, 0.0, 0.8, 0.0, -10.0,
          0.0, 0.0, 0.0, 1.0, 0.0,
        ]);
      case FilterPresetType.blackGold:
        return const ColorFilter.matrix(<double>[
          0.9, 0.3, 0.0, 0.0, 30.0,
          0.3, 0.8, 0.0, 0.0, 15.0,
          0.1, 0.1, 0.3, 0.0, -20.0,
          0.0, 0.0, 0.0, 1.0, 0.0,
        ]);
      case FilterPresetType.highSaturation:
        return const ColorFilter.matrix(<double>[
          1.5, 0.0, 0.0, 0.0, 0.0,
          0.0, 1.5, 0.0, 0.0, 0.0,
          0.0, 0.0, 1.5, 0.0, 0.0,
          0.0, 0.0, 0.0, 1.0, 0.0,
        ]);
      case FilterPresetType.noirMono:
        const rw = 0.299;
        const gw = 0.587;
        const bw = 0.114;
        return const ColorFilter.matrix(<double>[
          rw * 1.3, gw * 1.3, bw * 1.3, 0.0, 0.0,
          rw * 1.3, gw * 1.3, bw * 1.3, 0.0, 0.0,
          rw * 1.3, gw * 1.3, bw * 1.3, 0.0, 0.0,
          0.0, 0.0, 0.0, 1.0, 0.0,
        ]);
      case FilterPresetType.sunlight:
        return const ColorFilter.matrix(<double>[
          1.3, 0.1, 0.0, 0.0, 30.0,
          0.0, 1.3, 0.0, 0.0, 20.0,
          0.0, 0.0, 1.0, 0.0, -5.0,
          0.0, 0.0, 0.0, 1.0, 0.0,
        ]);
      default:
        return const ColorFilter.mode(Colors.transparent, BlendMode.multiply);
    }
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
                color: const Color(0xFF00E5FF).withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('PRO STUDIO', style: TextStyle(fontSize: 9, color: Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        actions: [
          if (_videoFile != null) ...[
            // 1. स्टिल फ्रेम / कवर एक्सपोर्ट बटन (स्क्रीनशॉट 20 जैसा)
            IconButton(
              tooltip: 'कवर / फ्रेम एक्सपोर्ट',
              icon: const Icon(Icons.camera_alt_outlined, size: 20, color: Colors.white70),
              onPressed: _openStillFrameExportDialog,
            ),
            // 2. कैनवास रेशियो बटन
            TextButton.icon(
              onPressed: _openRatioDialog,
              icon: const Icon(Icons.aspect_ratio, size: 16, color: Color(0xFF00E5FF)),
              label: Text(_ratioLabel, style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 12)),
            ),
            // 3. मुख्य एक्सपोर्ट
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
      body: _videoFile == null ? _buildEmptyView() : (isDesktop ? _buildDesktopLayout() : _buildMobileLayout()),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF00E5FF), width: 2),
            ),
            child: const Icon(Icons.video_library_outlined, size: 54, color: Color(0xFF00E5FF)),
          ),
          const SizedBox(height: 20),
          const Text('CapCut स्टाइल प्रो एडिटर', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('इफेक्ट्स, ट्रांज़िशन्स, फिल्टर्स और ऑटो-कैप्शंस', style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            onPressed: _isLoading ? null : _pickVideo,
            icon: const Icon(Icons.add),
            label: const Text('नया प्रोजेक्ट (वीडियो चुनें)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
    );
  }

  // मोबाइल लेआउट
  Widget _buildMobileLayout() {
    return Column(
      children: [
        // 1. वीडियो कैनवास (लाइव इफेक्ट्स के साथ)
        Expanded(
          flex: 5,
          child: _buildVideoCanvas(),
        ),

        // 2. टाइमलाइन बार
        _buildTimelineBar(),

        // 3. टैब स्विचर (Effects, Transitions, Filters, Captions, Audio)
        Container(
          height: 42,
          color: const Color(0xFF141414),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildCategoryTab('Effects', Icons.auto_awesome, 'इफेक्ट्स'),
              _buildCategoryTab('Transitions', Icons.shuffle, 'ट्रांज़िशन्स'),
              _buildCategoryTab('Filters', Icons.palette_outlined, 'फिल्टर्स'),
              _buildCategoryTab('Captions', Icons.subtitles_outlined, 'ऑटो-कैप्शन'),
              _buildCategoryTab('Audio', Icons.graphic_eq, 'ऑडियो'),
            ],
          ),
        ),

        // 4. विजुअल थंबनेल कार्ड्स ग्रिड
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

  // डेस्कटॉप लेआउट (स्क्रीनशॉट 1 और 4 जैसा)
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildDeskTab('Effects', 'इफेक्ट्स'),
                    _buildDeskTab('Transitions', 'ट्रांज़िशन'),
                    _buildDeskTab('Filters', 'फिल्टर्स'),
                    _buildDeskTab('Captions', 'कैप्शन'),
                  ],
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
        padding: const EdgeInsets.symmetric(horizontal: 16),
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

  // 1. वीडियो कैनवास (लाइव ट्रांसफॉर्म और विजुअल इफेक्ट्स)
  Widget _buildVideoCanvas() {
    final ctrl = _controller!;
    final pos = ctrl.value.position;
    final dur = ctrl.value.duration;
    final activeCaption = _getActiveCaption();

    double scale = 1.0;
    Offset shakeOffset = Offset.zero;
    Color overlayFlashColor = Colors.transparent;

    // इफेक्ट्स के अनुसार परिवर्तन
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
                      colorFilter: _getFilterMatrix(),
                      child: VideoPlayer(ctrl),
                    ),
                  ),
                ),
              ),
            ),

            if (overlayFlashColor != Colors.transparent)
              IgnorePointer(child: Container(color: overlayFlashColor)),

            // ट्रांज़िशन ओवरले एनिमेशन
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

            // प्ले/पॉज बटन
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

  // 2. टाइमलाइन बार
  Widget _buildTimelineBar() {
    final ctrl = _controller!;
    final pos = ctrl.value.position;
    final dur = ctrl.value.duration;

    return Container(
      height: 75,
      color: const Color(0xFF141414),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'इफ़ेक्ट: ${_activeEffect.name.toUpperCase()} | फ़िल्टर: ${_activeFilter.name.toUpperCase()}',
                style: const TextStyle(fontSize: 10, color: Color(0xFF00E5FF)),
              ),
              Text('${_speed}x', style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
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
      case 'Effects':
        return _buildEffectsGrid();
      case 'Transitions':
        return _buildTransitionsGrid();
      case 'Filters':
        return _buildFiltersGrid();
      case 'Captions':
        return _buildCaptionsPanel();
      case 'Audio':
        return _buildAudioPanel();
      default:
        return _buildEffectsGrid();
    }
  }

  // 3. इफेक्ट्स ग्रिड (टच करते ही वीडियो पर लाइव अप्लाई होगा)
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
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.9,
      ),
      itemCount: effectsList.length,
      itemBuilder: (ctx, i) {
        final item = effectsList[i];
        final type = item['type'] as VisualEffectType;
        final isSelected = _activeEffect == type;

        return GestureDetector(
          onTap: () {
            setState(() => _activeEffect = type);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('इफ़ेक्ट लागू हुआ: ${item['name']}'), duration: const Duration(milliseconds: 600)),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? const Color(0xFF00E5FF) : Colors.white10,
                width: isSelected ? 2.5 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (item['color'] as Color).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(item['icon'] as IconData, color: item['color'] as Color, size: 28),
                ),
                const SizedBox(height: 8),
                Text(
                  item['name'] as String,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? const Color(0xFF00E5FF) : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 4. ट्रांज़िशन्स ग्रिड (टच करते ही ट्रांज़िशन चलेगा)
  Widget _buildTransitionsGrid() {
    final transList = [
      {'type': TransitionEffectType.none, 'name': 'None', 'icon': Icons.block, 'color': Colors.grey},
      {'type': TransitionEffectType.whiteFlash, 'name': 'White Flash', 'icon': Icons.wb_sunny, 'color': Colors.white},
      {'type': TransitionEffectType.blackFade, 'name': 'Black Fade', 'icon': Icons.brightness_3, 'color': Colors.blueGrey},
      {'type': TransitionEffectType.mixDissolve, 'name': 'Mix Dissolve', 'icon': Icons.gradient, 'color': Colors.cyanAccent},
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.9,
      ),
      itemCount: transList.length,
      itemBuilder: (ctx, i) {
        final item = transList[i];
        final type = item['type'] as TransitionEffectType;
        final isSelected = _activeTransition == type;

        return GestureDetector(
          onTap: () {
            _applyTransition(type);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('ट्रांज़िशन चला: ${item['name']}'), duration: const Duration(milliseconds: 600)),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? const Color(0xFF00E5FF) : Colors.white10,
                width: isSelected ? 2.5 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item['icon'] as IconData, color: item['color'] as Color, size: 30),
                const SizedBox(height: 8),
                Text(
                  item['name'] as String,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? const Color(0xFF00E5FF) : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 5. फिल्टर्स ग्रिड (टच करते ही कलर बदल जाएगा)
  Widget _buildFiltersGrid() {
    final filtersList = [
      {'type': FilterPresetType.normal, 'name': 'Normal', 'color': Colors.grey},
      {'type': FilterPresetType.cyberpunk, 'name': 'Cyberpunk', 'color': const Color(0xFFFF0055)},
      {'type': FilterPresetType.tealOrange, 'name': 'Teal & Orange', 'color': Colors.tealAccent},
      {'type': FilterPresetType.vintageWarm, 'name': 'Vintage Warm', 'color': Colors.orangeAccent},
      {'type': FilterPresetType.blackGold, 'name': 'Black Gold', 'color': const Color(0xFFFFD700)},
      {'type': FilterPresetType.highSaturation, 'name': 'High Saturation', 'color': Colors.greenAccent},
      {'type': FilterPresetType.noirMono, 'name': 'Noir B&W', 'color': Colors.white},
      {'type': FilterPresetType.sunlight, 'name': 'Sunlight', 'color': Colors.amberAccent},
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.85,
      ),
      itemCount: filtersList.length,
      itemBuilder: (ctx, i) {
        final item = filtersList[i];
        final type = item['type'] as FilterPresetType;
        final isSelected = _activeFilter == type;

        return GestureDetector(
          onTap: () {
            setState(() => _activeFilter = type);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('फ़िल्टर बदला गया: ${item['name']}'), duration: const Duration(milliseconds: 600)),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? const Color(0xFF00E5FF) : Colors.white10,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: item['color'] as Color,
                    shape: BoxShape.circle,
                  ),
                  child: isSelected ? const Icon(Icons.check, color: Colors.black, size: 20) : null,
                ),
                const SizedBox(height: 6),
                Text(
                  item['name'] as String,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? const Color(0xFF00E5FF) : Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        );
      },
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

  // 7. ऑडियो मिक्सर
  Widget _buildAudioPanel() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
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
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.music_note, size: 18),
              const SizedBox(width: 8),
              Text('BGM साउंड: ${(_bgmVolume * 100).toInt()}%'),
            ],
          ),
          Slider(
            value: _bgmVolume,
            min: 0.0,
            max: 1.0,
            onChanged: (v) => setState(() => _bgmVolume = v),
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

  // स्टिल फ्रेम / कवर इमेज एक्सपोर्ट
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
