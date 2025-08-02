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
      

      // Initialize notification service
      await NotificationService().initialize();

      // Start keep-alive timer
      _startKeepAliveTimer();

      _isRunning = true;
      
    } catch (e) {
      
    }
  }

  // Stop background service
  void stop() {
    try {
      
      
      _keepAliveTimer?.cancel();
      _isRunning = false;
      
      
    } catch (e) {
      
    }
  }

  // Start keep-alive timer to prevent app from being killed
  void _startKeepAliveTimer() {
    _keepAliveTimer?.cancel();
    
    _keepAliveTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      
      
      // Send a silent ping to keep the service alive
      _sendKeepAlivePing();
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
