import 'package:flutter/material.dart';

void main() {
  runApp(const AutoEditorApp());
}

class AutoEditorApp extends StatelessWidget {
  const AutoEditorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auto Editor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const AutoEditorHomePage(),
    );
  }
}

class AutoEditorHomePage extends StatefulWidget {
  const AutoEditorHomePage({super.key});

  @override
  State<AutoEditorHomePage> createState() => _AutoEditorHomePageState();
}

class _AutoEditorHomePageState extends State<AutoEditorHomePage> {
  bool isProcessing = false;
  String selectedFile = "कोई फ़ाइल चयनित नहीं";
  double silenceThreshold = -30.0;
  double speedMultiplier = 1.5;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Auto Editor'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showAboutDialog(
                context: context,
                applicationName: 'Auto Editor',
                applicationVersion: '1.0.0',
                children: const [
                  Text('मोबाइल और डेस्कटॉप के लिए ऑटो वीडियो/ऑडियो कटर व एडिटर।'),
                ],
              );
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'फ़ाइल चयन',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          selectedFile,
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              selectedFile = "sample_video.mp4 (चयनित)";
                            });
                          },
                          icon: const Icon(Icons.video_file),
                          label: const Text('मीडिया फ़ाइल चुनें'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'एडिटिंग सेटिंग्स',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Text('साइलेंस थ्रेशोल्ड: ${silenceThreshold.toStringAsFixed(1)} dB'),
                        Slider(
                          value: silenceThreshold,
                          min: -50.0,
                          max: -10.0,
                          divisions: 40,
                          label: '${silenceThreshold.toStringAsFixed(1)} dB',
                          onChanged: (val) => setState(() => silenceThreshold = val),
                        ),
                        const SizedBox(height: 12),
                        Text('कट स्पीड: ${speedMultiplier.toStringAsFixed(1)}x'),
                        Slider(
                          value: speedMultiplier,
                          min: 1.0,
                          max: 3.0,
                          divisions: 20,
                          label: '${speedMultiplier.toStringAsFixed(1)}x',
                          onChanged: (val) => setState(() => speedMultiplier = val),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: isProcessing
                      ? null
                      : () async {
                          setState(() => isProcessing = true);
                          await Future.delayed(const Duration(seconds: 2));
                          if (mounted) {
                            setState(() => isProcessing = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('टेस्ट प्रोसेसिंग पूरी हुई!'),
                              ),
                            );
                          }
                        },
                  icon: isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow),
                  label: Text(
                    isProcessing ? 'प्रोसेसिंग जारी है...' : 'ऑटो एडिट शुरू करें',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
