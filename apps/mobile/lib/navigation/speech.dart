import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

abstract class Speech {
  Future<void> speak(String text);
  Future<void> stop();
}

class TtsSpeech implements Speech {
  final _tts = FlutterTts();
  bool _configured = false;

  @override
  Future<void> speak(String text) async {
    try {
      if (!_configured) {
        _configured = true;
        // Errors (e.g. no voice installed) are reported here instead of
        // surfacing as uncaught exceptions.
        _tts.setErrorHandler((_) {});
        await _tts.setLanguage('en-US');
        await _tts.setSpeechRate(0.5);
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
          // Speak over music (lowering it) and keep talking in the background.
          await _tts
              .setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
                IosTextToSpeechAudioCategoryOptions.duckOthers,
                IosTextToSpeechAudioCategoryOptions
                    .interruptSpokenAudioAndMixWithOthers,
              ]);
        }
      }
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {
      // No TTS engine on this device: navigation continues silently.
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
