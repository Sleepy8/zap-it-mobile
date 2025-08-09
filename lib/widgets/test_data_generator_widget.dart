import 'package:flutter/material.dart';
import '../utils/test_data_generator.dart';
import '../theme.dart';

class TestDataGeneratorWidget extends StatefulWidget {
  const TestDataGeneratorWidget({Key? key}) : super(key: key);

  @override
  State<TestDataGeneratorWidget> createState() => _TestDataGeneratorWidgetState();
}

class _TestDataGeneratorWidgetState extends State<TestDataGeneratorWidget> {
  bool _isGenerating = false;
  bool _isCleaning = false;
  String _statusMessage = '';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.science,
                color: AppTheme.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Generatore Dati di Test',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (_statusMessage.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: _statusMessage.contains('✅') || _statusMessage.contains('🎉')
                    ? Colors.green.withOpacity(0.2)
                    : Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _statusMessage,
                style: TextStyle(
                  color: _statusMessage.contains('✅') || _statusMessage.contains('🎉')
                      ? Colors.green
                      : Colors.red,
                  fontSize: 14,
                ),
              ),
            ),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _generateTestData,
                  icon: _isGenerating
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                          ),
                        )
                      : Icon(Icons.add_circle, color: AppTheme.primary),
                  label: Text(
                    _isGenerating ? 'Generando...' : 'Genera 20 Utenti',
                    style: TextStyle(color: AppTheme.primary),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.surfaceDark,
                    foregroundColor: AppTheme.primary,
                    side: BorderSide(color: AppTheme.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _generateQuickTestData,
                  icon: Icon(Icons.flash_on, color: AppTheme.primary),
                  label: Text(
                    'Genera 5 Utenti',
                    style: TextStyle(color: AppTheme.primary),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.surfaceDark,
                    foregroundColor: AppTheme.primary,
                    side: BorderSide(color: AppTheme.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isCleaning ? null : _cleanupTestData,
              icon: _isCleaning
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                      ),
                    )
                  : Icon(Icons.delete_sweep, color: Colors.red),
              label: Text(
                _isCleaning ? 'Pulendo...' : 'Pulisci Tutti gli Utenti di Test',
                style: TextStyle(color: Colors.red),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.surfaceDark,
                foregroundColor: Colors.red,
                side: BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ℹ️ Informazioni:',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '• Genera utenti con nomi italiani per popolare la home\n'
                  '• Password per tutti gli utenti: Test123!\n'
                  '• Gli utenti avranno statistiche casuali di ZAP\n'
                  '• Usa "Pulisci" per rimuovere tutti gli utenti di test',
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateTestData() async {
    setState(() {
      _isGenerating = true;
      _statusMessage = '🚀 Generazione in corso...';
    });

    try {
      await TestDataGenerator.generateTestUsers(count: 20);
      setState(() {
        _statusMessage = '🎉 Generazione completata! Ora puoi accedere con uno degli account generati per vedere la home popolata.';
      });
    } catch (e) {
      setState(() {
        _statusMessage = '❌ Errore durante la generazione: $e';
      });
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  Future<void> _generateQuickTestData() async {
    setState(() {
      _isGenerating = true;
      _statusMessage = '⚡ Generazione rapida in corso...';
    });

    try {
      await TestDataGenerator.generateTestUsers(count: 5);
      setState(() {
        _statusMessage = '⚡ Generazione rapida completata!';
      });
    } catch (e) {
      setState(() {
        _statusMessage = '❌ Errore durante la generazione rapida: $e';
      });
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  Future<void> _cleanupTestData() async {
    setState(() {
      _isCleaning = true;
      _statusMessage = '🧹 Pulizia in corso...';
    });

    try {
      await TestDataGenerator.cleanupTestUsers();
      setState(() {
        _statusMessage = '✅ Pulizia completata! Tutti gli utenti di test sono stati rimossi.';
      });
    } catch (e) {
      setState(() {
        _statusMessage = '❌ Errore durante la pulizia: $e';
      });
    } finally {
      setState(() {
        _isCleaning = false;
      });
    }
  }
}

