import 'package:flutter/material.dart';
import 'editor_home.dart';

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
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          elevation: 0,
        ),
      ),
      home: const VideoEditorHome(),
    );
  }
}
