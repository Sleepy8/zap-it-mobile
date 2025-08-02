// Mock implementation for web platform
class _FirebaseAuthService {
  // Mock implementation for web
  dynamic get currentUser => null;
  Stream<dynamic> get authStateChanges => Stream.value(null);
  
  Future<dynamic> signInWithEmailAndPassword(String email, String password) async {
    throw 'Firebase non supportato su web in modalità mock';
  }
  
  Future<dynamic> registerWithEmailAndPassword(String name, String email, String password) async {
    throw 'Firebase non supportato su web in modalità mock';
  }
  
  Future<void> signOut() async {
    // Mock implementation
  }
  
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    return null;
  }
} 