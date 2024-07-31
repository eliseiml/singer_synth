import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';

/**
 * 	<key>BGTaskSchedulerPermittedIdentifiers</key>
	<array>
		<string>dev.flutter.background.refresh</string>
	</array>
 */
class Home2 extends StatefulWidget {
  const Home2({super.key});

  @override
  State<Home2> createState() => _Home2State();
}

class _Home2State extends State<Home2> {
  bool _isRunning = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            _isRunning ? stopBackgroundService() : startBackgroundService();
            setState(() {
              _isRunning = !_isRunning;
            });
          },
          child: Text(_isRunning ? 'Stop' : 'Start'),
        ),
      ),
    );
  }
}

void startBackgroundService() {
  final service = FlutterBackgroundService();
  service.startService();
}

void stopBackgroundService() {
  final service = FlutterBackgroundService();
  service.invoke('stop');
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
    androidConfiguration: AndroidConfiguration(
      autoStart: false,
      onStart: onStart,
      isForegroundMode: false,
      autoStartOnBoot: false,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  debugPrint('onIosBackground');

  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // for testing purposes, a C-Major scale
  MajorScale scale = MajorScale(sampleRate: 44100, noteDuration: 0.5);

// invoked whenever we need to feed more samples to the platform
  void onFeed(int remainingFrames) async {
    // you could use 'remainingFrames' to feed very precisely.
    // But here we just load a few thousand samples everytime we run low.
    List<int> frame = scale.generate(periods: 100);
    await FlutterPcmSound.feed(PcmArrayInt16.fromList(frame));
  }

  await FlutterPcmSound.setup(sampleRate: 44100, channelCount: 1);
  await FlutterPcmSound.setFeedThreshold(8000); // feed when below 8000 queued frames
  FlutterPcmSound.setFeedCallback(onFeed);
  await FlutterPcmSound.play();
}
