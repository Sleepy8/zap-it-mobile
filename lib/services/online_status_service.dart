import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:flutter/widgets.dart';

class OnlineStatusService with WidgetsBindingObserver {
  static final OnlineStatusService _instance = OnlineStatusService._internal();
  factory OnlineStatusService() => _instance;
  OnlineStatusService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Timer? _onlineTimer;
  Timer? _lastSeenTimer;
  bool _isInitialized = false;

  // Set user as online
  Future<void> setOnline() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      // Check if user wants to show online status
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final showOnlineStatus = userData['showOnlineStatus'] ?? true;
        
        if (!showOnlineStatus) {
          // User doesn't want to show online status, only update lastSeen
          await _firestore.collection('users').doc(userId).update({
            'lastSeen': FieldValue.serverTimestamp(),
          });
          return;
        }
      }

      await _firestore.collection('users').doc(userId).update({
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
      });

      // Update last seen every 30 seconds while online
      _lastSeenTimer?.cancel();
      _lastSeenTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
        if (_auth.currentUser != null) {
          await _firestore.collection('users').doc(userId).update({
            'lastSeen': FieldValue.serverTimestamp(),
          });
        } else {
          timer.cancel();
        }
      });
    } catch (e) {
      // Silent error handling
    }
  }

  // Set user as offline
  Future<void> setOffline() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      await _firestore.collection('users').doc(userId).update({
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
      });

      _lastSeenTimer?.cancel();
    } catch (e) {
      // Silent error handling
    }
  }

  // Initialize online status tracking
  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;

    // Add observer for app lifecycle
    WidgetsBinding.instance.addObserver(this);

    // Set online when app starts
    setOnline();

    // Set offline when user logs out
    _auth.authStateChanges().listen((user) {
      if (user == null) {
        setOffline();
      } else {
        setOnline();
      }
    });
  }

  // Handle app lifecycle changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        // App is in foreground and visible
        setOnline();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // App is in background or closed
        setOffline();
        break;
      case AppLifecycleState.hidden:
        // App is hidden (new in Flutter 3.7+)
        setOffline();
        break;
    }
  }

  // Get user online status
  Future<bool> getUserOnlineStatus(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final showOnlineStatus = userData['showOnlineStatus'] ?? true;
        
        if (!showOnlineStatus) {
          return false; // User has hidden their online status
        }
        
        return userData['isOnline'] ?? false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Get user last seen
  Future<DateTime?> getUserLastSeen(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final showLastSeen = userData['showLastSeen'] ?? true;
        
        if (!showLastSeen) {
          return null; // User has hidden their last seen
        }
        
        final lastSeen = userData['lastSeen'] as Timestamp?;
        return lastSeen?.toDate();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Dispose timers and observer
  void dispose() {
    _onlineTimer?.cancel();
    _lastSeenTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _isInitialized = false;
  }
}
