import 'dart:async';

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// 휴대폰 마이크 음성 인식 (기기 내장 인식기 사용, ko-KR).
class SpeechService {
  SpeechService();
  static SpeechService instance = SpeechService();

  final SpeechToText _stt = SpeechToText();
  bool _ready = false;
  String? _localeId;

  void Function(String status)? _onStatus;
  void Function(SpeechRecognitionError error)? _onError;

  /// 마이크 · 음성 인식 권한을 요청하고 준비해요.
  Future<bool> init() async {
    if (_ready) return true;
    try {
      _ready = await _stt.initialize(
        onStatus: (s) => _onStatus?.call(s),
        onError: (e) => _onError?.call(e),
      );
      if (_ready) {
        final locales = await _stt.locales();
        _localeId =
            locales
                .where((l) => l.localeId.toLowerCase().startsWith('ko'))
                .map((l) => l.localeId)
                .firstOrNull ??
            'ko_KR';
      }
    } catch (_) {
      _ready = false;
    }
    return _ready;
  }

  bool get isListening => _stt.isListening;

  Future<void> listen({
    required void Function(String words, bool isFinal) onResult,
    required void Function(double level) onLevel,
    required void Function(String status) onStatus,
    required void Function(String message) onError,
  }) async {
    _onStatus = onStatus;
    _onError = (e) => onError(e.errorMsg);
    await _stt.listen(
      onResult: (SpeechRecognitionResult r) =>
          onResult(r.recognizedWords, r.finalResult),
      onSoundLevelChange: onLevel,
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(seconds: 12),
        pauseFor: const Duration(seconds: 2),
        localeId: _localeId,
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
        contextualPhrases: const ['그린까지', '퍼트', '벌타', '다음 홀', '이전 홀'],
      ),
    );
  }

  Future<void> stop() => _stt.stop();
  Future<void> cancel() => _stt.cancel();
}
