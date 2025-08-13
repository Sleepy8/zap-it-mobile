import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
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
    final visualizerHeight = isSmallScreen ? 320.0 : 400.0;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              key: _visualizerKey,
              height: visualizerHeight,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _visualizerHeight = constraints.maxHeight;
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
                      borderRadius: BorderRadius.circular(20),
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
                        if (_isRecording)
                          Positioned.fill(
                            child: GestureDetector(
                              onTapDown: _onVisualizerTapDown,
                              onTapUp: _onVisualizerTapUp,
                              onPanStart: _onVisualizerPanStart,
                              onPanUpdate: _onVisualizerPanUpdate,
                              onPanEnd: _onVisualizerPanEnd,
                              behavior: HitTestBehavior.opaque,
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
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            height: visualizerHeight,
            child: _buildIntensityScale(),
          ),
        ],
      ),
    );
  }

  Widget _buildIntensityScale() {
    return Column(
      children: List.generate(11, (index) {
        final percentage = 100 - (index * 10);
        final isActive = _currentTouchIntensity >= (percentage / 100);
        
        final itemHeight = (_visualizerHeight / 10) * 0.9;
        
        return SizedBox(
          height: itemHeight,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$percentage%',
              style: TextStyle(
                color: isActive ? AppTheme.limeAccent : Colors.white.withOpacity(0.4),
                fontSize: 8,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                letterSpacing: 0.0,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildControls(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildSmallControlButton(
            icon: _isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
            label: _isPlaying ? 'Stop' : 'Play',
            onPressed: () {
              if (_isPlaying) {
                _stopPlaying();
              } else {
                _playPattern();
              }
            },
            color: _isPlaying ? AppTheme.buttonDanger : AppTheme.buttonSuccess,
            isSmallScreen: isSmallScreen,
          ),
          _buildSmallControlButton(
            icon: Icons.fiber_manual_record_rounded,
            label: 'Record',
            onPressed: _toggleRecording,
            color: _isRecording ? AppTheme.buttonDanger : AppTheme.buttonWarning,
            isSmallScreen: isSmallScreen,
          ),
          _buildSmallControlButton(
            icon: Icons.clear_rounded,
            label: 'Clear',
            onPressed: _clearPattern,
            color: AppTheme.buttonDanger,
            isSmallScreen: isSmallScreen,
          ),
          _buildSmallControlButton(
            icon: Icons.save_rounded,
            label: 'Save',
            onPressed: _saveCurrentPattern,
            color: AppTheme.buttonSecondary,
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
          padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
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
    );
  }

  // SEMPLIFICATO PER iOS - NO TIMER COMPLESSI
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

  // SEMPLIFICATO PER iOS - NO TIMER
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
    
    // SEMPLIFICATO - SOLO UN FEEDBACK INIZIALE
    if (PlatformService.isAndroid) {
      if (_hasAmplitudeControl) {
        Vibration.vibrate(duration: 100, amplitude: intensity);
      } else {
        Vibration.vibrate(duration: 100);
      }
    } else if (PlatformService.isIOS) {
      _triggerHapticFeedback(intensity);
    }
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

  void _triggerHapticFeedback(int intensity) {
    if (PlatformService.isIOS) {
      if (intensity > 180) {
        HapticFeedback.heavyImpact();
      } else if (intensity > 120) {
        HapticFeedback.mediumImpact();
      } else if (intensity > 60) {
        HapticFeedback.lightImpact();
      } else {
        HapticFeedback.selectionClick();
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

  int _calculateIntensityFromPosition(Offset position, {double? visualizerHeight}) {
    final height = visualizerHeight ?? _visualizerHeight;
    final normalizedY = (position.dy / height).clamp(0.0, 1.0);
    final intensity = (1.0 - normalizedY).clamp(0.0, 1.0);
    return (intensity * 255).round().clamp(0, 255);
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

  Widget _buildPatternCard(VibrationPattern pattern, isSmallScreen) {
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
            padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
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
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.music_note_rounded,
                      color: Color(int.parse('0xFF${pattern.color.substring(1)}')),
                      size: isSmallScreen ? 14 : 18,
                    ),
                    SizedBox(width: isSmallScreen ? 3 : 6),
                    Expanded(
                      child: Text(
                        pattern.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                          fontSize: isSmallScreen ? 10 : 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isSmallScreen ? 2 : 4),
                Text(
                  '${pattern.pattern.length} impulsi',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 8 : 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => _playPattern(
                        pattern.pattern,
                        List<int>.filled(pattern.pattern.length, 220),
                        _synthesizeGaps(pattern.pattern.length),
                      ),
                      icon: Icon(
                        Icons.play_arrow_rounded,
                        color: Color(int.parse('0xFF${pattern.color.substring(1)}')),
                        size: isSmallScreen ? 14 : 18,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(
                        minWidth: isSmallScreen ? 24 : 32,
                        minHeight: isSmallScreen ? 24 : 32,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _deletePattern(pattern.id),
                      icon: Icon(
                        Icons.delete_rounded,
                        color: Colors.red.withOpacity(0.7),
                        size: isSmallScreen ? 14 : 18,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(
                        minWidth: isSmallScreen ? 24 : 32,
                        minHeight: isSmallScreen ? 24 : 32,
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

  // SEMPLIFICATO PER iOS - NO TIMER COMPLESSI
  void _playPattern([List<double>? pattern, List<int>? intensities, List<int>? gaps]) async {
    final patternToPlay = pattern ?? _currentPattern;
    final intensitiesToPlay = intensities ?? (
      _currentIntensities.length == patternToPlay.length
        ? _currentIntensities
        : List<int>.filled(patternToPlay.length, 220)
    );
    final gapsToPlay = gaps ?? (
      _currentGaps.length == patternToPlay.length
        ? _currentGaps
        : _synthesizeGaps(patternToPlay.length)
    );
    
    if (patternToPlay.isEmpty) return;

    setState(() {
      _isPlaying = true;
    });

    _animationController.repeat();

    try {
      if (PlatformService.isAndroid) {
        final hasVibrator = await Vibration.hasVibrator() ?? false;
        if (hasVibrator) {
          final hasAmplitude = await Vibration.hasAmplitudeControl() ?? false;

          final fullPattern = <int>[];
          final fullIntensities = <int>[];
          
          fullPattern.add(gapsToPlay.isNotEmpty ? gapsToPlay.first.clamp(0, 10000) : 0);
          fullIntensities.add(0);

          for (int i = 0; i < patternToPlay.length; i++) {
            final rawDuration = patternToPlay[i].round();
            final onDuration = rawDuration.clamp(5, 6000);
            fullPattern.add(onDuration);

            int amplitude = (i < intensitiesToPlay.length ? intensitiesToPlay[i] : 220);
            amplitude = amplitude.clamp(1, 255);
            fullIntensities.add(amplitude);

            final gap = (i + 1 < gapsToPlay.length) ? gapsToPlay[i + 1].clamp(0, 10000) : 0;
            if (i < patternToPlay.length - 1) {
              fullPattern.add(gap);
              fullIntensities.add(0);
            }
          }

          if (hasAmplitude) {
            await Vibration.vibrate(pattern: fullPattern, intensities: fullIntensities);
          } else {
            await Vibration.vibrate(pattern: fullPattern);
          }
        }
      } else if (PlatformService.isIOS) {
        // SEMPLIFICATO - SOLO HAPTIC FEEDBACK SEMPLICE
        for (int i = 0; i < patternToPlay.length; i++) {
          final intensity = i < intensitiesToPlay.length ? intensitiesToPlay[i] : 128;
          
          _triggerHapticFeedback(intensity);
          
          // Attendi la durata dell'impulso
          await Future.delayed(Duration(milliseconds: patternToPlay[i].round()));
        }
      }
    } catch (e) {
      // Gestione errori silenziosa
    }

    // Calcola durata totale
    int totalMs = 0;
    if (gapsToPlay.isNotEmpty) totalMs += gapsToPlay.first.clamp(0, 10000);
    for (int i = 0; i < patternToPlay.length; i++) {
      totalMs += patternToPlay[i].round();
      if (i + 1 < gapsToPlay.length) totalMs += gapsToPlay[i + 1].clamp(0, 10000);
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

  void _loadPattern(VibrationPattern pattern) {
    setState(() {
      _currentPattern = pattern.pattern.map((value) => 
        (value * 1000.0).round().toDouble()
      ).toList();
      _currentIntensities = List<int>.filled(pattern.pattern.length, 220);
      _currentGaps = _synthesizeGaps(_currentPattern.length);
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

  List<int> _synthesizeGaps(int segments) {
    if (segments <= 0) return [];
    final List<int> gaps = [];
    gaps.add(0);
    for (int i = 1; i < segments; i++) {
      gaps.add(60);
    }
    return gaps;
  }

  void _saveCurrentPattern() {
    if (_currentPattern.isEmpty) return;
    _addPattern();
  }
}

class WavePainter extends CustomPainter {
  final List<double> pattern;
  final List<int> intensities;
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
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(20),
    );
    canvas.drawRRect(rect, borderPaint);
    
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    for (int i = 0; i <= 10; i++) {
      final y = (size.height / 10) * i;
      final isMainLine = i % 2 == 0;
      
      final path = Path();
      path.moveTo(10, y);
      path.lineTo(size.width - 10, y);
      
      canvas.drawPath(
        path,
        gridPaint..strokeWidth = isMainLine ? 1.2 : 0.6,
      );
    }

    for (int i = 0; i <= 10; i++) {
      final x = (size.width / 10) * i;
      final isMainLine = i % 2 == 0;
      
      final path = Path();
      path.moveTo(x, 10);
      path.lineTo(x, size.height - 10);
      
      canvas.drawPath(
        path,
        gridPaint..strokeWidth = isMainLine ? 1.2 : 0.6,
      );
    }

    final paint = Paint()
      ..color = AppTheme.limeAccent.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    if (pattern.isEmpty) {
      canvas.drawLine(
        Offset(0, size.height / 2), 
        Offset(size.width, size.height / 2), 
        paint..strokeWidth = isSmallScreen ? 1.5 : 2
      );
      return;
    }

    if (pattern.length == 1) {
      final double x = size.width / 2;
      final intensity = intensities.isNotEmpty ? intensities[0] / 255.0 : 0.5;
      final double y = size.height / 2 + (Math.sin(animation.value * 2 * Math.pi) * intensity * (size.height / 4));
      final circleSize = isSmallScreen ? 4.0 * intensity : 5.0 * intensity;
      canvas.drawCircle(Offset(x, y), circleSize, paint);
      return;
    }

    for (int i = 0; i < pattern.length; i++) {
      final double x = size.width * (i / (pattern.length - 1.0));
      
      final intensity = i < intensities.length ? intensities[i] / 255.0 : 0.5;
      final double y = size.height / 2 + (Math.sin(animation.value * 2 * Math.pi + i * 0.5) * intensity * (size.height / 4));
      
      if (x.isFinite && y.isFinite) {
        final circleSize = isSmallScreen ? 4.0 * intensity : 5.0 * intensity;
        canvas.drawCircle(Offset(x, y), circleSize, paint);
        
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
