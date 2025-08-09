import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:vibration/vibration.dart';
import 'notification_service.dart';

class BackgroundService {
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;
  BackgroundService._internal();

  Timer? _keepAliveTimer;
  bool _isRunning = false;

  // Start background service
  Future<void> start() async {
    if (_isRunning) return;

    try {
      // Initialize notification service with error handling
      try {
        await NotificationService().initialize();
      } catch (e) {
        // Continue without notifications
      }

      // Start keep-alive timer only on Android (iOS handles background differently)
      if (Platform.isAndroid) {
        _startKeepAliveTimer();
      }

      _isRunning = true;
      
    } catch (e) {
      _isRunning = false;
    }
  }

  // Stop background service
  void stop() {
    try {
      _keepAliveTimer?.cancel();
      _isRunning = false;
      
    } catch (e) {
      // Silent error handling
    }
  }

  // Start keep-alive timer to prevent app from being killed (Android only)
  void _startKeepAliveTimer() {
    _keepAliveTimer?.cancel();
    
    _keepAliveTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      try {
        // Send a silent ping to keep the service alive
        _sendKeepAlivePing();
      } catch (e) {
        // Silent error handling
      }
    });
  }

  // Send keep-alive ping
  void _sendKeepAlivePing() {
    // This is a simple ping to keep the background service active
    // In a real app, you might want to send a heartbeat to your server
  }

  // Check if service is running
  bool get isRunning => _isRunning;

  // Dispose resources
  void dispose() {
    stop();
  }
} 
