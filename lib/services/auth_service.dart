import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'online_status_service.dart';
import 'dart:async';

abstract class AuthService {
  Future<bool> register(String email, String password, String username, String name);
  Future<bool> login(String email, String password);
  Future<void> logout();
  Future<bool> isLoggedIn();
  User? getCurrentUser();
  Future<bool> forceRefreshSession();
  Stream<User?> authStateChanges();
  void startAccountDeletionListener(BuildContext context);
  void stopAccountDeletionListener();
  Future<bool> checkAccountExists(String userId);
  Future<void> deleteAccount();
  Future<bool> checkUsernameExists(String username);
  Future<bool> checkEmailExists(String email);
}

class AuthServiceFirebaseImpl implements AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<DocumentSnapshot>? _userListener;
  
  AuthServiceFirebaseImpl() {
    // setPersistence() is only supported on web platforms
    // Firebase Auth on mobile automatically persists sessions
  }

  @override
  void startAccountDeletionListener(BuildContext context) {
    final user = _auth.currentUser;
    if (user != null) {
      _userListener = _firestore
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen((snapshot) {
        if (!snapshot.exists) {
          // Account has been deleted, sign out user
          _handleAccountDeletion(context);
        }
      });
    }
  }

  @override
  void stopAccountDeletionListener() {
    _userListener?.cancel();
    _userListener = null;
  }

  @override
  Future<bool> checkAccountExists(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Nessun utente loggato');
      }

      // Set user as offline before deletion
      await OnlineStatusService().setOffline();
      
      // Stop account deletion listener
      stopAccountDeletionListener();
      
      // Delete user document from Firestore first
      await _firestore.collection('users').doc(user.uid).delete();
      
      // Delete the Firebase Auth account directly
      await user.delete();
      
      // Force logout to clear any remaining state
      await _auth.signOut();
      
    } catch (e) {
      // Even if there's an error, try to sign out
      try {
        await _auth.signOut();
      } catch (signOutError) {
        // Ignore sign out errors
      }
      throw Exception('Errore durante l\'eliminazione dell\'account: $e');
    }
  }

  // Handle account deletion
  Future<void> _handleAccountDeletion(BuildContext context) async {
    try {
      // Set user as offline before logout
      await OnlineStatusService().setOffline();
      
      // Sign out the user
      await _auth.signOut();
      
      // Show notification to user
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Il tuo account è stato eliminato. Sei stato sloggato.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
        
        // Navigate to login screen
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
      }
    } catch (e) {
      // Handle error
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore durante il logout: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Future<bool> register(String email, String password, String username, String name) async {
    try {
      // Check if username already exists (case-insensitive)
      final usernameExists = await checkUsernameExists(username);
      if (usernameExists) {
        throw Exception('Username già in uso');
      }

      // Create user with Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) return false;

      // Save user data to Firestore
      await _firestore.collection('users').doc(user.uid).set({
        'email': email,
        'username': username,
        'name': name,
        'created_at': FieldValue.serverTimestamp(),
        'zapsSent': 0,
        'zapsReceived': 0,
        'profileImageUrl': null,
        'lastSeen': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> login(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        // Set user as online
        await OnlineStatusService().setOnline();

        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> logout() async {
    try {
      // Stop account deletion listener
      stopAccountDeletionListener();
      
      // Set user as offline before logout
      await OnlineStatusService().setOffline();
      await _auth.signOut();

    } catch (e) {
      // Handle logout error silently
    }
  }

  @override
  Future<bool> isLoggedIn() async {
    final user = _auth.currentUser;
    if (user != null) {
      // Update last seen
      await _firestore.collection('users').doc(user.uid).update({
        'lastSeen': FieldValue.serverTimestamp(),
      });
      return true;
    }
    return false;
  }

  @override
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  @override
  Future<bool> forceRefreshSession() async {
    try {
      // Wait for Firebase Auth to initialize
      await Future.delayed(Duration(milliseconds: 1500));
      
      final user = _auth.currentUser;
      if (user != null) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  @override
  Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }

  @override
  Future<bool> checkUsernameExists(String username) async {
    try {
      final usernameQuery = await _firestore
          .collection('users')
          .get();

      for (var doc in usernameQuery.docs) {
        final data = doc.data();
        final existingUsername = data['username'] as String?;
        if (existingUsername != null) {
          if (existingUsername.toLowerCase().trim() == username.toLowerCase().trim()) {
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> checkEmailExists(String email) async {
    try {
      final emailQuery = await _firestore
          .collection('users')
          .get();

      for (var doc in emailQuery.docs) {
        final data = doc.data();
        final existingEmail = data['email'] as String?;
        if (existingEmail != null) {
          if (existingEmail.toLowerCase().trim() == email.toLowerCase().trim()) {
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }
} 