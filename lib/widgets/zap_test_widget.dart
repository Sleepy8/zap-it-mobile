import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import '../theme.dart';
import '../services/notification_service.dart';

class ZapTestWidget extends StatefulWidget {
  const ZapTestWidget({Key? key}) : super(key: key);

  @override
  State<ZapTestWidget> createState() => _ZapTestWidgetState();
}

class _ZapTestWidgetState extends State<ZapTestWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  bool _isVibrating = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.1,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _testZapVibration() async {
    if (_isVibrating) return;

    setState(() {
      _isVibrating = true;
    });

    _animationController.forward();

    // Real vibration with console logging
    
    
    
    
    
    
    try {
      final hasVibrator = await Vibration.hasVibrator() ?? false;
      
      
      if (hasVibrator) {
        await Vibration.vibrate(
          pattern: [0, 100, 50, 150, 50, 200, 50, 150, 50, 100],
          intensities: [0, 255, 0, 255, 0, 255, 0, 255, 0, 255],
        );
        
      } else {
        
      }
    } catch (e) {
      
    }
    
    

    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.vibration, color: AppTheme.primaryDark),
            const SizedBox(width: 8),
            const Text(
              'Vibrazione ZAP testata! ⚡',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: AppTheme.limeAccent,
        duration: const Duration(seconds: 2),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 500));

    _animationController.reverse();

    setState(() {
      _isVibrating = false;
    });
  }

  void _testBeautifulNotification() async {
    
    
    try {
      await NotificationService().testNotification();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.notifications_active, color: AppTheme.primaryDark),
              SizedBox(width: 8),
              Text('Notifica ZAP bellissima inviata! ⚡'),
            ],
          ),
          backgroundColor: AppTheme.limeAccent,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  void _clearAllNotifications() async {
    
    await NotificationService().clearAllNotifications();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.clear_all, color: AppTheme.primaryDark),
            SizedBox(width: 8),
            Text('Tutte le notifiche cancellate! 🧹'),
          ],
        ),
        backgroundColor: AppTheme.limeAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
            'Test Sistema ZAP ⚡',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppTheme.limeAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Testa le funzionalità ZAP e le notifiche bellissime',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isVibrating ? null : _testZapVibration,
                  icon: AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Transform.rotate(
                          angle: _rotationAnimation.value,
                          child: const Icon(
                            Icons.vibration,
                            color: AppTheme.primaryDark,
                          ),
                        ),
                      );
                    },
                  ),
                  label: Text(
                    _isVibrating ? 'Vibrando...' : 'Test Vibrazione ZAP',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryDark,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.limeAccent,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _testBeautifulNotification,
                  icon: const Icon(
                    Icons.notifications_active,
                    color: AppTheme.primaryDark,
                  ),
                  label: const Text(
                    'Test Notifica Bellissima',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryDark,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.limeAccent,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _clearAllNotifications,
                  icon: const Icon(
                    Icons.clear_all,
                    color: AppTheme.limeAccent,
                  ),
                  label: const Text(
                    'Cancella Tutte le Notifiche',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.limeAccent,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: AppTheme.limeAccent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryDark.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.limeAccent.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: AppTheme.limeAccent,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Info Sistema ZAP',
                      style: TextStyle(
                        color: AppTheme.limeAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• Vibrazione personalizzata per ZAP\n'
                  '• Notifiche bellissime con animazioni\n'
                  '• Suoni distintivi per ogni tipo\n'
                  '• Gestione intelligente background',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 
