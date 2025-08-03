import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';

Future<void> initializeFirebase() async {
  try {
    // Check if Firebase is already initialized
    if (Firebase.apps.isNotEmpty) {
      return;
    }
    
    // Initialize Firebase with platform-specific options
    if (Platform.isIOS) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyBN8ih0LxKdiXJ4xM5vkUIDrKOO-Uq-jW0",
          appId: "1:927515149799:ios:2428144d2df0d4f233a942",
          messagingSenderId: "927515149799",
          projectId: "zap-it-ac442",
          storageBucket: "zap-it-ac442.firebasestorage.app",
        ),
      );
    } else {
      await Firebase.initializeApp();
    }
    
    print('Firebase initialized successfully');
  } catch (e) {
    print('Firebase initialization failed: $e');
    // Don't rethrow - let the app continue without Firebase
  }
}

Stream<User?> getFirebaseAuthStream() {
  try {
    return FirebaseAuth.instance.authStateChanges();
  } catch (e) {
    print('Firebase Auth stream error: $e');
    // Return empty stream if Firebase Auth fails
    return Stream.value(null);
  }
} 