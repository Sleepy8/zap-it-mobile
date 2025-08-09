import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../services/auth_service.dart';
import '../services/friends_service.dart';
import '../widgets/custom_button.dart';
import '../theme.dart';
import '../services/encryption_service.dart';
import '../widgets/zap_test_widget.dart';
import 'dart:typed_data'; // Added for Uint8List
import 'dart:convert'; // Added for utf8.encode

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthServiceFirebaseImpl();
  final _friendsService = FriendsService();
  final _imagePicker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? _userData;
  Map<String, dynamic> _userStats = {};
  bool _isLoading = true;
  File? _profileImage;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = _authService.getCurrentUser();
      if (user != null) {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final userStats = await _friendsService.getUserStats(user.uid);
          setState(() {
            _userData = userData;
            _userStats = userStats;
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() {
          _profileImage = File(image.path);
          _isUploading = true;
        });
        
        // Upload image to Firebase Storage
        final success = await _uploadProfileImage();
        
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Immagine di profilo salvata con successo!'),
              backgroundColor: AppTheme.limeAccent,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Errore nel salvataggio dell\'immagine. Riprova.'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
        
        setState(() {
          _isUploading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore nella selezione dell\'immagine: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<bool> _uploadProfileImage() async {
    try {
      if (_profileImage == null) return false;
      
      final user = _authService.getCurrentUser();
      if (user == null) {
        
        return false;
      }
      
      
      
      
      
      // Check if image file exists and is readable
      if (!await _profileImage!.exists()) {
        
        return false;
      }
      
      // Read image bytes
      final imageBytes = await _profileImage!.readAsBytes();
      
      
      if (imageBytes.isEmpty) {
        
        return false;
      }
      
      // Create storage reference with unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storageRef = _storage.ref().child('profile_images/${user.uid}_$timestamp.jpg');
      
      
      
      // Upload file with metadata
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploadedBy': user.uid,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );
      
      
      
      // Use putData instead of putFile to avoid file system issues
      final uploadTask = storageRef.putData(imageBytes, metadata);
      
      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        
      });
      
      final snapshot = await uploadTask;
      
      
      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      
      // Update user profile in Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'profileImageUrl': downloadUrl,
        'profileImageUpdatedAt': FieldValue.serverTimestamp(),
      });
      
      
      
      // Update local user data
      if (_userData != null) {
        _userData!['profileImageUrl'] = downloadUrl;
      }
      
      return true;
    } catch (e) {
      
      
      // Show detailed error in console
      if (e is FirebaseException) {
        
        
        
        // Handle specific Firebase Storage errors
        switch (e.code) {
          case 'storage/unauthorized':
            
            
            break;
          case 'storage/quota-exceeded':
            
            break;
          case 'storage/unauthenticated':
            
            break;
          case 'storage/object-not-found':
            
            
            break;
          case 'storage/bucket-not-found':
            
            
            break;
          case 'storage/project-not-found':
            
            break;
          case 'storage/retry-limit-exceeded':
            
            break;
          case 'storage/invalid-checksum':
            
            break;
          case 'storage/canceled':
            
            break;
          default:
            
        }
      } else {
        
        
      }
      
      return false;
    }
  }

  // Test Firebase Storage connection
  Future<bool> _testFirebaseStorage() async {
    try {
      
      
      final user = _authService.getCurrentUser();
      if (user == null) {
        
        return false;
      }
      
      // Try to create a test reference
      final testRef = _storage.ref().child('test/${user.uid}_test.txt');
      
      
      // Try to upload a small test file
      final testData = Uint8List.fromList(utf8.encode('test'));
      final metadata = SettableMetadata(contentType: 'text/plain');
      
      
      final uploadTask = testRef.putData(testData, metadata);
      
      final snapshot = await uploadTask;
      
      
      // Clean up test file
      await testRef.delete();
      
      
      return true;
    } catch (e) {
      
      if (e is FirebaseException) {
        
        
      }
      return false;
    }
  }

  void _showImagePickerDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textSecondary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(
                Icons.camera_alt,
                color: AppTheme.limeAccent,
              ),
              title: Text(
                'Scatta Foto',
                style: TextStyle(color: AppTheme.textPrimary),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: AppTheme.limeAccent,
              ),
              title: Text(
                'Scegli dalla Galleria',
                style: TextStyle(color: AppTheme.textPrimary),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    try {
      await _authService.logout();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore durante il logout: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _testLoginPersistence() async {
    try {
      
      
      // Test SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      final userId = prefs.getString('userId');
      final userEmail = prefs.getString('userEmail');
      
      
      
      
      
      
      // Test Firebase Auth
      final user = _authService.getCurrentUser();
      
      
      // Test force refresh
      final refreshResult = await _authService.forceRefreshSession();
      
      
      // Show results
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Login Test:\n'
              'SharedPrefs: $isLoggedIn\n'
              'Firebase: ${user != null ? 'OK' : 'NULL'}\n'
              'Refresh: $refreshResult',
            ),
            backgroundColor: isLoggedIn && user != null 
                ? AppTheme.limeAccent 
                : AppTheme.errorColor,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } catch (e) {
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test error: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      appBar: AppBar(
        title: const Text('Profilo'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.limeAccent),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Welcome Section
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.limeAccent.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _isUploading ? null : _showImagePickerDialog,
                            child: Stack(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: AppTheme.limeAccent,
                                    borderRadius: BorderRadius.circular(40),
                                  ),
                                  child: _profileImage != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(40),
                                          child: Image.file(
                                            _profileImage!,
                                            width: 80,
                                            height: 80,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : _userData?['profileImageUrl'] != null
                                          ? ClipRRect(
                                              borderRadius: BorderRadius.circular(40),
                                              child: Image.network(
                                                _userData!['profileImageUrl'],
                                                width: 80,
                                                height: 80,
                                                fit: BoxFit.cover,
                                                loadingBuilder: (context, child, loadingProgress) {
                                                  if (loadingProgress == null) return child;
                                                  return Container(
                                                    width: 80,
                                                    height: 80,
                                                    decoration: BoxDecoration(
                                                      color: AppTheme.limeAccent.withOpacity(0.2),
                                                      borderRadius: BorderRadius.circular(40),
                                                    ),
                                                    child: const Icon(
                                                      Icons.person,
                                                      size: 40,
                                                      color: AppTheme.primaryDark,
                                                    ),
                                                  );
                                                },
                                                errorBuilder: (context, error, stackTrace) {
                                                  return const Icon(
                                                    Icons.person,
                                                    size: 40,
                                                    color: AppTheme.primaryDark,
                                                  );
                                                },
                                              ),
                                            )
                                          : const Icon(
                                              Icons.person,
                                              size: 40,
                                              color: AppTheme.primaryDark,
                                            ),
                                ),
                                if (_isUploading)
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(40),
                                      ),
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.limeAccent),
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: AppTheme.limeAccent,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppTheme.primaryDark,
                                          width: 2,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt,
                                        size: 12,
                                        color: AppTheme.primaryDark,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Benvenuto!',
                            style: Theme.of(context).textTheme.displaySmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _userData?['name'] ?? 'Utente',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: AppTheme.limeAccent,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _userData?['email'] ?? '',
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.limeAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppTheme.limeAccent.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              '@${_userData?['username'] ?? 'username'}',
                              style: TextStyle(
                                color: AppTheme.limeAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Stats Section
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Statistiche',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  icon: Icons.flash_on,
                                  title: 'Zap',
                                  value: '${_userStats['zapsSent'] ?? 0}',
                                  color: AppTheme.limeAccent,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildStatCard(
                                  icon: Icons.people,
                                  title: 'Amici',
                                  value: '${_userStats['friendsCount'] ?? 0}',
                                  color: AppTheme.limeAccent,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Settings Section
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.limeAccent.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Impostazioni',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 16),
                          _buildSettingItem(
                            icon: Icons.edit,
                            title: 'Modifica Profilo',
                            onTap: () {
                              Navigator.pushNamed(context, '/edit-profile');
                            },
                          ),
                          _buildSettingItem(
                            icon: Icons.notifications,
                            title: 'Notifiche',
                            onTap: () {
                              Navigator.pushNamed(context, '/notification-settings');
                            },
                          ),
                          _buildSettingItem(
                            icon: Icons.security,
                            title: 'Privacy',
                            onTap: () {
                              Navigator.pushNamed(context, '/privacy-settings');
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // E2EE Status - Always enabled
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.limeAccent.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.security,
                            color: AppTheme.limeAccent,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Crittografia E2EE',
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Sicurezza attiva - Messaggi protetti',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.limeAccent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'ATTIVA',
                              style: TextStyle(
                                color: AppTheme.limeAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // ZAP Test Widget
                    const ZapTestWidget(),
                    
                    const SizedBox(height: 16),
                    
                    // Test Login Persistence
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.limeAccent.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Test Login Persistence',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap to test if login state is saved',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          CustomButton(
                            text: 'Test Login State',
                            onPressed: _testLoginPersistence,
                            isLoading: false,
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Logout button
                    CustomButton(
                      text: 'Logout',
                      onPressed: _signOut,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: AppTheme.limeAccent,
      ),
      title: Text(title),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: AppTheme.textSecondary,
      ),
      onTap: onTap,
    );
  }
} 
