import 'dart:ui';

import 'package:dart_melty_soundfont/dart_melty_soundfont.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:music_notes/music_notes.dart';

// https://github.com/chipweinberger/dart_melty_soundfont/issues/22

class Player {
  static const soundSampleFile = 'assets/sf2/Bosen_Korg_M1.sf2';

  Synthesizer? _synth;

  Player() {
    _loadSoundfont().then((_) {
      debugPrint('SoundFront loaded');
    });

    _loadPcmSound().then((_) {
      debugPrint('PCMSound loaded');
    });
  }

  Future<void> play() async {
    await FlutterPcmSound.play();

    _synth!.noteOffAll();
    _synth!.selectPreset(channel: 0, preset: 0);
  }

  Future<void> pause() async {
    await FlutterPcmSound.pause();
  }

  // ================== Internal Methods ======================
  int _remainingFrames = 0;
  int _fedCount = 0;
  int _prevNote = 0;

  void _onFeed(RootIsolateToken rootIsolateToken) async {
    BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken);
    // _remainingFrames = remainingFrames;

    // c major scale
    final notes = ScalePattern.major.on(Note.c).degrees.map((note) => note.inOctave(4).semitones).toList();

    // List<int> notes = [60, 62, 64, 65, 67, 69, 71, 72];
    int step = (_fedCount ~/ 16) % notes.length;
    int curNote = notes[step];
    if (curNote != _prevNote) {
      _synth!.noteOff(channel: 0, key: _prevNote);
      _synth!.noteOn(channel: 0, key: curNote, velocity: 100);
    }
    ArrayInt16 buf16 = ArrayInt16.zeros(numShorts: 1000);
    _synth!.renderMonoInt16(buf16);
    await FlutterPcmSound.feed(PcmArrayInt16(bytes: buf16.bytes));
    _fedCount++;
    _prevNote = curNote;
  }

  Future<void> _loadPcmSound() async {
    await FlutterPcmSound.setup(sampleRate: 44100, channelCount: 1);
    FlutterPcmSound.setFeedCallback((_) => compute(_onFeed, RootIsolateToken.instance!));
    await FlutterPcmSound.setFeedThreshold(8000);
    await FlutterPcmSound.setLogLevel(LogLevel.standard);
  }

  Future<void> _loadSoundfont() async {
    ByteData bytes = await rootBundle.load(soundSampleFile);
    _synth = Synthesizer.loadByteData(bytes, SynthesizerSettings());

    // print available instruments
    List<Preset> p = _synth!.soundFont.presets;
    for (int i = 0; i < p.length; i++) {
      String instrumentName = p[i].regions.isNotEmpty ? p[i].regions[0].instrument.name : "N/A";
      debugPrint('[preset $i] name: ${p[i].name} instrument: $instrumentName');
    }

    return Future<void>.value(null);
  }
}
