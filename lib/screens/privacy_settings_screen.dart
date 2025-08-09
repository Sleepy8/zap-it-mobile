import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({Key? key}) : super(key: key);

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  bool _showOnlineStatus = true;
  bool _showLastSeen = true;
  bool _allowFriendRequests = true;
  bool _showProfileToEveryone = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPrivacySettings();
  }

  Future<void> _loadPrivacySettings() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _showOnlineStatus = userData['showOnlineStatus'] ?? true;
          _showLastSeen = userData['showLastSeen'] ?? true;
          _allowFriendRequests = userData['allowFriendRequests'] ?? true;
          _showProfileToEveryone = userData['showProfileToEveryone'] ?? true;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading privacy settings: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updatePrivacySetting(String setting, bool value) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      await _firestore.collection('users').doc(userId).update({
        setting: value,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impostazione aggiornata'),
          backgroundColor: AppTheme.limeAccent,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore nell\'aggiornamento'),
          backgroundColor: AppTheme.errorColor,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      appBar: AppBar(
        title: const Text(
          'Privacy',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.limeAccent),
              ),
            )
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Impostazioni Privacy',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 30),
                    
                    // Stato Online
                    _buildPrivacyOption(
                      'Mostra stato online',
                      'Gli altri utenti possono vedere quando sei online',
                      _showOnlineStatus,
                      (value) {
                        setState(() {
                          _showOnlineStatus = value;
                        });
                        _updatePrivacySetting('showOnlineStatus', value);
                      },
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Ultimo accesso
                    _buildPrivacyOption(
                      'Mostra ultimo accesso',
                      'Gli altri utenti possono vedere quando ti sei connesso l\'ultima volta',
                      _showLastSeen,
                      (value) {
                        setState(() {
                          _showLastSeen = value;
                        });
                        _updatePrivacySetting('showLastSeen', value);
                      },
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Richieste amicizia
                    _buildPrivacyOption(
                      'Consenti richieste amicizia',
                      'Gli altri utenti possono inviarti richieste di amicizia',
                      _allowFriendRequests,
                      (value) {
                        setState(() {
                          _allowFriendRequests = value;
                        });
                        _updatePrivacySetting('allowFriendRequests', value);
                      },
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Profilo pubblico
                    _buildPrivacyOption(
                      'Profilo pubblico',
                      'Il tuo profilo è visibile a tutti gli utenti',
                      _showProfileToEveryone,
                      (value) {
                        setState(() {
                          _showProfileToEveryone = value;
                        });
                        _updatePrivacySetting('showProfileToEveryone', value);
                      },
                    ),
                    
                    const SizedBox(height: 40),
                    
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.limeAccent.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: AppTheme.limeAccent,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Informazioni',
                                style: TextStyle(
                                  color: AppTheme.limeAccent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Queste impostazioni controllano come gli altri utenti possono interagire con te e vedere le tue informazioni.',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPrivacyOption(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.limeAccent.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.limeAccent,
            activeTrackColor: AppTheme.limeAccent.withOpacity(0.3),
            inactiveThumbColor: AppTheme.textSecondary,
            inactiveTrackColor: AppTheme.textSecondary.withOpacity(0.3),
          ),
        ],
      ),
    );
  }
}
