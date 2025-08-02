import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import 'dart:math' as Math;
import '../theme.dart';
import '../services/vibration_pattern_service.dart';
import '../services/platform_service.dart';

class VibeComposerScreen extends StatefulWidget {
  const VibeComposerScreen({Key? key}) : super(key: key);

  @override
  State<VibeComposerScreen> createState() => _VibeComposerScreenState();
}

class _VibeComposerScreenState extends State<VibeComposerScreen>
    with TickerProviderStateMixin {
  final VibrationPatternService _patternService = VibrationPatternService();
  List<int> _currentPattern = [];
  List<int> _currentIntensities = []; // Nuovo: lista delle intensità
  bool _isRecording = false;
  bool _isPlaying = false;
  late AnimationController _animationController;
  late Animation<double> _animation;
  List<VibrationPattern> _savedPatterns = [];
  VibrationPattern? _selectedPattern;
  DateTime? _recordingStartTime;
  DateTime? _vibrationStartTime;
  bool _isVibrating = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadSavedPatterns();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedPatterns() async {
    final patterns = await _patternService.getAllPatterns();
    setState(() {
      _savedPatterns = patterns;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 700; // Schermi piccoli come Redmi Go
    
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isSmallScreen),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isSmallScreen ? 8 : 16),
                child: Column(
                  children: [
                    _buildVisualizer(isSmallScreen),
                    SizedBox(height: isSmallScreen ? 16 : 24),
                    _buildControls(isSmallScreen),
                    SizedBox(height: isSmallScreen ? 16 : 32),
                    _buildPatternLibrary(isSmallScreen),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.surfaceDark,
            AppTheme.surfaceDark.withOpacity(0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.vibration_rounded,
            color: AppTheme.limeAccent,
            size: isSmallScreen ? 24 : 28,
          ),
          SizedBox(width: isSmallScreen ? 8 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vibe Composer',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 20 : 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  'Crea vibrazioni personalizzate',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisualizer(bool isSmallScreen) {
    final visualizerHeight = isSmallScreen ? 160.0 : 220.0; // Aumentato significativamente
    
    return Container(
      height: visualizerHeight,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.surfaceDark.withOpacity(0.3),
            AppTheme.surfaceDark.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.limeAccent.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return CustomPaint(
                painter: WavePainter(
                  pattern: _currentPattern,
                  intensities: _currentIntensities,
                  animation: _animation,
                  isPlaying: _isPlaying,
                  isSmallScreen: isSmallScreen,
                ),
                size: Size.infinite,
              );
            },
          ),
          // Area interattiva per la registrazione
          if (_isRecording)
            Positioned.fill(
              child: GestureDetector(
                onTapDown: _onVisualizerTapDown,
                onTapUp: _onVisualizerTapUp,
                onPanStart: _onVisualizerPanStart,
                onPanUpdate: _onVisualizerPanUpdate,
                onPanEnd: _onVisualizerPanEnd,
                behavior: HitTestBehavior.opaque, // Importante: previene lo scroll
                child: Container(
                  color: Colors.transparent,
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 12 : 16, 
                        vertical: isSmallScreen ? 6 : 8
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceDark.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.limeAccent.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '🎙️ Tocca qui per registrare!\nTrascina per cambiare intensità',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: isSmallScreen ? 10 : 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            Center(
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 12 : 16, 
                  vertical: isSmallScreen ? 6 : 8
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.limeAccent.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: Text(
                  _currentPattern.isEmpty 
                    ? 'Crea il tuo pattern di vibrazione'
                    : '${_currentPattern.length} impulsi creati',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: isSmallScreen ? 12 : 14,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControls(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        // RIMOSSO IL BORDO
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildSmallControlButton(
            icon: _isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
            label: _isPlaying ? 'Stop' : 'Play',
            onPressed: _isPlaying ? _stopPlaying : _playPattern,
            color: _isPlaying ? Colors.red : Colors.green,
            isSmallScreen: isSmallScreen,
          ),
          _buildSmallControlButton(
            icon: Icons.fiber_manual_record_rounded,
            label: 'Record',
            onPressed: _toggleRecording,
            color: _isRecording ? Colors.red : Colors.orange,
            isSmallScreen: isSmallScreen,
          ),
          _buildSmallControlButton(
            icon: Icons.add_rounded,
            label: 'Create',
            onPressed: _createManualPattern,
            color: Colors.blue,
            isSmallScreen: isSmallScreen,
          ),
          _buildSmallControlButton(
            icon: Icons.save_rounded,
            label: 'Save',
            onPressed: _saveCurrentPattern,
            color: Colors.purple,
            isSmallScreen: isSmallScreen,
          ),
        ],
      ),
    );
  }

  Widget _buildSmallControlButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required Color color,
    required bool isSmallScreen,
  }) {
    final buttonSize = isSmallScreen ? 60.0 : 70.0;
    final iconSize = isSmallScreen ? 18.0 : 20.0;
    final fontSize = isSmallScreen ? 9.0 : 10.0;
    
    return Container(
      width: buttonSize,
      height: buttonSize,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 3,
          // RIMOSSO IL BORDO
          side: BorderSide.none,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: iconSize),
            SizedBox(height: isSmallScreen ? 1 : 2),
            Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Metodi per il controllo interattivo del visualizzatore
  void _onVisualizerTapDown(TapDownDetails details) {
    if (!_isRecording) return;
    
    final renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    
    _startInteractiveRecording(localPosition);
  }

  void _onVisualizerTapUp(TapUpDetails details) {
    if (!_isRecording) return;
    
    final renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    
    _stopInteractiveRecording(localPosition);
  }

  void _onVisualizerPanStart(DragStartDetails details) {
    if (!_isRecording) return;
    
    final renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    
    _startInteractiveRecording(localPosition);
  }

  void _onVisualizerPanUpdate(DragUpdateDetails details) {
    if (!_isRecording || _vibrationStartTime == null) return;
    
    final renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    
    // Aggiorna l'intensità in tempo reale durante il trascinamento
    _updateVibrationIntensity(localPosition);
  }

  void _onVisualizerPanEnd(DragEndDetails details) {
    if (!_isRecording) return;
    
    _stopInteractiveRecording(null);
  }

  void _startRecording() {
    setState(() {
      _currentPattern.clear();
      _currentIntensities.clear(); // Pulisci anche le intensità
      _recordingStartTime = DateTime.now();
    });
    
    // Rimossa la notifica per rendere l'app più fluida
  }

  void _stopRecording() {
    // Rimossa la notifica per rendere l'app più fluida
  }

  void _startInteractiveRecording(Offset position) {
    setState(() {
      _isVibrating = true;
      _vibrationStartTime = DateTime.now();
    });
    
    // Calcola l'intensità basata sulla posizione Y
    final intensity = _calculateIntensityFromPosition(position);
    
    // Gestione specifica per piattaforma
    if (PlatformService.isAndroid) {
      // Android: vibrazione diretta
      Vibration.vibrate(duration: 200, amplitude: intensity);
    } else if (PlatformService.isIOS) {
      // iOS: haptic feedback
      _triggerHapticFeedback(intensity);
    }
    
    
  }

  void _updateVibrationIntensity(Offset position) {
    final intensity = _calculateIntensityFromPosition(position);
    
    // Gestione specifica per piattaforma
    if (PlatformService.isAndroid) {
      // Android: aggiorna vibrazione in tempo reale
      Vibration.vibrate(duration: 50, amplitude: intensity);
    } else if (PlatformService.isIOS) {
      // iOS: aggiorna haptic feedback
      _triggerHapticFeedback(intensity);
    }
    
    
  }

  void _triggerHapticFeedback(int intensity) {
    if (PlatformService.isIOS) {
      // Converti intensità in tipo di haptic feedback
      if (intensity > 200) {
        HapticFeedback.heavyImpact();
      } else if (intensity > 100) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.lightImpact();
      }
    }
  }

  void _stopInteractiveRecording(Offset? position) {
    setState(() {
      _isVibrating = false;
    });
    
    // Calcola la durata e l'intensità
    if (_vibrationStartTime != null) {
      final duration = DateTime.now().difference(_vibrationStartTime!).inMilliseconds;
      final intensity = position != null ? _calculateIntensityFromPosition(position) : 128;
      
      // Crea l'impulso con intensità personalizzata
      final impulseDuration = duration.clamp(50, 1000);
      final impulseIntensity = intensity;
      
      setState(() {
        _currentPattern.add(impulseDuration);
        _currentIntensities.add(impulseIntensity); // Salva l'intensità
        
      });
      
      // Rimossa la notifica per rendere l'app più fluida
    }
    
    _vibrationStartTime = null;
  }

  int _calculateIntensityFromPosition(Offset position) {
    // Ottieni l'altezza del visualizzatore in base alla dimensione dello schermo
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;
    final visualizerHeight = isSmallScreen ? 160.0 : 220.0; // Aggiornato per la nuova altezza
    
    // Normalizza la posizione Y (0 = alto/soft, 1 = basso/hard)
    final normalizedY = position.dy / visualizerHeight;
    
    // Inverti la scala (0 = soft, 1 = hard)
    final intensity = (1.0 - normalizedY).clamp(0.0, 1.0);
    
    // Converti in valore per Vibration API (1-255)
    return (intensity * 255).round();
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
          ),
          child: Column(
            children: [
              Icon(icon, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPatternLibrary(bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Libreria Pattern',
          style: TextStyle(
            fontSize: isSmallScreen ? 18 : 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        SizedBox(height: isSmallScreen ? 12 : 16),
        SizedBox(
          height: isSmallScreen ? 100.0 : 120.0,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _savedPatterns.length,
            itemBuilder: (context, index) {
              final pattern = _savedPatterns[index];
              return _buildPatternCard(pattern, isSmallScreen);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPatternCard(VibrationPattern pattern, bool isSmallScreen) {
    final isSelected = _selectedPattern?.id == pattern.id;
    
    return Container(
      width: isSmallScreen ? 140.0 : 160.0,
      margin: EdgeInsets.only(right: isSmallScreen ? 8.0 : 12.0),
      child: Card(
        elevation: isSelected ? 8 : 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected ? AppTheme.limeAccent : Colors.transparent,
            width: 2,
          ),
        ),
        child: InkWell(
          onTap: () => _loadPattern(pattern),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.all(isSmallScreen ? 8 : 12), // Ridotto il padding
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(int.parse('0xFF${pattern.color.substring(1)}')).withOpacity(0.1),
                  Color(int.parse('0xFF${pattern.color.substring(1)}')).withOpacity(0.05),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // Importante per evitare overflow
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.music_note_rounded,
                      color: Color(int.parse('0xFF${pattern.color.substring(1)}')),
                      size: isSmallScreen ? 14 : 18, // Ridotto
                    ),
                    SizedBox(width: isSmallScreen ? 3 : 6), // Ridotto
                    Expanded(
                      child: Text(
                        pattern.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                          fontSize: isSmallScreen ? 10 : 13, // Ridotto
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isSmallScreen ? 2 : 4), // Ridotto
                Text(
                  '${pattern.pattern.length} impulsi',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 8 : 11, // Ridotto
                    color: AppTheme.textSecondary,
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => _playPattern(pattern.pattern),
                      icon: Icon(
                        Icons.play_arrow_rounded,
                        color: Color(int.parse('0xFF${pattern.color.substring(1)}')),
                        size: isSmallScreen ? 14 : 18, // Ridotto
                      ),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(
                        minWidth: isSmallScreen ? 24 : 32, // Ridotto
                        minHeight: isSmallScreen ? 24 : 32, // Ridotto
                      ),
                    ),
                    IconButton(
                      onPressed: () => _deletePattern(pattern.id),
                      icon: Icon(
                        Icons.delete_rounded,
                        color: Colors.red.withOpacity(0.7),
                        size: isSmallScreen ? 14 : 18, // Ridotto
                      ),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(
                        minWidth: isSmallScreen ? 24 : 32, // Ridotto
                        minHeight: isSmallScreen ? 24 : 32, // Ridotto
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _playPattern([List<int>? pattern]) async {
    final patternToPlay = pattern ?? _currentPattern;
    if (patternToPlay.isEmpty) {
      return; // Rimossa la notifica per rendere l'app più fluida
    }

    setState(() {
      _isPlaying = true;
    });

    _animationController.repeat();

    try {
      if (PlatformService.isAndroid) {
        // Android: usa Vibration API
        if (await Vibration.hasVibrator() ?? false) {
          // Se abbiamo intensità personalizzate, usale
          if (_currentIntensities.isNotEmpty && _currentIntensities.length == patternToPlay.length) {
            // Crea pattern con intensità personalizzate
            final patternWithIntensity = <int>[];
            for (int i = 0; i < patternToPlay.length; i++) {
              patternWithIntensity.add(patternToPlay[i]);
              if (i < _currentIntensities.length) {
                // Aggiungi una pausa basata sull'intensità (più intenso = meno pausa)
                final pause = (255 - _currentIntensities[i]) ~/ 10; // 0-25ms di pausa
                if (pause > 0) patternWithIntensity.add(pause);
              }
            }
            await Vibration.vibrate(pattern: patternWithIntensity);
          } else {
            await Vibration.vibrate(pattern: patternToPlay);
          }
          
        }
      } else if (PlatformService.isIOS) {
        // iOS: usa haptic feedback per ogni impulso
        for (int i = 0; i < patternToPlay.length; i++) {
          final intensity = i < _currentIntensities.length ? _currentIntensities[i] : 128;
          _triggerHapticFeedback(intensity);
          
          // Attendi la durata dell'impulso
          await Future.delayed(Duration(milliseconds: patternToPlay[i]));
        }
        
      }
    } catch (e) {
      
    }

    Future.delayed(Duration(milliseconds: patternToPlay.fold(0, (a, b) => a + b)), () {
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
        _animationController.stop();
      }
    });
  }

  void _stopPlaying() async {
    setState(() {
      _isPlaying = false;
    });
    
    _animationController.stop();
    
    try {
      if (PlatformService.isAndroid) {
        await Vibration.cancel();
        
      } else if (PlatformService.isIOS) {
        // iOS non ha bisogno di fermare haptic feedback
        
      }
    } catch (e) {
      
    }
  }

  void _toggleRecording() {
    setState(() {
      _isRecording = !_isRecording;
    });

    if (_isRecording) {
      _startRecording();
    } else {
      _stopRecording();
    }
  }

  void _clearPattern() {
    setState(() {
      _currentPattern.clear();
      _currentIntensities.clear();
      _selectedPattern = null;
    });
  }

  void _createManualPattern() {
    _showManualPatternDialog();
  }

  void _addPattern() {
    if (_currentPattern.isEmpty) {
      return; // Rimossa la notifica per rendere l'app più fluida
    }

    _showSaveDialog();
  }

  void _showSaveDialog() {
    final nameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Salva Pattern',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: 'Nome del pattern',
            labelStyle: TextStyle(color: AppTheme.textSecondary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annulla', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                _savePattern(nameController.text);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.limeAccent,
            ),
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }

  void _savePattern(String name) async {
    final pattern = VibrationPattern(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      pattern: List.from(_currentPattern),
      color: '#${AppTheme.limeAccent.value.toRadixString(16).substring(2)}',
      createdAt: DateTime.now(),
    );

    await _patternService.savePattern(pattern);
    await _loadSavedPatterns();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pattern "$name" salvato!'),
        backgroundColor: AppTheme.limeAccent,
      ),
    );
  }

  void _loadPattern(VibrationPattern pattern) {
    setState(() {
      _currentPattern = List.from(pattern.pattern);
      _selectedPattern = pattern;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pattern "${pattern.name}" caricato!'),
        backgroundColor: AppTheme.primary,
      ),
    );
  }

  void _deletePattern(String patternId) async {
    await _patternService.deletePattern(patternId);
    await _loadSavedPatterns();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pattern eliminato!'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showManualPatternDialog() {
    final patternController = TextEditingController();
    patternController.text = _currentPattern.isEmpty ? '0,200,100,300,100,200' : _currentPattern.join(',');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Crea Pattern Manualmente',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Inserisci i valori separati da virgola (es: 0,200,100,300)',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            SizedBox(height: 16),
            TextField(
              controller: patternController,
              decoration: InputDecoration(
                labelText: 'Pattern (millisecondi)',
                labelStyle: TextStyle(color: AppTheme.textSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                hintText: '0,200,100,300,100,200',
                hintStyle: TextStyle(color: AppTheme.textSecondary.withOpacity(0.5)),
              ),
              style: TextStyle(color: AppTheme.textPrimary),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final text = patternController.text.trim();
                      if (text.isNotEmpty) {
                        try {
                          final values = text.split(',').map((e) => int.parse(e.trim())).toList();
                          setState(() {
                            _currentPattern = values;
                          });
                          Navigator.pop(context);
                          // Rimossa la notifica per rendere l'app più fluida
                        } catch (e) {
                          // Rimossa la notifica per rendere l'app più fluida
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.limeAccent,
                    ),
                    child: const Text('Crea'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annulla', style: TextStyle(color: AppTheme.textSecondary)),
          ),
        ],
      ),
    );
  }

  void _saveCurrentPattern() {
    if (_currentPattern.isEmpty) {
      return; // Rimossa la notifica per rendere l'app più fluida
    }
    _addPattern();
  }
}

class WavePainter extends CustomPainter {
  final List<int> pattern;
  final List<int> intensities; // Nuovo: lista delle intensità
  final Animation<double> animation;
  final bool isPlaying;
  final bool isSmallScreen;

  WavePainter({
    required this.pattern,
    required this.intensities,
    required this.animation,
    required this.isPlaying,
    required this.isSmallScreen,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.limeAccent.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    if (pattern.isEmpty) {
      // Draw a static line if no pattern
      canvas.drawLine(
        Offset(0, size.height / 2), 
        Offset(size.width, size.height / 2), 
        paint..strokeWidth = isSmallScreen ? 1.5 : 2
      );
      return;
    }

    // Fix NaN error when pattern has only one element
    if (pattern.length == 1) {
      final double x = size.width / 2; // Center the single impulse
      final intensity = intensities.isNotEmpty ? intensities[0] / 255.0 : 0.5;
      final double y = size.height / 2 + (Math.sin(animation.value * 2 * Math.pi) * intensity * (size.height / 4));
      final circleSize = isSmallScreen ? 4.0 * intensity : 5.0 * intensity;
      canvas.drawCircle(Offset(x, y), circleSize, paint);
      return;
    }

    // Draw wave for multiple impulses with intensity
    for (int i = 0; i < pattern.length; i++) {
      // Fix division by zero by ensuring pattern.length - 1 is never zero
      final double x = size.width * (i / (pattern.length - 1.0));
      
      // Usa l'intensità per modificare l'ampiezza e la dimensione
      final intensity = i < intensities.length ? intensities[i] / 255.0 : 0.5;
      final double y = size.height / 2 + (Math.sin(animation.value * 2 * Math.pi + i * 0.5) * intensity * (size.height / 4));
      
      // Check for NaN values before drawing
      if (x.isFinite && y.isFinite) {
        // Disegna cerchi più grandi per intensità maggiori
        final circleSize = isSmallScreen ? 4.0 * intensity : 5.0 * intensity;
        canvas.drawCircle(Offset(x, y), circleSize, paint);
        
        // Aggiungi un'aura per le intensità alte (solo su schermi grandi)
        if (!isSmallScreen && intensity > 0.7) {
          canvas.drawCircle(
            Offset(x, y), 
            8.0 * intensity, 
            Paint()
              ..color = AppTheme.limeAccent.withOpacity(0.3)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    WavePainter oldPainter = oldDelegate as WavePainter;
    return oldPainter.pattern != pattern || 
           oldPainter.intensities != intensities ||
           oldPainter.animation.value != animation.value || 
           oldPainter.isPlaying != isPlaying ||
           oldPainter.isSmallScreen != isSmallScreen;
  }
} 
