import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:vibration/vibration.dart';
import 'dart:math' as Math;
import '../theme.dart';
import '../services/vibration_pattern_service.dart';
import '../services/platform_service.dart';
import '../services/advanced_haptics_service.dart';

class VibeComposerScreen extends StatefulWidget {
  const VibeComposerScreen({Key? key}) : super(key: key);

  @override
  State<VibeComposerScreen> createState() => _VibeComposerScreenState();
}

class _VibeComposerScreenState extends State<VibeComposerScreen>
    with TickerProviderStateMixin {
  final VibrationPatternService _patternService = VibrationPatternService();
  final AdvancedHapticsService _hapticsService = AdvancedHapticsService();
  
  List<double> _currentPattern = [];
  List<int> _currentIntensities = [];
  List<int> _currentGaps = [];
  double _currentTouchIntensity = 0.5;
  double _visualizerHeight = 280.0;
  final GlobalKey _visualizerKey = GlobalKey();
  bool _isRecording = false;
  bool _isPlaying = false;
  late AnimationController _animationController;
  late Animation<double> _animation;
  List<VibrationPattern> _savedPatterns = [];
  VibrationPattern? _selectedPattern;
  DateTime? _recordingStartTime;
  bool _isVibrating = false;
  int _lastIntensity = 200;
  DateTime? _lastReleaseTime;
  DateTime? _segmentStartTime;
  int _segmentCurrentIntensity = 128;
  bool _hasAmplitudeControl = false;
  bool _hasVibrator = true;

  static const int _minSegmentMs = 50;
  static const int _intensityChangeThreshold = 20;
  static const int _minTapGapMs = 50;

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
    _detectVibrationCapabilities();
    _initializeHaptics();
  }

  Future<void> _initializeHaptics() async {
    await _hapticsService.initialize();
  }

  Future<void> _detectVibrationCapabilities() async {
    try {
      _hasVibrator = await Vibration.hasVibrator() ?? true;
      _hasAmplitudeControl = await Vibration.hasAmplitudeControl() ?? false;
    } catch (_) {
      _hasVibrator = true;
      _hasAmplitudeControl = false;
    }
    if (mounted) setState(() {});
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
    final isSmallScreen = screenHeight < 700;
    
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isSmallScreen),
            Expanded(
              child: SingleChildScrollView(
                // Disabilita lo scroll durante la registrazione - FIXED FOR iOS 18.6
                physics: _isRecording ? NeverScrollableScrollPhysics() : AlwaysScrollableScrollPhysics(),
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
            child: Text(
              'Vibe Composer',
              style: TextStyle(
                fontSize: isSmallScreen ? 20 : 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.close,
              color: AppTheme.textSecondary,
              size: isSmallScreen ? 20 : 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisualizer(bool isSmallScreen) {
    return Container(
      height: _visualizerHeight,
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isRecording ? AppTheme.limeAccent : AppTheme.surfaceLight,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: GestureDetector(
          key: _visualizerKey,
          onTapDown: _isRecording ? _onVisualizerTapDown : null,
          onTapUp: _isRecording ? _onVisualizerTapUp : null,
          onTapCancel: _isRecording ? _onVisualizerTapCancel : null,
          onPanStart: _isRecording ? _onVisualizerPanStart : null,
          onPanUpdate: _isRecording ? _onVisualizerPanUpdate : null,
          onPanEnd: _isRecording ? _onVisualizerPanEnd : null,
          // FIXED FOR iOS 18.6: Disabilita il movimento della pagina durante la registrazione
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              // Background grid
              _buildGrid(),
              // Pattern visualization
              _buildPatternVisualization(),
              // Recording indicator
              if (_isRecording) _buildRecordingIndicator(),
              // Touch indicator
              if (_isVibrating) _buildTouchIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrid() {
    return CustomPaint(
      size: Size.infinite,
      painter: GridPainter(
        color: AppTheme.surfaceLight.withOpacity(0.3),
        gridSize: 20,
      ),
    );
  }

  Widget _buildPatternVisualization() {
    if (_currentPattern.isEmpty) {
      return Center(
        child: Text(
          _isRecording ? 'Tocca per registrare' : 'Nessun pattern',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 16,
          ),
        ),
      );
    }

    return CustomPaint(
      size: Size.infinite,
      painter: PatternPainter(
        pattern: _currentPattern,
        intensities: _currentIntensities,
        gaps: _currentGaps,
        isPlaying: _isPlaying,
        animation: _animation,
      ),
    );
  }

  Widget _buildRecordingIndicator() {
    return Positioned(
      top: 16,
      right: 16,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.limeAccent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 6),
            Text(
              'Registrando',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTouchIndicator() {
    return Positioned(
      left: 16,
      bottom: 16,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.limeAccent.withOpacity(0.8),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'Intensità: ${(_currentTouchIntensity * 100).round()}%',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildControls(bool isSmallScreen) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildControlButton(
          icon: _isRecording ? Icons.stop : Icons.fiber_manual_record,
          label: _isRecording ? 'Stop' : 'Registra',
          color: _isRecording ? Colors.red : AppTheme.limeAccent,
          onPressed: _toggleRecording,
          isSmallScreen: isSmallScreen,
        ),
        _buildControlButton(
          icon: _isPlaying ? Icons.stop : Icons.play_arrow,
          label: _isPlaying ? 'Stop' : 'Riproduci',
          color: _isPlaying ? Colors.red : AppTheme.limeAccent,
          onPressed: _isPlaying ? _stopPlaying : _playPattern,
          isSmallScreen: isSmallScreen,
        ),
        _buildControlButton(
          icon: Icons.clear,
          label: 'Cancella',
          color: Colors.orange,
          onPressed: _clearPattern,
          isSmallScreen: isSmallScreen,
        ),
        _buildControlButton(
          icon: Icons.save,
          label: 'Salva',
          color: AppTheme.limeAccent,
          onPressed: _addPattern,
          isSmallScreen: isSmallScreen,
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
    required bool isSmallScreen,
  }) {
    final iconSize = isSmallScreen ? 20.0 : 24.0;
    final fontSize = isSmallScreen ? 10.0 : 12.0;
    
    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 8 : 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 3,
            side: BorderSide.none,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: iconSize, color: Colors.white),
              SizedBox(height: isSmallScreen ? 1 : 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // UPDATED FOR iOS 18.6: Gestione touch migliorata
  void _onVisualizerTapDown(TapDownDetails details) {
    if (!_isRecording) return;
    
    final renderBox = _visualizerKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    
    _startInteractiveRecording(localPosition);
  }

  void _onVisualizerTapUp(TapUpDetails details) {
    if (!_isRecording) return;
    
    final renderBox = _visualizerKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    
    _stopInteractiveRecording(localPosition);
  }

  void _onVisualizerTapCancel() {
    if (!_isRecording) return;
    _stopInteractiveRecording(null);
  }

  void _onVisualizerPanStart(DragStartDetails details) {
    if (!_isRecording) return;
    
    final renderBox = _visualizerKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    
    _startInteractiveRecording(localPosition);
  }

  void _onVisualizerPanUpdate(DragUpdateDetails details) {
    if (!_isRecording) return;
    
    final renderBox = _visualizerKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    
    _updateVibrationIntensity(localPosition);
  }

  void _onVisualizerPanEnd(DragEndDetails details) {
    if (!_isRecording) return;
    _stopInteractiveRecording(null);
  }

  void _startRecording() {
    setState(() {
      _currentPattern.clear();
      _currentIntensities.clear();
      _currentGaps.clear();
      _recordingStartTime = DateTime.now();
      _lastReleaseTime = null;
    });
  }

  void _stopRecording() {
    // Niente di speciale
  }

  // UPDATED FOR iOS 18.6: Registrazione interattiva migliorata
  void _startInteractiveRecording(Offset position) {
    setState(() {
      _isVibrating = true;
    });
    
    final intensity = _calculateIntensityFromPosition(position, visualizerHeight: _visualizerHeight);
    _lastIntensity = intensity;
    _segmentStartTime = DateTime.now();
    _segmentCurrentIntensity = intensity;
    
    setState(() {
      _currentTouchIntensity = intensity / 255.0;
    });
    
    // Registra gap
    final now = DateTime.now();
    int gapMs = 0;
    if (_lastReleaseTime != null) {
      gapMs = now.difference(_lastReleaseTime!).inMilliseconds;
    } else if (_recordingStartTime != null && _currentPattern.isEmpty) {
      gapMs = now.difference(_recordingStartTime!).inMilliseconds;
    }
    _currentGaps.add(gapMs < _minTapGapMs ? _minTapGapMs : gapMs.clamp(0, 10000));
    
    // UPDATED FOR iOS 18.6: Feedback tattile migliorato
    _hapticsService.playRecordingFeedback(intensity / 255.0);
  }

  void _updateVibrationIntensity(Offset position) {
    final intensity = _calculateIntensityFromPosition(position, visualizerHeight: _visualizerHeight);
    _lastIntensity = intensity;
    
    setState(() {
      _currentTouchIntensity = intensity / 255.0;
    });

    // Split segment se necessario
    if (_segmentStartTime != null) {
      final elapsed = DateTime.now().difference(_segmentStartTime!).inMilliseconds;
      if (elapsed >= _minSegmentMs && (intensity - _segmentCurrentIntensity).abs() >= _intensityChangeThreshold) {
        final segmentDuration = elapsed.clamp(5, 6000);
        setState(() {
          if (_currentGaps.length == _currentPattern.length) {
            _currentGaps.add(10);
          }
          _currentPattern.add(segmentDuration.toDouble());
          _currentIntensities.add(_segmentCurrentIntensity);
          _segmentStartTime = DateTime.now();
          _segmentCurrentIntensity = intensity;
        });
      }
    }
  }

  void _stopInteractiveRecording(Offset? position) {
    setState(() {
      _isVibrating = false;
      _currentTouchIntensity = 0.5;
    });
    
    // Chiudi l'ultimo segmento
    if (_segmentStartTime != null) {
      final elapsed = DateTime.now().difference(_segmentStartTime!).inMilliseconds;
      final duration = elapsed.clamp(5, 6000);
      if (duration >= 5) {
        setState(() {
          _currentPattern.add(duration.toDouble());
          _currentIntensities.add(_segmentCurrentIntensity);
        });
      }
      _segmentStartTime = null;
    }
    
    _lastReleaseTime = DateTime.now();
  }

  int _calculateIntensityFromPosition(Offset position, {required double visualizerHeight}) {
    final normalizedY = (visualizerHeight - position.dy) / visualizerHeight;
    return (normalizedY * 255).clamp(0, 255).round();
  }

  Widget _buildPatternLibrary(bool isSmallScreen) {
    if (_savedPatterns.isEmpty) {
      return Container(
        padding: EdgeInsets.all(20),
        child: Text(
          'Nessun pattern salvato',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 16,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pattern Salvati',
          style: TextStyle(
            fontSize: isSmallScreen ? 18 : 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        SizedBox(height: 12),
        Container(
          height: isSmallScreen ? 120 : 150,
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
      width: isSmallScreen ? 100 : 120,
      margin: EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () => _selectPattern(pattern),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.limeAccent : AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppTheme.limeAccent : AppTheme.surfaceLight,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Color(int.parse(pattern.color.replaceAll('#', '0xFF'))),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.vibration,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              SizedBox(height: 8),
              Text(
                pattern.name,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textPrimary,
                  fontSize: isSmallScreen ? 10 : 12,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectPattern(VibrationPattern pattern) {
    setState(() {
      _selectedPattern = pattern;
      _currentPattern = pattern.pattern.map((p) => p * 1000).toList(); // Convert to milliseconds
      _currentIntensities = pattern.pattern.map((p) => (p * 255).round()).toList();
      _currentGaps = List.filled(pattern.pattern.length - 1, 100); // Default gaps
    });
  }

  // UPDATED FOR iOS 18.6: Riproduzione pattern migliorata
  void _playPattern() async {
    if (_currentPattern.isEmpty) return;

    setState(() {
      _isPlaying = true;
    });

    _animationController.forward();

    try {
      // UPDATED FOR iOS 18.6: Usa il servizio di haptic avanzato
      await _hapticsService.playPattern(_currentPattern.map((p) => p / 1000.0).toList());
    } catch (e) {
      // Fallback a vibrazione tradizionale
      try {
        if (PlatformService.isAndroid) {
          final patternToPlay = _currentPattern.map((p) => p.round()).toList();
          await Vibration.vibrate(pattern: patternToPlay);
        } else if (PlatformService.isIOS) {
          // iOS fallback
          for (int i = 0; i < _currentPattern.length; i++) {
            final intensity = _currentIntensities[i] / 255.0;
            await _hapticsService.playIntensityHaptic(intensity);
            if (i < _currentPattern.length - 1) {
              await Future.delayed(Duration(milliseconds: _currentPattern[i].round()));
            }
          }
        }
      } catch (e) {
        // Gestione errori silenziosa
      }
    }

    // Calcola durata totale
    int totalMs = 0;
    if (_currentGaps.isNotEmpty) totalMs += _currentGaps.first.clamp(0, 10000);
    for (int i = 0; i < _currentPattern.length; i++) {
      totalMs += _currentPattern[i].round();
      if (i + 1 < _currentGaps.length) totalMs += _currentGaps[i + 1].clamp(0, 10000);
    }
    
    Future.delayed(Duration(milliseconds: totalMs), () {
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
      }
    } catch (e) {
      // Gestione errori silenziosa
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

  void _addPattern() {
    if (_currentPattern.isEmpty) return;
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
            child: const Text(
              'Salva',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _savePattern(String name) async {
    final normalizedPattern = _currentPattern.map((duration) => 
      (duration / 1000.0).clamp(0.0, 1.0)
    ).toList();
    
    final pattern = VibrationPattern(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      pattern: normalizedPattern,
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
}

// Custom painters for visualization
class GridPainter extends CustomPainter {
  final Color color;
  final double gridSize;

  GridPainter({required this.color, required this.gridSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PatternPainter extends CustomPainter {
  final List<double> pattern;
  final List<int> intensities;
  final List<int> gaps;
  final bool isPlaying;
  final Animation<double> animation;

  PatternPainter({
    required this.pattern,
    required this.intensities,
    required this.gaps,
    required this.isPlaying,
    required this.animation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (pattern.isEmpty) return;

    final paint = Paint()
      ..color = AppTheme.limeAccent
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final path = Path();
    double currentX = 0;
    double currentY = size.height / 2;

    for (int i = 0; i < pattern.length; i++) {
      final duration = pattern[i];
      final intensity = intensities[i];
      final normalizedIntensity = intensity / 255.0;
      
      final segmentWidth = (duration / 1000.0) * size.width * 0.1; // Scale factor
      final segmentHeight = normalizedIntensity * size.height * 0.8;
      
      final targetY = size.height / 2 - segmentHeight / 2;
      
      if (i == 0) {
        path.moveTo(currentX, currentY);
      }
      
      path.lineTo(currentX + segmentWidth / 2, targetY);
      path.lineTo(currentX + segmentWidth, targetY);
      
      currentX += segmentWidth;
      currentY = targetY;
      
      // Add gap if available
      if (i < gaps.length) {
        final gapWidth = (gaps[i] / 1000.0) * size.width * 0.1;
        currentX += gapWidth;
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 
