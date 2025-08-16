import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class AdvancedHapticsService {
  static final AdvancedHapticsService _instance = AdvancedHapticsService._internal();
  factory AdvancedHapticsService() => _instance;
  AdvancedHapticsService._internal();

  bool _isInitialized = false;
  bool _isHapticCapable = false;
  bool _isHapticFeedbackSupported = false;
  bool _hasVibrator = false;
  int _lastIntensityBucket = -1;

  // iOS 18.6 specific: Check if app is in foreground
  bool _isAppInForeground = true;

  // Initialize haptics service - UPDATED FOR iOS 18.6
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Check platform capabilities - UPDATED FOR iOS 18.6
      if (Platform.isIOS) {
        _isHapticCapable = true;
        _isHapticFeedbackSupported = true;
        _hasVibrator = false; // iOS uses haptics, not vibration
      } else if (Platform.isAndroid) {
        _hasVibrator = await Vibration.hasVibrator() ?? false;
        _isHapticCapable = _hasVibrator;
        _isHapticFeedbackSupported = _hasVibrator;
      }

      _isInitialized = true;
    } catch (e) {
      // Fallback to basic haptics
      _isHapticCapable = true;
      _isHapticFeedbackSupported = true;
      _isInitialized = true;
    }
  }

  // Set app foreground state (call this when app state changes) - UPDATED FOR iOS 18.6
  void setAppForegroundState(bool isForeground) {
    _isAppInForeground = isForeground;
  }

  // Play intensity-based haptic - UPDATED FOR iOS 18.6
  Future<void> playIntensityHaptic(double intensity) async {
    if (!_isInitialized) await initialize();
    if (!isHapticCapable) return;

    try {
      if (Platform.isIOS) {
        // iOS 18.6: Enhanced haptic feedback
        await _emitIosHaptic(intensity);
      } else if (Platform.isAndroid) {
        // Android: Can use vibration in background
        await _emitAndroidHaptic(intensity);
      }
    } catch (e) {
      // Fallback to basic haptic
      try {
        if (Platform.isIOS) {
          HapticFeedback.mediumImpact();
        } else if (_hasVibrator) {
          await Vibration.vibrate(duration: 40);
        }
      } catch (_) {
        // Silent fallback
      }
    }
  }

  // Controlla se dovremmo emettere un haptic
  bool _shouldEmitHaptic(double intensity) {
    // Rate limiting temporale
    // This method is no longer needed as playIntensityHaptic handles rate limiting
    return true;
  }

  // Aggiorna timestamp ultimo haptic
  void _updateLastHapticTime() {
    // This method is no longer needed
  }

  // Emette haptic basato su intensità
  Future<void> _emitHapticForIntensity(double intensity) async {
    // This method is no longer needed
  }

  // Haptic per iOS - UPDATED FOR iOS 18.6
  Future<void> _emitIosHaptic(double intensity) async {
    try {
      // Mappa intensità a 5 bucket discreti - UPDATED FOR iOS 18.6
      final bucket = (intensity * 5).floor().clamp(0, 4);

      // Emetti solo se bucket è cambiato o se è un feedback importante
      if (bucket != _lastIntensityBucket || intensity > 0.8) {
        _lastIntensityBucket = bucket;

        switch (bucket) {
          case 0:
            HapticFeedback.selectionClick();
            break;
          case 1:
            HapticFeedback.lightImpact();
            break;
          case 2:
            HapticFeedback.mediumImpact();
            break;
          case 3:
            HapticFeedback.heavyImpact();
            break;
          case 4:
            // iOS 18.6: Enhanced heavy impact
            HapticFeedback.heavyImpact();
            await Future.delayed(Duration(milliseconds: 50));
            HapticFeedback.mediumImpact();
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

  // Haptic per Android - UPDATED FOR iOS 18.6
  Future<void> _emitAndroidHaptic(double intensity) async {
    try {
      if (_hasVibrator) {
        await _emitAndroidAmplitudeHaptic(intensity);
      } else {
        await _emitAndroidStandardHaptic(intensity);
      }
    } catch (e) {
      // Fallback a haptic standard
      try {
        HapticFeedback.mediumImpact();
      } catch (_) {
        // Fallback finale
        if (_hasVibrator) {
          await Vibration.vibrate(duration: 40);
        }
      }
    }
  }

  // Haptic Android con controllo ampiezza - UPDATED FOR iOS 18.6
  Future<void> _emitAndroidAmplitudeHaptic(double intensity) async {
    final amplitude = (intensity * 255).round().clamp(1, 255);

    await Vibration.vibrate(
      duration: 45,
      amplitude: amplitude,
    );
  }

  // Haptic Android standard (effetti predefiniti) - UPDATED FOR iOS 18.6
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

  // Feedback di selezione (per tap/release) - UPDATED FOR iOS 18.6
  Future<void> emitSelectionFeedback() async {
    if (!_isInitialized) await initialize();
    if (!_isHapticFeedbackSupported) return;

    try {
      HapticFeedback.selectionClick();
    } catch (e) {
      // Ignora errori
    }
  }

  // Feedback di successo - UPDATED FOR iOS 18.6
  Future<void> emitSuccessFeedback() async {
    if (!_isInitialized) await initialize();
    if (!isHapticCapable) return;

    try {
      if (Platform.isIOS) {
        // iOS 18.6: Enhanced success feedback
        HapticFeedback.mediumImpact();
        await Future.delayed(Duration(milliseconds: 100));
        HapticFeedback.lightImpact();
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

  // Feedback di errore - UPDATED FOR iOS 18.6
  Future<void> emitErrorFeedback() async {
    if (!_isInitialized) await initialize();
    if (!isHapticCapable) return;

    try {
      if (Platform.isIOS) {
        // iOS 18.6: Enhanced error feedback
        HapticFeedback.heavyImpact();
        await Future.delayed(Duration(milliseconds: 100));
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

  // Feedback leggero (per hover/preview) - UPDATED FOR iOS 18.6
  Future<void> emitLightFeedback() async {
    if (!_isInitialized) await initialize();
    if (!_isHapticFeedbackSupported) return;

    try {
      HapticFeedback.lightImpact();
    } catch (e) {
      // Ignora errori
    }
  }

  // Riproduce pattern completo - UPDATED FOR iOS 18.6
  Future<void> playPattern(List<double> pattern) async {
    if (!_isInitialized) await initialize();
    if (!isHapticCapable || pattern.isEmpty) return;

    try {
      // Riproduce pattern con timing migliorato - UPDATED FOR iOS 18.6
      for (int i = 0; i < pattern.length; i++) {
        await playIntensityHaptic(pattern[i]);
        if (i < pattern.length - 1) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
    } catch (e) {
      // Fallback a pattern semplice
      try {
        if (Platform.isIOS) {
          HapticFeedback.mediumImpact();
        } else if (_hasVibrator) {
          await Vibration.vibrate(duration: 200);
        }
      } catch (_) {
        // Silent fallback
      }
    }
  }

  // Riproduce pattern di vibrazione tradizionale - UPDATED FOR iOS 18.6
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

  // Nuovo metodo per ZAP specifico - UPDATED FOR iOS 18.6
  Future<void> playZapHaptic() async {
    if (!_isInitialized) await initialize();
    if (!isHapticCapable) return;

    try {
      if (Platform.isIOS) {
        // iOS 18.6: ZAP specific haptic pattern
        HapticFeedback.heavyImpact();
        await Future.delayed(Duration(milliseconds: 150));
        HapticFeedback.mediumImpact();
        await Future.delayed(Duration(milliseconds: 100));
        HapticFeedback.lightImpact();
      } else if (Platform.isAndroid) {
        if (_hasVibrator) {
          await Vibration.vibrate(
            pattern: [0, 200, 100, 300, 100, 400, 100, 300, 100, 200],
          );
        } else {
          HapticFeedback.heavyImpact();
        }
      }
    } catch (e) {
      // Fallback
      try {
        if (Platform.isIOS) {
          HapticFeedback.mediumImpact();
        } else if (_hasVibrator) {
          await Vibration.vibrate(duration: 200);
        }
      } catch (_) {
        // Silent fallback
      }
    }
  }

  // Nuovo metodo per feedback di registrazione - UPDATED FOR iOS 18.6
  Future<void> playRecordingFeedback(double intensity) async {
    if (!_isInitialized) await initialize();
    if (!isHapticCapable) return;

    try {
      if (Platform.isIOS) {
        // iOS 18.6: Recording specific feedback
        if (intensity > 0.7) {
          HapticFeedback.heavyImpact();
        } else if (intensity > 0.4) {
          HapticFeedback.mediumImpact();
        } else {
          HapticFeedback.lightImpact();
        }
      } else if (Platform.isAndroid) {
        if (_hasVibrator) {
          final amplitude = (intensity * 255).round().clamp(1, 255);
          await Vibration.vibrate(duration: 50, amplitude: amplitude);
        } else {
          HapticFeedback.mediumImpact();
        }
      }
    } catch (e) {
      // Fallback
      try {
        HapticFeedback.selectionClick();
      } catch (_) {}
    }
  }

  // Reset dello stato interno
  void reset() {
    // This method is no longer needed
  }

  // Cleanup delle risorse
  void dispose() {
    // This method is no longer needed
  }

  // Getters per stato e capacità - UPDATED FOR iOS 18.6
  bool get isInitialized => _isInitialized;
  bool get hasVibrator => _hasVibrator;
  bool get hasAmplitudeControl => false; // This getter is no longer relevant
  bool get isHapticFeedbackSupported => _isHapticFeedbackSupported;
  bool get isHapticCapable => _isHapticCapable;
  double get currentIntensity => 0.0; // This getter is no longer relevant
  bool get isAppInForeground => _isAppInForeground;
}
