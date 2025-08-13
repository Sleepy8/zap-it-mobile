import 'package:flutter/material.dart';
import '../services/messages_service.dart';
import '../theme.dart';

class E2EESetupScreen extends StatefulWidget {
  const E2EESetupScreen({Key? key}) : super(key: key);

  @override
  State<E2EESetupScreen> createState() => _E2EESetupScreenState();
}

class _E2EESetupScreenState extends State<E2EESetupScreen> {
  final _messagesService = MessagesService();
  bool _isInitializing = false;
  bool _isCompleted = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _initializeE2EE();
  }

  Future<void> _initializeE2EE() async {
    setState(() {
      _isInitializing = true;
      _status = 'Generazione chiavi di crittografia...';
    });

    try {
      final success = await _messagesService.initializeE2EE();
      
      if (success) {
        setState(() {
          _isCompleted = true;
          _status = 'Crittografia end-to-end attivata!';
        });
        
        // Don't auto-close, let user close manually
      } else {
        setState(() {
          _status = 'Errore nell\'attivazione della crittografia';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Errore: $e';
      });
    } finally {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  Future<void> _forceE2EEInitialization() async {
    setState(() {
      _isInitializing = true;
      _status = 'Forzatura attivazione E2EE...';
    });

    try {
      final success = await _messagesService.forceE2EEInitialization();
      
      if (success) {
        setState(() {
          _isCompleted = true;
          _status = 'Crittografia end-to-end forzata e attivata!';
        });
        
        // Don't auto-close, let user close manually
      } else {
        setState(() {
          _status = 'Errore nella forzatura dell\'attivazione E2EE';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Errore: $e';
      });
    } finally {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      appBar: AppBar(
        title: const Text('🔐 Sicurezza Messaggi'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Security icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppTheme.limeAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(60),
                    border: Border.all(
                      color: AppTheme.limeAccent,
                      width: 3,
                    ),
                  ),
                  child: Icon(
                    _isCompleted ? Icons.security : Icons.security_outlined,
                    size: 60,
                    color: AppTheme.limeAccent,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Title
                Text(
                  _isCompleted ? 'Crittografia Attivata!' : 'Configurazione Sicurezza',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                
                // Description
                Text(
                  _isCompleted 
                      ? 'I tuoi messaggi sono ora protetti con crittografia end-to-end. Solo tu e i destinatari potete leggerli.'
                      : 'Stiamo configurando la crittografia end-to-end per proteggere i tuoi messaggi.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                
                // Force E2EE button for existing users
                if (!_isCompleted && !_isInitializing)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ElevatedButton(
                      onPressed: _forceE2EEInitialization,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.limeAccent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '🔐 Forza Attivazione E2EE',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryDark,
                        ),
                      ),
                    ),
                  ),
                
                // Status
                if (_status.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _isCompleted 
                          ? AppTheme.limeAccent.withOpacity(0.1)
                          : AppTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isCompleted 
                            ? AppTheme.limeAccent
                            : AppTheme.limeAccent.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        if (_isInitializing) ...[
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.limeAccent),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ] else if (_isCompleted) ...[
                          const Icon(
                            Icons.check_circle,
                            color: AppTheme.limeAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Text(
                            _status,
                            style: TextStyle(
                              color: _isCompleted 
                                  ? AppTheme.limeAccent
                                  : AppTheme.textPrimary,
                              fontWeight: _isCompleted 
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                
                // Security features list
                if (_isCompleted) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Caratteristiche di Sicurezza:',
                          style: TextStyle(
                            color: AppTheme.limeAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildSecurityFeature(
                          '🔐 Crittografia End-to-End',
                          'I messaggi sono crittografati e solo tu e i destinatari potete leggerli',
                        ),
                        const SizedBox(height: 8),
                        _buildSecurityFeature(
                          '🔑 Chiavi Asimmetriche',
                          'Ogni utente ha una coppia di chiavi unica per la sicurezza',
                        ),
                        const SizedBox(height: 8),
                        _buildSecurityFeature(
                          '🛡️ Protezione Dati',
                          'I messaggi non possono essere letti da terze parti, nemmeno dal server',
                        ),
                        const SizedBox(height: 8),
                        _buildSecurityFeature(
                          '✅ Conformità GDPR',
                          'Sistema conforme alle normative sulla privacy europee',
                        ),
                        const SizedBox(height: 8),
                        _buildSecurityFeature(
                          '⏰ 10 Seconds Chat',
                          'I messaggi si autodistruggono automaticamente dopo 10 secondi per massima privacy',
                        ),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 32),
                
                // Skip button (only if not completed)
                if (!_isCompleted) ...[
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Configura più tardi',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityFeature(String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.check_circle,
          color: AppTheme.limeAccent,
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }


} 