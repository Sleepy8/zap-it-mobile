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
  bool _previousLastSeenState = true; // Salva lo stato precedente dell'ultimo accesso

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
          _previousLastSeenState = userData['showLastSeen'] ?? true; // Inizializza con il valore salvato
          _isLoading = false;
        });
      }
    } catch (e) {
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
                      (value) async {
                        setState(() {
                          _showOnlineStatus = value;
                          if (!value) {
                            // Se disattivi lo stato online, salva lo stato corrente e disattiva l'ultimo accesso
                            _previousLastSeenState = _showLastSeen;
                            _showLastSeen = false;
                          } else {
                            // Se riattivi lo stato online, ripristina lo stato precedente dell'ultimo accesso
                            _showLastSeen = _previousLastSeenState;
                          }
                        });
                        await _updatePrivacySetting('showOnlineStatus', value);
                        // Aggiorna anche l'ultimo accesso
                        if (!value) {
                          await _updatePrivacySetting('showLastSeen', false);
                        } else {
                          await _updatePrivacySetting('showLastSeen', _previousLastSeenState);
                        }
                      },
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Ultimo accesso
                    _buildPrivacyOption(
                      'Mostra ultimo accesso',
                      _showOnlineStatus 
                          ? 'Gli altri utenti possono vedere quando ti sei connesso l\'ultima volta'
                          : 'Disabilitato automaticamente quando lo stato online è disattivato',
                      _showLastSeen,
                      (value) {
                        setState(() {
                          _showLastSeen = value;
                        });
                        _updatePrivacySetting('showLastSeen', value);
                      },
                      enabled: _showOnlineStatus, // Disabilita se lo stato online è off
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
    Function(bool) onChanged, {
    bool enabled = true,
  }) {
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
                    color: enabled ? AppTheme.textPrimary : AppTheme.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: enabled ? AppTheme.textSecondary : AppTheme.textSecondary.withOpacity(0.5),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeColor: enabled ? AppTheme.limeAccent : AppTheme.textSecondary.withOpacity(0.3),
            activeTrackColor: enabled ? AppTheme.limeAccent.withOpacity(0.3) : AppTheme.textSecondary.withOpacity(0.1),
            inactiveThumbColor: AppTheme.textSecondary,
            inactiveTrackColor: AppTheme.textSecondary.withOpacity(0.3),
          ),
        ],
      ),
    );
  }
}
