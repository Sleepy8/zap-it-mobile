import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'dart:developer' as developer;

Future<void> initializeFirebase() async {
  try {
    developer.log('Starting Firebase initialization...', name: 'Firebase');
    
    // Check if Firebase is already initialized
    if (Firebase.apps.isNotEmpty) {
      developer.log('Firebase already initialized, skipping...', name: 'Firebase');
      return;
    }
    
    // Initialize Firebase with platform-specific options
    if (Platform.isIOS) {
      developer.log('Initializing Firebase for iOS...', name: 'Firebase');
      
      // For iOS, we need to be more careful with initialization
      try {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: "AIzaSyBN8ih0LxKdiXJ4xM5vkUIDrKOO-Uq-jW0",
            appId: "1:927515149799:ios:2428144d2df0d4f233a942",
            messagingSenderId: "927515149799",
            projectId: "zap-it-ac442",
            storageBucket: "zap-it-ac442.firebasestorage.app",
          ),
        );
        developer.log('Firebase initialized successfully for iOS', name: 'Firebase');
      } catch (iosError) {
        developer.log('iOS Firebase initialization failed: $iosError', name: 'Firebase');
        // Try without options as fallback
        try {
          await Firebase.initializeApp();
          developer.log('Firebase initialized with fallback method for iOS', name: 'Firebase');
        } catch (fallbackError) {
          developer.log('Firebase fallback initialization also failed: $fallbackError', name: 'Firebase');
          // Don't rethrow - let the app continue without Firebase
          return;
        }
      }
    } else {
      developer.log('Initializing Firebase for other platforms...', name: 'Firebase');
      await Firebase.initializeApp();
      developer.log('Firebase initialized successfully for other platforms', name: 'Firebase');
    }
    
    // Test Firebase Auth
    try {
      final auth = FirebaseAuth.instance;
      developer.log('Firebase Auth instance created successfully', name: 'Firebase');
    } catch (e) {
      developer.log('Firebase Auth test failed: $e', name: 'Firebase');
    }
    
  } catch (e) {
    developer.log('Firebase initialization failed: $e', name: 'Firebase');
    // Don't rethrow - let the app continue without Firebase
  }
}

Stream<User?> getFirebaseAuthStream() {
  try {
    developer.log('Getting Firebase Auth stream...', name: 'Firebase');
    final stream = FirebaseAuth.instance.authStateChanges();
    developer.log('Firebase Auth stream created successfully', name: 'Firebase');
    return stream;
  } catch (e) {
    developer.log('Firebase Auth stream error: $e', name: 'Firebase');
    // Return empty stream if Firebase Auth fails
    return Stream.value(null);
  }
} 