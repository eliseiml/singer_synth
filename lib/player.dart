import 'dart:isolate';
import 'dart:ui';

import 'package:dart_melty_soundfont/dart_melty_soundfont.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:music_notes/music_notes.dart';

// https://github.com/chipweinberger/dart_melty_soundfont/issues/22

class Player {
  static const soundSampleFile = 'assets/sf2/Bosen_Korg_M1.sf2';

  // Synthesizer? _synth;

  Player() {
    // _loadSoundfont().then((_) {
    //   debugPrint('SoundFront loaded');
    // });

    _loadPcmSound().then((_) {
      debugPrint('PCMSound loaded');
    });
  }

  Future<void> play() async {
    await _initFeedingIsolate();
    await FlutterPcmSound.play();

    // _synth!.noteOffAll();
    // _synth!.selectPreset(channel: 0, preset: 0);
  }

  Future<void> pause() async {
    await FlutterPcmSound.stop();
    _txPort!.send('exit');
    _isolate = null;
  }

  // ================== Internal Methods ======================
  // int _fedCount = 0;
  // int _prevNote = 0;

  // void _onFeedClassic(int remainingFrames) async {
  //   final notes = ScalePattern.major
  //       .on(Note.c)
  //       .degrees
  //       .map((note) => note.inOctave(4).semitones)
  //       .toList()
  //     ..removeLast();

  //   int step = (_fedCount ~/ 16) % notes.length;
  //   int curNote = notes[step];
  //   if (curNote != _prevNote) {
  //     _synth!.noteOff(channel: 0, key: _prevNote);
  //     _synth!.noteOn(channel: 0, key: curNote, velocity: 30);
  //   }
  //   ArrayInt16 buf16 = ArrayInt16.zeros(numShorts: 2000);
  //   _synth!.renderMonoInt16(buf16);
  //   await FlutterPcmSound.feed(PcmArrayInt16(bytes: buf16.bytes));
  //   _fedCount++;
  //   _prevNote = curNote;
  // }

  Future<void> _loadPcmSound() async {
    await FlutterPcmSound.setup(sampleRate: 44100, channelCount: 1);
    FlutterPcmSound.setFeedCallback(_requestFeed);
    // FlutterPcmSound.setFeedCallback(_onFeedClassic);
    await FlutterPcmSound.setFeedThreshold(8000);
    await FlutterPcmSound.setLogLevel(LogLevel.standard);
  }

  // Future<void> _loadSoundfont() async {
  //   ByteData bytes = await rootBundle.load(soundSampleFile);
  //   _synth = Synthesizer.loadByteData(bytes, SynthesizerSettings());

  //   // print available instruments
  //   List<Preset> p = _synth!.soundFont.presets;
  //   for (int i = 0; i < p.length; i++) {
  //     String instrumentName =
  //         p[i].regions.isNotEmpty ? p[i].regions[0].instrument.name : "N/A";
  //     debugPrint('[preset $i] name: ${p[i].name} instrument: $instrumentName');
  //   }

  //   return Future<void>.value(null);
  // }

  Isolate? _isolate;
  ReceivePort? _rxPort;
  SendPort? _txPort;

  Future<void> _initFeedingIsolate() async {
    _rxPort = ReceivePort();
    final args = FeedingIsolateArgs(
      RootIsolateToken.instance!,
      _rxPort!.sendPort,
    );

    _isolate = await Isolate.spawn(
      _onFeedBackground,
      args,
    );

    debugPrint('Waiting for isolate\'s rx port');

    _rxPort!.listen(
      (data) async {
        if (data is SendPort) {
          _txPort = data;
          debugPrint('Got isolate\'s rx port');
        } else if (data is String && data == 'requestSynthData') {
          final bytes = await rootBundle.load(soundSampleFile);
          _txPort!.send(bytes);
          _requestFeed(0);
        } else {
          debugPrint('Message type is not handled');
        }
      },
    );
  }

  void _requestFeed(int remainingFrames) {
    _txPort!.send('feed');
  }
}

class FeedingIsolateArgs {
  final RootIsolateToken token;
  final SendPort sendPort;

  const FeedingIsolateArgs(this.token, this.sendPort);
}

class FeedingIsolateMessage {
  final Synthesizer? synth;
  final int prevNote;
  final int fedCount;
  final int? remainingFrames;

  const FeedingIsolateMessage({
    this.synth,
    this.remainingFrames,
    required this.fedCount,
    required this.prevNote,
  });
}

void _onFeedBackground(FeedingIsolateArgs args) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(args.token);

  final txPort = args.sendPort;
  final rxPort = ReceivePort();

  final notes = ScalePattern.major
      .on(Note.c)
      .degrees
      .map((note) => note.inOctave(4).semitones)
      .toList()
    ..removeLast();

  txPort.send(rxPort.sendPort);

  int fedCount = 0;
  int prevNote = 0;

  Synthesizer? synth;

  txPort.send('requestSynthData');

  rxPort.listen(
    (data) async {
      // Init synth
      if (data is ByteData) {
        synth = Synthesizer.loadByteData(data, SynthesizerSettings());

        // print available instruments
        List<Preset> p = synth!.soundFont.presets;
        for (int i = 0; i < p.length; i++) {
          String instrumentName =
              p[i].regions.isNotEmpty ? p[i].regions[0].instrument.name : "N/A";
          debugPrint(
              '[preset $i] name: ${p[i].name} instrument: $instrumentName');
        }
      } else if (data is String && data == 'feed') {
        int step = (fedCount ~/ 16) % notes.length;
        int curNote = notes[step];
        if (curNote != prevNote) {
          synth!.noteOff(channel: 0, key: prevNote);
          synth!.noteOn(channel: 0, key: curNote, velocity: 100);
        }
        ArrayInt16 buf16 = ArrayInt16.zeros(numShorts: 1000);
        synth!.renderMonoInt16(buf16);
        await FlutterPcmSound.feed(PcmArrayInt16(bytes: buf16.bytes));
      } else if (data is String && data == 'exit') {
        Isolate.exit();
      }
    },
    onError: (_) => debugPrint('Feeding isolate rxPort received error'),
  );
}
