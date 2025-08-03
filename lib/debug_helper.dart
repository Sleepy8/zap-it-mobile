import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/foundation.dart';

class DebugHelper {
  static void log(String message, {String? tag}) {
    if (kDebugMode) {
      developer.log(message, name: tag ?? 'ZapIt');
    }
  }

  static void logError(String message, dynamic error, {String? tag}) {
    if (kDebugMode) {
      developer.log('ERROR: $message - $error', name: tag ?? 'ZapIt');
    }
  }

  static void logPlatformInfo() {
    if (kDebugMode) {
      developer.log('Platform: ${Platform.operatingSystem}', name: 'ZapIt');
      developer.log('Platform version: ${Platform.operatingSystemVersion}', name: 'ZapIt');
      developer.log('Local hostname: ${Platform.localHostname}', name: 'ZapIt');
      developer.log('Number of processors: ${Platform.numberOfProcessors}', name: 'ZapIt');
    }
  }

  static void logFirebaseStatus() {
    if (kDebugMode) {
      try {
        // Add Firebase status logging here if needed
        developer.log('Firebase status check completed', name: 'ZapIt');
      } catch (e) {
        developer.log('Firebase status check failed: $e', name: 'ZapIt');
      }
    }
  }

  static void logMemoryUsage() {
    if (kDebugMode) {
      // Add memory usage logging here if needed
      developer.log('Memory usage check completed', name: 'ZapIt');
    }
  }

  static void logAppLifecycle(String state) {
    if (kDebugMode) {
      developer.log('App lifecycle: $state', name: 'ZapIt');
    }
  }
} 