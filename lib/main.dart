import 'package:flutter/material.dart';
import 'package:singer_synth/player.dart';

void main() async {
  // WidgetsFlutterBinding.ensureInitialized();
  // initializeService();

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _player = Player();
  bool _isPlaying = false;

  void _togglePlay() {
    setState(() {
      _isPlaying = !_isPlaying;
      _isPlaying ? _player.play() : _player.pause();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: _togglePlay,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_isPlaying ? 'Pause' : 'Play'),
              Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
            ],
          ),
        ),
      ),
    );
  }
}
