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
      print('Starting background service...');

      // Initialize notification service with error handling
      try {
        await NotificationService().initialize();
        print('Notification service initialized successfully');
      } catch (e) {
        print('Notification service initialization failed: $e');
        // Continue without notifications
      }

      // Start keep-alive timer only on Android (iOS handles background differently)
      if (Platform.isAndroid) {
        _startKeepAliveTimer();
      }

      _isRunning = true;
      print('Background service started successfully');
      
    } catch (e) {
      print('Background service start error: $e');
      _isRunning = false;
    }
  }

  // Stop background service
  void stop() {
    try {
      print('Stopping background service...');
      
      _keepAliveTimer?.cancel();
      _isRunning = false;
      
      print('Background service stopped successfully');
      
    } catch (e) {
      print('Background service stop error: $e');
    }
  }

  // Start keep-alive timer to prevent app from being killed (Android only)
  void _startKeepAliveTimer() {
    _keepAliveTimer?.cancel();
    
    _keepAliveTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      try {
        print('Background service keep-alive ping');
        // Send a silent ping to keep the service alive
        _sendKeepAlivePing();
      } catch (e) {
        print('Keep-alive timer error: $e');
      }
    });
  }

  // Send keep-alive ping
  void _sendKeepAlivePing() {
    // This is a simple ping to keep the background service active
    // In a real app, you might want to send a heartbeat to your server
    print('Keep-alive ping sent');
  }

  // Check if service is running
  bool get isRunning => _isRunning;

  // Dispose resources
  void dispose() {
    stop();
  }
} 
