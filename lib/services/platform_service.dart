import 'dart:io';
import 'package:flutter/foundation.dart';

class PlatformService {
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get isIOS => !kIsWeb && Platform.isIOS;
  static bool get isWeb => kIsWeb;
  
  // Configurazioni specifiche per piattaforma - UPDATED FOR iOS 18.6
  static Map<String, dynamic> get platformConfig {
    if (isAndroid) {
      return {
        'vibrationEnabled': true,
        'hapticFeedbackEnabled': false,
        'notificationSound': false,
        'backgroundProcessing': true,
      };
    } else if (isIOS) {
      return {
        'vibrationEnabled': false, // iOS non supporta vibrazione diretta
        'hapticFeedbackEnabled': true, // iOS usa haptic feedback
        'notificationSound': true,
        'backgroundProcessing': true,
        'hapticFeedbackIntensity': 'medium', // iOS haptic intensity
        'iosVersion': '18.6', // Specifico per iOS 18.6
      };
    } else {
      return {
        'vibrationEnabled': false,
        'hapticFeedbackEnabled': false,
        'notificationSound': true,
        'backgroundProcessing': false,
      };
    }
  }
  
  // Verifica se la vibrazione è supportata - UPDATED FOR iOS 18.6
  static bool get isVibrationSupported {
    if (isAndroid) {
      return true; // Android supporta vibrazione diretta
    } else if (isIOS) {
      return false; // iOS non supporta vibrazione diretta, usa haptic feedback
    }
    return false;
  }
  
  // Verifica se l'haptic feedback è supportato - UPDATED FOR iOS 18.6
  static bool get isHapticFeedbackSupported {
    if (isIOS) {
      return true; // iOS supporta haptic feedback
    } else if (isAndroid) {
      return true; // Android moderno supporta haptic feedback
    }
    return false;
  }
  
  // Messaggi di errore specifici per piattaforma - UPDATED FOR iOS 18.6
  static String get vibrationNotSupportedMessage {
    if (isIOS) {
      return 'La vibrazione non è supportata su iOS. Usa l\'haptic feedback.';
    } else if (isAndroid) {
      return 'La vibrazione non è supportata su questo dispositivo Android.';
    }
    return 'La vibrazione non è supportata su questa piattaforma.';
  }
  
  // Configurazioni per notifiche - UPDATED FOR iOS 18.6
  static Map<String, dynamic> get notificationConfig {
    if (isAndroid) {
      return {
        'channelId': 'zap_vibration',
        'channelName': 'ZAP Vibration',
        'importance': 'high',
        'playSound': false,
        'enableVibration': true,
        'showBadge': false,
        'enableLights': false,
      };
    } else if (isIOS) {
      return {
        'requestAlertPermission': true,
        'requestBadgePermission': true,
        'requestSoundPermission': true,
        'enableVibration': false, // iOS usa haptic feedback
        'playSound': true,
        'hapticFeedbackEnabled': true,
        'backgroundModes': ['remote-notification', 'background-processing', 'background-fetch'],
        'iosVersion': '18.6', // Specifico per iOS 18.6
        'criticalAlerts': false, // iOS 18.6 non richiede critical alerts per ZAP
        'provisionalNotifications': true, // iOS 18.6 supporta notifiche provvisorie
      };
    }
    return {};
  }
  
  // Configurazioni per haptic feedback - UPDATED FOR iOS 18.6
  static Map<String, dynamic> get hapticConfig {
    if (isAndroid) {
      return {
        'amplitudeControl': true,
        'patternSupport': true,
        'intensityLevels': 255,
        'minDuration': 1,
        'maxDuration': 10000,
      };
    } else if (isIOS) {
      return {
        'amplitudeControl': false, // iOS non ha controllo ampiezza diretto
        'patternSupport': true, // iOS supporta pattern tramite haptic feedback
        'intensityLevels': 5, // iOS ha 5 livelli di intensità
        'minDuration': 1,
        'maxDuration': 10000,
        'iosVersion': '18.6',
        'hapticTypes': ['selection', 'light', 'medium', 'heavy'],
        'backgroundHaptics': false, // iOS non supporta haptics in background
      };
    }
    return {};
  }
  
  // Configurazioni per ZAP specifici - UPDATED FOR iOS 18.6
  static Map<String, dynamic> get zapConfig {
    if (isAndroid) {
      return {
        'vibrationPattern': [0, 200, 100, 300, 100, 400, 100, 300, 100, 200],
        'vibrationIntensities': [0, 128, 0, 255, 0, 255, 0, 255, 0, 128],
        'backgroundVibration': true,
        'foregroundVibration': true,
      };
    } else if (isIOS) {
      return {
        'hapticPattern': ['heavy', 'medium', 'light'], // Pattern haptic per iOS
        'backgroundHaptics': false, // iOS non supporta haptics in background
        'foregroundHaptics': true,
        'notificationHaptics': true, // Haptics tramite notifiche
        'iosVersion': '18.6',
        'zapIntensity': 'medium', // Intensità default per ZAP su iOS
      };
    }
    return {};
  }
  
  // Configurazioni per Vibe Composer - UPDATED FOR iOS 18.6
  static Map<String, dynamic> get vibeComposerConfig {
    if (isAndroid) {
      return {
        'recordingEnabled': true,
        'playbackEnabled': true,
        'amplitudeControl': true,
        'patternSupport': true,
        'maxPatternLength': 100,
        'minSegmentDuration': 5,
        'maxSegmentDuration': 6000,
      };
    } else if (isIOS) {
      return {
        'recordingEnabled': true,
        'playbackEnabled': true,
        'amplitudeControl': false, // iOS non ha controllo ampiezza diretto
        'patternSupport': true, // iOS supporta pattern tramite haptic feedback
        'maxPatternLength': 50, // Limite più basso per iOS
        'minSegmentDuration': 10, // Minimo più alto per iOS
        'maxSegmentDuration': 3000, // Massimo più basso per iOS
        'iosVersion': '18.6',
        'hapticFeedbackDuringRecording': true,
        'hapticFeedbackDuringPlayback': true,
        'intensityMapping': {
          'low': 0.2,
          'medium': 0.5,
          'high': 0.8,
          'very_high': 1.0,
        },
      };
    }
    return {};
  }
  
  // Verifica se il dispositivo supporta funzionalità avanzate - UPDATED FOR iOS 18.6
  static Map<String, bool> get deviceCapabilities {
    if (isAndroid) {
      return {
        'vibration': true,
        'hapticFeedback': true,
        'amplitudeControl': true,
        'patternVibration': true,
        'backgroundVibration': true,
        'notificationVibration': true,
      };
    } else if (isIOS) {
      return {
        'vibration': false, // iOS non ha vibrazione diretta
        'hapticFeedback': true,
        'amplitudeControl': false, // iOS non ha controllo ampiezza diretto
        'patternVibration': true, // Tramite haptic feedback
        'backgroundVibration': false, // iOS non supporta vibrazione in background
        'notificationVibration': true, // Tramite notifiche
        'ios18_6': true, // Specifico per iOS 18.6
      };
    }
    return {
      'vibration': false,
      'hapticFeedback': false,
      'amplitudeControl': false,
      'patternVibration': false,
      'backgroundVibration': false,
      'notificationVibration': false,
    };
  }
  
  // Ottieni informazioni sulla versione iOS - UPDATED FOR iOS 18.6
  static String get iosVersion {
    if (isIOS) {
      return '18.6'; // Versione target
    }
    return 'unknown';
  }
  
  // Verifica se è iOS 18.6 o superiore - UPDATED FOR iOS 18.6
  static bool get isIOS18_6OrHigher {
    if (isIOS) {
      return true; // Assumiamo iOS 18.6
    }
    return false;
  }
  
  // Configurazioni per debug - UPDATED FOR iOS 18.6
  static Map<String, dynamic> get debugConfig {
    return {
      'platform': isIOS ? 'iOS' : (isAndroid ? 'Android' : 'Web'),
      'iosVersion': iosVersion,
      'capabilities': deviceCapabilities,
      'notificationConfig': notificationConfig,
      'hapticConfig': hapticConfig,
      'zapConfig': zapConfig,
      'vibeComposerConfig': vibeComposerConfig,
    };
  }
} 