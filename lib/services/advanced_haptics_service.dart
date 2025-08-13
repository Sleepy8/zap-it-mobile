import 'dart:io';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import 'dart:async';

class AdvancedHapticsService {
  static final AdvancedHapticsService _instance = AdvancedHapticsService._internal();
  factory AdvancedHapticsService() => _instance;
  AdvancedHapticsService._internal();

  // Capacità del dispositivo
  bool _isInitialized = false;
  bool _hasVibrator = false;
  bool _hasAmplitudeControl = false;
  bool _isHapticFeedbackSupported = false;

  // Rate limiting per performance
  DateTime? _lastHapticTime;
  static const int _minHapticInterval = 40; // 25 haptics/secondo max
  static const double _intensityThreshold = 0.06; // Soglia per cambiamenti significativi

  // Stato corrente
  double _lastIntensity = 0.0;
  int _lastIntensityBucket = -1;

  // Timer per debounce
  Timer? _debounceTimer;

  // Inizializzazione del servizio
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Controlla capacità vibrazione
      _hasVibrator = await Vibration.hasVibrator() ?? false;
      _hasAmplitudeControl = await Vibration.hasAmplitudeControl() ?? false;

      _isHapticFeedbackSupported = true;

      _isInitialized = true;
    } catch (e) {
      // Fallback sicuro
      _hasVibrator = false;
      _hasAmplitudeControl = false;
      _isHapticFeedbackSupported = false;
      _isInitialized = true;
    }
  }



  // Metodo principale per haptic basato su intensità
  Future<void> playIntensityHaptic(double intensity) async {
    if (!_isInitialized) await initialize();
    if (!_isHapticCapable) return;

    intensity = intensity.clamp(0.0, 1.0);

    // Rate limiting
    if (!_shouldEmitHaptic(intensity)) return;

    _updateLastHapticTime();
    _lastIntensity = intensity;

    // Debounce per evitare spam
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 35), () async {
      await _emitHapticForIntensity(intensity);
    });
  }

  // Controlla se dovremmo emettere un haptic
  bool _shouldEmitHaptic(double intensity) {
    // Rate limiting temporale
    if (_lastHapticTime != null) {
      final timeSince = DateTime.now().difference(_lastHapticTime!).inMilliseconds;
      if (timeSince < _minHapticInterval) return false;
    }

    // Soglia di cambiamento intensità
    if ((intensity - _lastIntensity).abs() < _intensityThreshold) return false;

    return true;
  }

  // Aggiorna timestamp ultimo haptic
  void _updateLastHapticTime() {
    _lastHapticTime = DateTime.now();
  }

  // Emette haptic basato su intensità
  Future<void> _emitHapticForIntensity(double intensity) async {
    if (Platform.isIOS) {
      await _emitIosHaptic(intensity);
    } else if (Platform.isAndroid) {
      await _emitAndroidHaptic(intensity);
    }
  }

  // Haptic per iOS (discretizzato in bucket)
  Future<void> _emitIosHaptic(double intensity) async {
    try {
      // Mappa intensità a 5 bucket discreti
      final bucket = (intensity * 5).floor().clamp(0, 4);

      // Emetti solo se bucket è cambiato
      if (bucket != _lastIntensityBucket) {
        _lastIntensityBucket = bucket;

        switch (bucket) {
          case 0:
            HapticFeedback.selectionClick();
            break;
          case 1:
            HapticFeedback.lightImpact();
            break;
          case 2:
          case 3:
            HapticFeedback.mediumImpact();
            break;
          case 4:
            HapticFeedback.heavyImpact();
            break;
        }
      }
    } catch (e) {
      // Fallback silenzioso
      try {
        HapticFeedback.selectionClick();
      } catch (_) {}
    }
  }

  // Haptic per Android
  Future<void> _emitAndroidHaptic(double intensity) async {
    try {
      if (_hasAmplitudeControl) {
        await _emitAndroidAmplitudeHaptic(intensity);
      } else {
        await _emitAndroidStandardHaptic(intensity);
      }
    } catch (e) {
      // Fallback a haptic standard
      try {
        await HapticFeedback.mediumImpact();
      } catch (_) {
        // Fallback finale
        if (_hasVibrator) {
          await Vibration.vibrate(duration: 40);
        }
      }
    }
  }

  // Haptic Android con controllo ampiezza
  Future<void> _emitAndroidAmplitudeHaptic(double intensity) async {
    final amplitude = (intensity * 255).round().clamp(1, 255);

    await Vibration.vibrate(
      duration: 45,
      amplitude: amplitude,
    );
  }

  // Haptic Android standard (effetti predefiniti)
  Future<void> _emitAndroidStandardHaptic(double intensity) async {
    if (intensity >= 0.8) {
      HapticFeedback.heavyImpact();
    } else if (intensity >= 0.5) {
      HapticFeedback.mediumImpact();
    } else if (intensity >= 0.2) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.selectionClick();
    }
  }

  // Feedback di selezione (per tap/release)
  Future<void> emitSelectionFeedback() async {
    if (!_isInitialized) await initialize();
    if (!_isHapticFeedbackSupported) return;

    try {
      HapticFeedback.selectionClick();
    } catch (e) {
      // Ignora errori
    }
  }

  // Feedback di successo
  Future<void> emitSuccessFeedback() async {
    if (!_isInitialized) await initialize();
    if (!_isHapticCapable) return;

    try {
      if (Platform.isIOS) {
        HapticFeedback.mediumImpact();
      } else {
        if (_hasVibrator) {
          await Vibration.vibrate(pattern: [0, 100, 50, 100]);
        } else {
          HapticFeedback.lightImpact();
        }
      }
    } catch (e) {
      // Ignora errori
    }
  }

  // Feedback di errore
  Future<void> emitErrorFeedback() async {
    if (!_isInitialized) await initialize();
    if (!_isHapticCapable) return;

    try {
      if (Platform.isIOS) {
        HapticFeedback.heavyImpact();
      } else {
        if (_hasVibrator) {
          await Vibration.vibrate(pattern: [0, 200, 100, 200]);
        } else {
          HapticFeedback.heavyImpact();
        }
      }
    } catch (e) {
      // Ignora errori
    }
  }

  // Feedback leggero (per hover/preview)
  Future<void> emitLightFeedback() async {
    if (!_isInitialized) await initialize();
    if (!_isHapticFeedbackSupported) return;

    try {
      HapticFeedback.lightImpact();
    } catch (e) {
      // Ignora errori
    }
  }

  // Riproduce pattern completo
  Future<void> playPattern(List<double> pattern) async {
    if (!_isInitialized) await initialize();
    if (!_isHapticCapable || pattern.isEmpty) return;

    // Riproduce pattern con timing
    for (int i = 0; i < pattern.length; i++) {
      await playIntensityHaptic(pattern[i]);
      Future.delayed(const Duration(milliseconds: 100));
    }
  }

  // Riproduce pattern di vibrazione tradizionale
  Future<void> playVibrationPattern(List<int> pattern) async {
    if (!_isInitialized) await initialize();
    if (!_hasVibrator || pattern.isEmpty) return;

    try {
      await Vibration.vibrate(pattern: pattern);
    } catch (e) {
      // Fallback a vibrazione singola
      await Vibration.vibrate(duration: 200);
    }
  }

  // Reset dello stato interno
  void reset() {
    _lastIntensity = 0.0;
    _lastIntensityBucket = -1;
    _lastHapticTime = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  // Cleanup delle risorse
  void dispose() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  // Getters per stato e capacità
  bool get isInitialized => _isInitialized;
  bool get hasVibrator => _hasVibrator;
  bool get hasAmplitudeControl => _hasAmplitudeControl;
  bool get isHapticFeedbackSupported => _isHapticFeedbackSupported;
  bool get _isHapticCapable => _isHapticFeedbackSupported || _hasVibrator;
  double get currentIntensity => _lastIntensity;
}
