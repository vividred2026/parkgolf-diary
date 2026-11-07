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

  /// 인식기에 알려 주는 골프 용어 (안드로이드 13+ · iOS 에서 인식률이 올라가요).
  static const phrases = [
    '원온',
    '투온',
    '쓰리온',
    '포온',
    '파이브온',
    '원퍼트',
    '투퍼트',
    '쓰리퍼트',
    '포퍼트',
    '원펏',
    '투펏',
    '쓰리펏',
    '쓰리온 투퍼트',
    '투온 투퍼트',
    '쓰리온 원퍼트',
    '포온 투퍼트',
    '쓰리온 투펏',
    '투온 원펏',
    '홀인원',
    '칩인',
    '노퍼트',
    '파',
    '버디',
    '보기',
    '더블보기',
    '이글',
    '그린까지',
    '퍼트',
    '벌타',
    '오비',
    '다음 홀',
    '이전 홀',
    '취소',
  ];

  Future<void> listen({
    required void Function(String words, bool isFinal, List<String> alternates)
    onResult,
    required void Function(double level) onLevel,
    required void Function(String status) onStatus,
    required void Function(String message) onError,
  }) async {
    _onStatus = onStatus;
    _onError = (e) => onError(e.errorMsg);
    await _stt.listen(
      onResult: (SpeechRecognitionResult r) => onResult(
        r.recognizedWords,
        r.finalResult,
        // 인식기가 준 다른 후보들 (첫 후보를 못 알아들으면 차례로 해석해 봐요)
        r.alternates.map((a) => a.recognizedWords).toList(),
      ),
      onSoundLevelChange: onLevel,
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(seconds: 15),
        // 말 사이에 잠깐 쉬어도 끊기지 않게 (쓰리온 … 투퍼트)
        pauseFor: const Duration(seconds: 3),
        localeId: _localeId,
        partialResults: true,
        cancelOnError: true,
        // dictation 이 짧은 숫자 · 골프 용어를 덜 잘라 먹어요
        listenMode: ListenMode.dictation,
        contextualPhrases: phrases,
      ),
    );
  }

  Future<void> stop() => _stt.stop();
  Future<void> cancel() => _stt.cancel();
}
