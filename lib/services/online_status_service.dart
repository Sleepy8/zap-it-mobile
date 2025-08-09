import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class OnlineStatusService {
  static final OnlineStatusService _instance = OnlineStatusService._internal();
  factory OnlineStatusService() => _instance;
  OnlineStatusService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Timer? _onlineTimer;
  Timer? _lastSeenTimer;

  // Set user as online
  Future<void> setOnline() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      await _firestore.collection('users').doc(userId).update({
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
      });

      // Update last seen every 15 seconds while online (more frequent for better real-time updates)
      _lastSeenTimer?.cancel();
      _lastSeenTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
        if (_auth.currentUser != null) {
          await _firestore.collection('users').doc(userId).update({
            'lastSeen': FieldValue.serverTimestamp(),
          });
        } else {
          timer.cancel();
        }
      });
    } catch (e) {
      print('❌ Error setting online status: $e');
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
      print('❌ Error setting offline status: $e');
    }
  }

  // Initialize online status tracking
  void initialize() {
    // Set online when app starts
    setOnline();

    // Set offline when app is closed or user logs out
    _auth.authStateChanges().listen((user) {
      if (user == null) {
        setOffline();
      } else {
        setOnline();
      }
    });
  }

  // Dispose timers
  void dispose() {
    _onlineTimer?.cancel();
    _lastSeenTimer?.cancel();
  }
}
