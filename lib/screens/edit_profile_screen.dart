import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _emailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  
  DateTime? _birthDate;
  String? _gender;
  String? _location;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _usernameController.text = userData['username'] ?? '';
          _nameController.text = userData['name'] ?? '';
          _bioController.text = userData['bio'] ?? '';
          _emailController.text = userData['email'] ?? '';
          _birthDate = userData['birthDate']?.toDate();
          _gender = userData['gender'];
          _location = userData['location'];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final updateData = <String, dynamic>{
        'username': _usernameController.text.trim(),
        'name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
        'gender': _gender,
        'location': _location,
      };

      if (_birthDate != null) {
        updateData['birthDate'] = Timestamp.fromDate(_birthDate!);
      }

      await _firestore.collection('users').doc(userId).update(updateData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profilo aggiornato con successo'),
          backgroundColor: AppTheme.limeAccent,
          duration: const Duration(seconds: 2),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore nell\'aggiornamento: $e'),
          backgroundColor: AppTheme.errorColor,
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _changePassword() async {
    if (_currentPasswordController.text.isEmpty || _newPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Inserisci la password attuale e la nuova password'),
          backgroundColor: AppTheme.errorColor,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Re-authenticate user
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPasswordController.text,
      );
      await user.reauthenticateWithCredential(credential);

      // Change password
      await user.updatePassword(_newPasswordController.text);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password aggiornata con successo'),
          backgroundColor: AppTheme.limeAccent,
          duration: const Duration(seconds: 2),
        ),
      );

      _currentPasswordController.clear();
      _newPasswordController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore nel cambio password: $e'),
          backgroundColor: AppTheme.errorColor,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _selectBirthDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime.now().subtract(const Duration(days: 6570)), // 18 anni fa
      firstDate: DateTime.now().subtract(const Duration(days: 36500)), // 100 anni fa
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.limeAccent,
              onPrimary: AppTheme.primaryDark,
              surface: AppTheme.surfaceDark,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _birthDate) {
      setState(() {
        _birthDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      appBar: AppBar(
        title: const Text(
          'Modifica Profilo',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _isSaving ? null : _saveProfile,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.limeAccent),
                      ),
                    )
                  : Text(
                      'Salva',
                      style: TextStyle(
                        color: AppTheme.limeAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.limeAccent),
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Informazioni di base
                      _buildSectionTitle('Informazioni di Base'),
                      const SizedBox(height: 16),
                      
                      _buildTextField(
                        controller: _usernameController,
                        label: 'Username',
                        icon: Icons.person,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Username richiesto';
                          }
                          if (value.length < 3) {
                            return 'Username deve essere di almeno 3 caratteri';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      _buildTextField(
                        controller: _nameController,
                        label: 'Nome completo',
                        icon: Icons.badge,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Nome richiesto';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      _buildTextField(
                        controller: _bioController,
                        label: 'Bio',
                        icon: Icons.description,
                        maxLines: 3,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      _buildTextField(
                        controller: _emailController,
                        label: 'Email',
                        icon: Icons.email,
                        enabled: false, // Email non modificabile
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Informazioni personali
                      _buildSectionTitle('Informazioni Personali'),
                      const SizedBox(height: 16),
                      
                      // Data di nascita
                      GestureDetector(
                        onTap: _selectBirthDate,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceDark,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.limeAccent.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.cake,
                                color: AppTheme.limeAccent,
                                size: 24,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Data di nascita',
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _birthDate != null
                                          ? '${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}'
                                          : 'Seleziona data',
                                      style: TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                color: AppTheme.textSecondary,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Genere
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.limeAccent.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              color: AppTheme.limeAccent,
                              size: 24,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Genere',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  DropdownButton<String>(
                                    value: _gender,
                                    hint: Text(
                                      'Seleziona genere',
                                      style: TextStyle(color: AppTheme.textPrimary),
                                    ),
                                    dropdownColor: AppTheme.surfaceDark,
                                    style: TextStyle(color: AppTheme.textPrimary),
                                    underline: Container(),
                                    items: [
                                      DropdownMenuItem(
                                        value: 'male',
                                        child: Text('Uomo'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'female',
                                        child: Text('Donna'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'other',
                                        child: Text('Altro'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'prefer_not_to_say',
                                        child: Text('Preferisco non specificare'),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      setState(() {
                                        _gender = value;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      _buildTextField(
                        controller: TextEditingController(text: _location ?? ''),
                        label: 'Località',
                        icon: Icons.location_on,
                        onChanged: (value) {
                          _location = value;
                        },
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Cambio password
                      _buildSectionTitle('Sicurezza'),
                      const SizedBox(height: 16),
                      
                      _buildTextField(
                        controller: _currentPasswordController,
                        label: 'Password attuale',
                        icon: Icons.lock,
                        isPassword: true,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      _buildTextField(
                        controller: _newPasswordController,
                        label: 'Nuova password',
                        icon: Icons.lock_outline,
                        isPassword: true,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _changePassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.limeAccent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Cambia Password',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: AppTheme.primaryDark,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: AppTheme.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool enabled = true,
    int maxLines = 1,
    Function(String)? onChanged,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.limeAccent.withOpacity(0.3),
        ),
      ),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        obscureText: isPassword,
        maxLines: maxLines,
        onChanged: onChanged,
        validator: validator,
        style: TextStyle(color: AppTheme.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: AppTheme.textSecondary),
          prefixIcon: Icon(icon, color: AppTheme.limeAccent),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _nameController.dispose();
    _bioController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }
}
