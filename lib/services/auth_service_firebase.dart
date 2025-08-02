import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class _FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Register with email and password
  Future<UserCredential?> registerWithEmailAndPassword(
    String name,
    String email,
    String password,
  ) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user document in Firestore
      await _firestore.collection('users').doc(result.user!.uid).set({
        'userId': result.user!.uid,
        'name': name,
        'email': email,
        'created_at': FieldValue.serverTimestamp(),
      });

      return result;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Get user data from Firestore
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      throw 'Errore nel recupero dei dati utente';
    }
  }

  // Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Nessun utente trovato con questa email';
      case 'wrong-password':
        return 'Password errata';
      case 'email-already-in-use':
        return 'Email già registrata';
      case 'weak-password':
        return 'La password deve essere di almeno 6 caratteri';
      case 'invalid-email':
        return 'Email non valida';
      case 'user-disabled':
        return 'Account disabilitato';
      case 'too-many-requests':
        return 'Troppi tentativi. Riprova più tardi';
      default:
        return 'Errore di autenticazione: ${e.message}';
    }
  }
} 