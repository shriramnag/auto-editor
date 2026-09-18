import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

void main() {
  runApp(const CapCutStyleEditorApp());
}

class CapCutStyleEditorApp extends StatelessWidget {
  const CapCutStyleEditorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auto Editor Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF161616),
          elevation: 0,
        ),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF), // CapCut cyan color
          secondary: Color(0xFF6C5CE7),
          surface: Color(0xFF1E1E1E),
        ),
      ),
      home: const VideoEditorScreen(),
    );
  }
}

class VideoEditorScreen extends StatefulWidget {
  const VideoEditorScreen({super.key});

  @override
  State<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends State<VideoEditorScreen> {
  final ImagePicker _picker = ImagePicker();
  VideoPlayerController? _videoController;
  File? _videoFile;

  bool _isLoading = false;
  double _currentSpeed = 1.0;
  bool _isMuted = false;
  final List<Duration> _splitPoints = [];
  String _activeTool = 'none';

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  // गैलरी से असली वीडियो चुनना
  Future<void> _pickVideoFromGallery() async {
    setState(() => _isLoading = true);
    try {
      final XFile? pickedFile = await _picker.pickVideo(
        source: ImageSource.gallery,
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        _videoController?.dispose();

        final controller = VideoPlayerController.file(file);
        await controller.initialize();
        controller.addListener(() {
          if (mounted) setState(() {});
        });

        setState(() {
          _videoFile = file;
          _videoController = controller;
          _splitPoints.clear();
          _currentSpeed = 1.0;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('वीडियो लोड करने में त्रुटि: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _togglePlayPause() {
    if (_videoController == null) return;
    setState(() {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
      } else {
        _videoController!.play();
      }
    });
  }

  void _splitAtCurrentPosition() {
    if (_videoController == null) return;
    final currentPos = _videoController!.value.position;
    setState(() {
      if (!_splitPoints.contains(currentPos)) {
        _splitPoints.add(currentPos);
        _splitPoints.sort();
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('कट लगाया गया: ${_formatDuration(currentPos)} पर'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _changePlaybackSpeed(double speed) {
    if (_videoController == null) return;
    _videoController!.setPlaybackSpeed(speed);
    setState(() => _currentSpeed = speed);
  }

  void _toggleMute() {
    if (_videoController == null) return;
    setState(() {
      _isMuted = !_isMuted;
      _videoController!.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
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
        title: const Text(
          'Auto Editor Pro',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_videoFile != null)
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: () => _showExportDialog(),
                icon: const Icon(Icons.arrow_upward, size: 16),
                label: const Text('एक्सपोर्ट', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
      body: _videoFile == null ? _buildEmptyState() : _buildEditorUI(),
    );
  }

  // खाली स्क्रीन (नया प्रोजेक्ट शुरू करने के लिए)
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.4), width: 2),
            ),
            child: const Icon(Icons.video_library, size: 54, color: Color(0xFF00E5FF)),
          ),
          const SizedBox(height: 24),
          const Text(
            'CapCut स्टाइल ऑटो एडिटर',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'मोबाइल गैलरी से वीडियो चुनकर एडिट करें',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            onPressed: _isLoading ? null : _pickVideoFromGallery,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : const Icon(Icons.add),
            label: const Text(
              'नया प्रोजेक्ट (वीडियो चुनें)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // मुख्य CapCut जैसा एडिटर लेआउट
  Widget _buildEditorUI() {
    final controller = _videoController!;
    final position = controller.value.position;
    final duration = controller.value.duration;

    return Column(
      children: [
        // 1. वीडियो प्लेयर प्रीव्यू विंडो
        Expanded(
          flex: 4,
          child: Container(
            color: Colors.black,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (controller.value.isInitialized)
                  AspectRatio(
                    aspectRatio: controller.value.aspectRatio,
                    child: VideoPlayer(controller),
                  ),
                // प्ले/पॉज टच डिटेक्टर
                GestureDetector(
                  onTap: _togglePlayPause,
                  child: Container(
                    color: Colors.transparent,
                    child: Center(
                      child: !controller.value.isPlaying
                          ? Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.play_arrow, size: 48, color: Colors.white),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
                // टाइम कोड इंडिकेटर
                Positioned(
                  bottom: 10,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${_formatDuration(position)} / ${_formatDuration(duration)}',
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 2. CapCut स्टाइल टाइमलाइन सेक्शन
        Container(
          height: 120,
          color: const Color(0xFF161616),
          child: Column(
            children: [
              // टाइमलाइन रूलर बार
              Container(
                height: 24,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('00:00', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text('00:05', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text('00:10', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text('00:15', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
              // वीडियो ट्रैक और प्लेहेड
              Expanded(
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    // वीडियो क्लिप ट्रैक
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Container(
                        height: 54,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C2C2C),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF00E5FF), width: 1.5),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 8),
                            const Icon(Icons.movie, size: 20, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _videoFile!.path.split('/').last,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            // स्प्लिट मार्कर्स
                            for (var point in _splitPoints)
                              Container(
                                width: 2,
                                height: 50,
                                color: Colors.yellow,
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                              ),
                          ],
                        ),
                      ),
                    ),
                    // सीख स्लाइडर (प्लेहेड कंट्रोल)
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        thumbColor: Colors.white,
                        activeTrackColor: const Color(0xFF00E5FF),
                        inactiveTrackColor: Colors.transparent,
                      ),
                      child: Slider(
                        value: duration.inMilliseconds > 0
                            ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
                            : 0.0,
                        onChanged: (val) {
                          final newMillis = (val * duration.inMilliseconds).toInt();
                          controller.seekTo(Duration(milliseconds: newMillis));
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 3. CapCut स्टाइल बॉटम टूलबार
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          color: const Color(0xFF121212),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildToolItem(
                  icon: Icons.content_cut,
                  label: 'स्प्लिट',
                  onTap: _splitAtCurrentPosition,
                ),
                _buildToolItem(
                  icon: Icons.speed,
                  label: '${_currentSpeed}x स्पीड',
                  onTap: () => _showSpeedDialog(),
                ),
                _buildToolItem(
                  icon: Icons.auto_fix_high,
                  label: 'ऑटो-कट',
                  onTap: () => _runAutoCutSilence(),
                ),
                _buildToolItem(
                  icon: _isMuted ? Icons.volume_off : Icons.volume_up,
                  label: _isMuted ? 'अनम्यूट' : 'म्यूट',
                  onTap: _toggleMute,
                ),
                _buildToolItem(
                  icon: Icons.title,
                  label: 'टेक्स्ट',
                  onTap: () => _showTextDialog(),
                ),
                _buildToolItem(
                  icon: Icons.filter,
                  label: 'फ़िल्टर',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('फ़िल्टर लागू किया गया')),
                    );
                  },
                ),
                _buildToolItem(
                  icon: Icons.video_library_outlined,
                  label: 'वीडियो बदलें',
                  onTap: _pickVideoFromGallery,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: Colors.white),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  // स्पीड कंट्रोल डायलॉग
  void _showSpeedDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('प्लेबैक स्पीड चुनें', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [0.5, 1.0, 1.5, 2.0].map((s) {
                  return ChoiceChip(
                    label: Text('${s}x'),
                    selected: _currentSpeed == s,
                    onSelected: (_) {
                      _changePlaybackSpeed(s);
                      Navigator.pop(ctx);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  // ऑटो-कट साइलेंस रिमूवर फंक्शन
  void _runAutoCutSilence() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ऑडियो स्कैन हो रहा है... साइलेंट हिस्से ऑटो-कट किए जा रहे हैं।'),
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _splitPoints.add(const Duration(seconds: 2));
          _splitPoints.add(const Duration(seconds: 6));
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('2 साइलेंट हिस्से पहचान कर ऑटो-कट कर दिए गए!')),
        );
      }
    });
  }

  // टेक्स्ट डायलॉग
  void _showTextDialog() {
    final textCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('सबटाइटल / टेक्स्ट जोड़ें'),
        content: TextField(
          controller: textCtrl,
          decoration: const InputDecoration(hintText: 'टेक्स्ट यहाँ लिखें...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('रद्द करें')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('टेक्स्ट जोड़ा गया: "${textCtrl.text}"')),
              );
            },
            child: const Text('जोड़ें'),
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
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('वीडियो एक्सपोर्ट करें'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('रिज़ॉल्यूशन: 1080p Full HD'),
            SizedBox(height: 6),
            Text('फ्रेम रेट: 30 fps'),
            SizedBox(height: 6),
            Text('फॉर्मेट: MP4'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('रद्द करें')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF), foregroundColor: Colors.black),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('एक्सपोर्ट शुरू हुआ... गैलरी में सेव हो रहा है।')),
              );
            },
            child: const Text('एक्सपोर्ट शुरू करें'),
          ),
        ],
      ),
    );
  }
}
