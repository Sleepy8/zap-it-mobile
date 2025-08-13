import 'dart:io';
import 'package:flutter/foundation.dart';

class PlatformService {
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get isIOS => !kIsWeb && Platform.isIOS;
  static bool get isWeb => kIsWeb;
  
  // Configurazioni specifiche per piattaforma - FIXED FOR iOS
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
  
  // Verifica se la vibrazione è supportata - FIXED FOR iOS
  static bool get isVibrationSupported {
    if (isAndroid) {
      return true; // Android supporta vibrazione diretta
    } else if (isIOS) {
      return false; // iOS non supporta vibrazione diretta, usa haptic feedback
    }
    return false;
  }
  
  // Verifica se l'haptic feedback è supportato - FIXED FOR iOS
  static bool get isHapticFeedbackSupported {
    if (isIOS) {
      return true; // iOS supporta haptic feedback
    } else if (isAndroid) {
      return true; // Android moderno supporta haptic feedback
    }
    return false;
  }
  
  // Messaggi di errore specifici per piattaforma - FIXED FOR iOS
  static String get vibrationNotSupportedMessage {
    if (isIOS) {
      return 'La vibrazione non è supportata su iOS. Usa l\'haptic feedback.';
    } else if (isAndroid) {
      return 'La vibrazione non è supportata su questo dispositivo Android.';
    }
    return 'La vibrazione non è supportata su questa piattaforma.';
  }
  
  // Configurazioni per notifiche - FIXED FOR iOS
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
      };
    }
    return {};
  }
  
  // Configurazioni specifiche per haptic feedback - FIXED FOR iOS
  static Map<String, dynamic> get hapticFeedbackConfig {
    if (isIOS) {
      return {
        'lightImpact': true,
        'mediumImpact': true,
        'heavyImpact': true,
        'selectionClick': true,
        'defaultIntensity': 'medium',
        'zapIntensity': 'heavy',
        'messageIntensity': 'light',
      };
    } else if (isAndroid) {
      return {
        'lightImpact': true,
        'mediumImpact': true,
        'heavyImpact': true,
        'selectionClick': true,
        'defaultIntensity': 'medium',
        'zapIntensity': 'heavy',
        'messageIntensity': 'light',
      };
    }
    return {};
  }
  
  // Configurazioni per vibrazione - FIXED FOR iOS
  static Map<String, dynamic> get vibrationConfig {
    if (isAndroid) {
      return {
        'hasVibrator': true,
        'hasAmplitudeControl': true,
        'defaultDuration': 200,
        'zapPattern': [0, 200, 100, 300, 100, 400, 100, 300, 100, 200],
        'zapIntensities': [0, 128, 0, 255, 0, 255, 0, 255, 0, 128],
      };
    } else if (isIOS) {
      return {
        'hasVibrator': false,
        'hasAmplitudeControl': false,
        'defaultDuration': 0, // iOS uses haptic feedback
        'zapPattern': [], // iOS uses haptic feedback
        'zapIntensities': [], // iOS uses haptic feedback
        'hapticSequence': ['heavy', 'medium', 'light'], // iOS haptic sequence
      };
    }
    return {};
  }
} 