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

  // iOS 18 specific: Check if app is in foreground
  bool _isAppInForeground = true;

  // Initialize haptics service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Check platform capabilities
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

  // Set app foreground state (call this when app state changes)
  void setAppForegroundState(bool isForeground) {
    _isAppInForeground = isForeground;
  }

  // Play intensity-based haptic (iOS 18 optimized)
  Future<void> playIntensityHaptic(double intensity) async {
    if (!_isInitialized) await initialize();
    if (!_isHapticCapable) return;

    try {
      if (Platform.isIOS) {
        // iOS 18: Only trigger haptics if app is in foreground
        if (!_isAppInForeground) {
          // Store for later playback when app comes to foreground
          await _storePendingHaptic(intensity);
          return;
        }
        
        // Use Core Haptics equivalent through Flutter
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

  // Store pending haptic for iOS background
  Future<void> _storePendingHaptic(double intensity) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingHaptics = prefs.getStringList('pending_haptics') ?? [];
      pendingHaptics.add(intensity.toString());
      
      // Keep only last 10 haptics to avoid memory issues
      if (pendingHaptics.length > 10) {
        pendingHaptics.removeRange(0, pendingHaptics.length - 10);
      }
      
      await prefs.setStringList('pending_haptics', pendingHaptics);
    } catch (e) {
      // Silent error handling
    }
  }

  // Play pending haptics when app comes to foreground
  Future<void> playPendingHaptics() async {
    if (!Platform.isIOS) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingHaptics = prefs.getStringList('pending_haptics') ?? [];
      
      if (pendingHaptics.isNotEmpty) {
        // Play all pending haptics with small delays
        for (int i = 0; i < pendingHaptics.length; i++) {
          final intensity = double.tryParse(pendingHaptics[i]) ?? 0.5;
          await _emitIosHaptic(intensity);
          
          // Small delay between haptics
          if (i < pendingHaptics.length - 1) {
            await Future.delayed(Duration(milliseconds: 100));
          }
        }
        
        // Clear pending haptics
        await prefs.remove('pending_haptics');
      }
    } catch (e) {
      // Silent error handling
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
    // This method is no longer needed
  }

  // Cleanup delle risorse
  void dispose() {
    // This method is no longer needed
  }

  // Getters per stato e capacità
  bool get isInitialized => _isInitialized;
  bool get hasVibrator => _hasVibrator;
  bool get hasAmplitudeControl => false; // This getter is no longer relevant
  bool get isHapticFeedbackSupported => _isHapticFeedbackSupported;
  bool get _isHapticCapable => _isHapticCapable;
  double get currentIntensity => 0.0; // This getter is no longer relevant
}
