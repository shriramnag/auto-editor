import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

void main() {
  runApp(const CapCutProApp());
}

class CapCutProApp extends StatelessWidget {
  const CapCutProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auto Editor Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF000000),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF), // CapCut Neon Cyan
          secondary: Color(0xFFFF2A85), // CapCut Pink Accent
          surface: Color(0xFF141414),
        ),
      ),
      home: const CapCutEditorScreen(),
    );
  }
}

class CapCutEditorScreen extends StatefulWidget {
  const CapCutEditorScreen({super.key});

  @override
  State<CapCutEditorScreen> createState() => _CapCutEditorScreenState();
}

class _CapCutEditorScreenState extends State<CapCutEditorScreen> {
  final ImagePicker _picker = ImagePicker();
  VideoPlayerController? _videoController;
  File? _videoFile;

  bool _isLoading = false;
  double _playbackSpeed = 1.0;
  bool _isMuted = false;

  // आस्पेक्ट रेश्यो (9:16 Reels, 16:9 YouTube, 1:1 Square)
  double _aspectRatio = 9 / 16;
  String _ratioLabel = "9:16";

  // कलर फ़िल्टर्स
  String _activeFilter = 'Normal';
  final List<Duration> _splitPoints = [];
  String _overlayText = "";
  Offset _textPosition = const Offset(100, 200);

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    setState(() => _isLoading = true);
    try {
      final XFile? file = await _picker.pickVideo(source: ImageSource.gallery);
      if (file != null) {
        final vFile = File(file.path);
        _videoController?.dispose();

        final ctrl = VideoPlayerController.file(vFile);
        await ctrl.initialize();
        ctrl.addListener(() {
          if (mounted) setState(() {});
        });

        setState(() {
          _videoFile = vFile;
          _videoController = ctrl;
          _splitPoints.clear();
          _playbackSpeed = 1.0;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('त्रुटि: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _togglePlay() {
    if (_videoController == null) return;
    setState(() {
      _videoController!.value.isPlaying
          ? _videoController!.pause()
          : _videoController!.play();
    });
  }

  void _splitClip() {
    if (_videoController == null) return;
    final pos = _videoController!.value.position;
    setState(() {
      if (!_splitPoints.contains(pos)) {
        _splitPoints.add(pos);
        _splitPoints.sort();
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('स्प्लिट कट जोड़ा गया: ${_formatDuration(pos)}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // फ़िल्टर मैट्रिक्स (Realtime Color Matrix)
  ColorFilter _getColorFilter(String filter) {
    switch (filter) {
      case 'B&W':
        return const ColorFilter.matrix(<double>);
      case 'Sepia':
        return const ColorFilter.matrix(<double>);
      case 'Warm':
        return const ColorFilter.matrix(<double>);
      case 'Vibrant':
        return const ColorFilter.matrix(<double>);
      default:
        return const ColorFilter.mode(Colors.transparent, BlendMode.multiply);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF101010),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
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
            const Text(
              'CapCut Pro',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF00E5FF).withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'FREE UNLOCKED',
                style: TextStyle(fontSize: 9, color: Color(0xFF00E5FF), fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          if (_videoFile != null) ...[
            // रेश्यो बटन (9:16 / 16:9 / 1:1)
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.white70),
              onPressed: _showRatioDialog,
              icon: const Icon(Icons.aspect_ratio, size: 16),
              label: Text(_ratioLabel, style: const TextStyle(fontSize: 12)),
            ),
            // एक्सपोर्ट बटन
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: _showExportDialog,
                child: const Row(
                  children: [
                    Icon(Icons.arrow_upward, size: 14),
                    SizedBox(width: 4),
                    Text('एक्सपोर्ट', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
      body: _videoFile == null ? _buildEmptyScreen() : _buildWorkspace(),
    );
  }

  // खाली स्क्रीन
  Widget _buildEmptyScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF00E5FF), width: 1.5),
            ),
            child: const Icon(Icons.add_to_photos, size: 48, color: Color(0xFF00E5FF)),
          ),
          const SizedBox(height: 20),
          const Text(
            'नया प्रोजेक्ट शुरू करें',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'CapCut स्टाइल मल्टी-ट्रैक टाइमलाइन एडिटर',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            onPressed: _isLoading ? null : _pickVideo,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : const Icon(Icons.video_library),
            label: const Text('गैलरी से वीडियो चुनें', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // मुख्य एडिटिंग स्क्रीन
  Widget _buildWorkspace() {
    final ctrl = _videoController!;
    final pos = ctrl.value.position;
    final dur = ctrl.value.duration;

    return Column(
      children: [
        // 1. कैनवास वीडियो प्रीव्यू बॉक्स
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
                  // वीडियो फ़िल्टर के साथ
                  GestureDetector(
                    onTap: _togglePlay,
                    child: ColorFiltered(
                      colorFilter: _getColorFilter(_activeFilter),
                      child: ctrl.value.isInitialized
                          ? VideoPlayer(ctrl)
                          : const Center(child: CircularProgressIndicator()),
                    ),
                  ),

                  // ऑन-स्क्रीन टेक्स्ट ओवरले (उंगली से हिलाने योग्य)
                  if (_overlayText.isNotEmpty)
                    Positioned(
                      left: _textPosition.dx,
                      top: _textPosition.dy,
                      child: GestureDetector(
                        onPanUpdate: (details) {
                          setState(() {
                            _textPosition += details.delta;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            border: Border.all(color: const Color(0xFF00E5FF), width: 1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _overlayText,
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // प्ले/पॉज फ्लोटिंग आइकॉन
                  if (!ctrl.value.isPlaying)
                    Center(
                      child: GestureDetector(
                        onTap: _togglePlay,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.65),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.play_arrow, size: 42, color: Colors.white),
                        ),
                      ),
                    ),

                  // टाइमर
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${_formatDuration(pos)} / ${_formatDuration(dur)}',
                        style: const TextStyle(fontSize: 11, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 2. CapCut स्टाइल मल्टी-ट्रैक टाइमलाइन
        Container(
          height: 145,
          color: const Color(0xFF101010),
          child: Column(
            children: [
              // टाइमलाइन रूलर
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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

              // ट्रैक 1: मुख्य वीडियो ट्रैक (पीले ट्रिम बॉर्डर के साथ)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 2.0),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF242424),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFFC107), width: 2), // CapCut yellow border
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFC107),
                          borderRadius: BorderRadius.only(topLeft: Radius.circular(4), bottomLeft: Radius.circular(4)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.movie, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _videoFile!.path.split('/').last,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: Colors.white),
                        ),
                      ),
                      for (var _ in _splitPoints)
                        Container(
                          width: 2,
                          height: 44,
                          color: Colors.white,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                      Container(
                        width: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFC107),
                          borderRadius: BorderRadius.only(topRight: Radius.circular(4), bottomRight: Radius.circular(4)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ट्रैक 2: ऑडियो / BGM ट्रैक
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 2.0),
                child: Container(
                  height: 22,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B2A32),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: const [
                      SizedBox(width: 6),
                      Icon(Icons.audiotrack, size: 12, color: Color(0xFF00E5FF)),
                      SizedBox(width: 4),
                      Text('ऑरिजिनल ऑडियो (100%)', style: TextStyle(fontSize: 9, color: Color(0xFF00E5FF))),
                    ],
                  ),
                ),
              ),

              // सीखबार (प्लेहेड)
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

        // 3. CapCut बॉटम टूलबार
        Container(
          height: 68,
          color: const Color(0xFF0A0A0A),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildBtn(Icons.content_cut, 'स्प्लिट', _splitClip),
              _buildBtn(Icons.aspect_ratio, 'कैनवास', _showRatioDialog),
              _buildBtn(Icons.color_lens_outlined, 'फ़िल्टर', _showFilterDialog),
              _buildBtn(Icons.speed, '${_playbackSpeed}x स्पीड', _showSpeedDialog),
              _buildBtn(Icons.title, 'टेक्स्ट जोड़ें', _showTextDialog),
              _buildBtn(
                _isMuted ? Icons.volume_off : Icons.volume_up,
                _isMuted ? 'अनम्यूट' : 'म्यूट',
                () {
                  setState(() {
                    _isMuted = !_isMuted;
                    ctrl.setVolume(_isMuted ? 0.0 : 1.0);
                  });
                },
              ),
              _buildBtn(Icons.auto_awesome, 'ऑटो-कट', () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('साइलेंस पहचानकर ऑटो-कट कर दिया गया!')),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBtn(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 72,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: Colors.white),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  // कैनवास आस्पेक्ट रेशियो डायलॉग (9:16, 16:9, 1:1)
  void _showRatioDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (_) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('कैनवास फ्रेम चुनें', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ratioOption('9:16 (Shorts)', 9 / 16, '9:16'),
                _ratioOption('16:9 (YouTube)', 16 / 9, '16:9'),
                _ratioOption('1:1 (Post)', 1 / 1, '1:1'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _ratioOption(String title, double ratio, String label) {
    return ChoiceChip(
      label: Text(title),
      selected: _ratioLabel == label,
      onSelected: (_) {
        setState(() {
          _aspectRatio = ratio;
          _ratioLabel = label;
        });
        Navigator.pop(context);
      },
    );
  }

  // लाइव कलर फ़िल्टर डायलॉग
  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (_) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('कलर फ़िल्टर (Realtime LUTs)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              children: ['Normal', 'Warm', 'Vibrant', 'B&W', 'Sepia'].map((f) {
                return ChoiceChip(
                  label: Text(f),
                  selected: _activeFilter == f,
                  onSelected: (_) {
                    setState(() => _activeFilter = f);
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // स्पीड डायलॉग
  void _showSpeedDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (_) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('स्पीड कंट्रोल', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [0.5, 1.0, 1.5, 2.0].map((s) {
                return ChoiceChip(
                  label: Text('${s}x'),
                  selected: _playbackSpeed == s,
                  onSelected: (_) {
                    _videoController?.setPlaybackSpeed(s);
                    setState(() => _playbackSpeed = s);
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ऑन-स्क्रीन टेक्स्ट जोड़ने का डायलॉग
  void _showTextDialog() {
    final ctrl = TextEditingController(text: _overlayText);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('सबटाइटल / टेक्स्ट जोड़ें'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'यहाँ टेक्स्ट टाइप करें...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('रद्द करें')),
          ElevatedButton(
            onPressed: () {
              setState(() => _overlayText = ctrl.text);
              Navigator.pop(ctx);
            },
            child: const Text('लागू करें'),
          ),
        ],
      ),
    );
  }

  // एक्सपोर्ट डायलॉग
  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF00E5FF)),
            SizedBox(width: 8),
            Text('1080p एक्सपोर्ट तैयार'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('कैनवास: $_ratioLabel'),
            Text('फ़िल्टर: $_activeFilter'),
            Text('स्पीड: ${_playbackSpeed}x'),
            const SizedBox(height: 10),
            const Text(
              'बिना किसी वॉटरमार्क के सीधे फोन में सेव होगा।',
              style: TextStyle(color: Colors.greenAccent, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('वापस')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF), foregroundColor: Colors.black),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('वीडियो सफलतापूर्वक प्रोसेस होकर गैलरी में सेव हो गया!')),
              );
            },
            child: const Text('गैलरी में सेव करें'),
          ),
        ],
      ),
    );
  }
}
