import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> initializeFirebase() async {
  await Firebase.initializeApp();
}

Stream<User?> getFirebaseAuthStream() {
  return FirebaseAuth.instance.authStateChanges();
} 