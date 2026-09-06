import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class TtsSttService {
  static final TtsSttService _instance = TtsSttService._internal();
  factory TtsSttService() => _instance;
  TtsSttService._internal();

  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _stt = stt.SpeechToText();

  bool _sttAvailable = false;
  bool _isSpeaking = false;
  bool _isListening = false;

  bool get isSpeaking => _isSpeaking;
  bool get isListening => _isListening;

  // Language code to TTS locale mapping
  static const Map<String, String> _ttsLocaleMap = {
    'en': 'en-US',
    'ta': 'ta-IN',
    'hi': 'hi-IN',
    'te': 'te-IN',
    'kn': 'kn-IN',
    'ml': 'ml-IN',
    'zh': 'zh-CN',
  };

  // Language code to STT locale mapping
  static const Map<String, String> _sttLocaleMap = {
    'en': 'en_US',
    'ta': 'ta_IN',
    'hi': 'hi_IN',
    'te': 'te_IN',
    'kn': 'kn_IN',
    'ml': 'ml_IN',
    'zh': 'zh_CN',
  };

  Future<void> initTts(String langCode) async {
    final locale = _ttsLocaleMap[langCode] ?? 'en-US';
    await _tts.setLanguage(locale);
    await _tts.setSpeechRate(0.48);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    _tts.setStartHandler(() => _isSpeaking = true);
    _tts.setCompletionHandler(() => _isSpeaking = false);
    _tts.setCancelHandler(() => _isSpeaking = false);
  }

  Future<void> speak(String text, {String langCode = 'en'}) async {
    await initTts(langCode);
    if (_isSpeaking) await stopSpeaking();
    // Strip markdown characters for cleaner TTS
    final cleanText = text
        .replaceAll(RegExp(r'\*+'), '')
        .replaceAll(RegExp(r'#{1,6}\s?'), '')
        .replaceAll(RegExp(r'•\s?'), '')
        .replaceAll(RegExp(r'\[.*?\]\(.*?\)'), '');
    await _tts.speak(cleanText);
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
    _isSpeaking = false;
  }

  Future<bool> initStt() async {
    _sttAvailable = await _stt.initialize(
      onError: (error) {
        _isListening = false;
      },
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          _isListening = false;
        }
      },
    );
    return _sttAvailable;
  }

  Future<void> startListening({
    required String langCode,
    required Function(String text) onResult,
    required Function() onDone,
  }) async {
    if (!_sttAvailable) {
      _sttAvailable = await initStt();
    }

    if (_sttAvailable) {
      final locale = _sttLocaleMap[langCode] ?? 'en_US';
      _isListening = true;
      await _stt.listen(
        onResult: (result) {
          if (result.finalResult) {
            onResult(result.recognizedWords);
            _isListening = false;
            onDone();
          }
        },
        listenOptions: stt.SpeechListenOptions(
          partialResults: false,
          cancelOnError: true,
          listenMode: stt.ListenMode.confirmation,
        ),
      );
    }
  }

  Future<void> stopListening() async {
    await _stt.stop();
    _isListening = false;
  }

  Future<void> dispose() async {
    await _tts.stop();
    await _stt.cancel();
  }
}
