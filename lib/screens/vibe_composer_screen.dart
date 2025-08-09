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
  List<int> _currentPattern = [];
  List<int> _currentIntensities = []; // Nuovo: lista delle intensità
  List<int> _currentGaps = []; // Gap (ms) PRIMA di ogni segmento (il primo è il delay iniziale)
  bool _isRecording = false;
  bool _isPlaying = false;
  late AnimationController _animationController;
  late Animation<double> _animation;
  List<VibrationPattern> _savedPatterns = [];
  VibrationPattern? _selectedPattern;
  DateTime? _recordingStartTime;
  DateTime? _vibrationStartTime;
  bool _isVibrating = false;
  Timer? _vibrationTimer;
  int _lastIntensity = 200;
  DateTime? _lastReleaseTime; // per misurare gap tra pressioni separate
  // Recording segmentation for precise duration and intensity tracking
  DateTime? _segmentStartTime;
  int _segmentCurrentIntensity = 128;
  // Live vibration refresh strategy to keep continuous feeling (no perceivable gaps)
  static const int _liveChunkMs = 400; // chunk duration we (re)issue
  static const int _liveRefreshMs = 150; // refresh rate to overlap chunks
  // PWM fallback constants for playback on devices without amplitude control
  static const double _dutyMin = 0.35;
  static const int _microPeriodMs = 80;
  static const int _minOnMs = 30;
  bool _hasAmplitudeControl = false;
  bool _hasVibrator = true;

  static const int _minSegmentMs = 30; // minimum duration per segment to register
  static const int _intensityChangeThreshold = 12; // change needed to split segment
  static const int _minTapGapMs = 40; // minimum OFF gap between separate taps

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
            icon: Icons.add_rounded,
            label: 'Create',
            onPressed: _createManualPattern,
            color: AppTheme.buttonAccent,
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
    
    // Aggiorna l'intensità in tempo reale durante il trascinamento - MIGLIORATA LA REATTIVITÀ
    _updateVibrationIntensity(localPosition);
    
    // NON registrare impulsi intermedi durante il trascinamento - la vibrazione continua
    // verrà registrata solo quando si rilascia il dito
  }

  void _onVisualizerPanEnd(DragEndDetails details) {
    if (!_isRecording) return;
    
    _stopInteractiveRecording(null);
  }

  // RIMOSSO IL METODO _recordIntermediateImpulse - non serve più

  void _startRecording() {
    setState(() {
      _currentPattern.clear();
      _currentIntensities.clear(); // Pulisci anche le intensità
      _currentGaps.clear();
      _recordingStartTime = DateTime.now();
      _lastReleaseTime = null;
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
    
    // Calcola l'intensità basata sulla posizione Y - MIGLIORATA LA SENSIBILITÀ
    final intensity = _calculateIntensityFromPosition(position);
    _lastIntensity = intensity;
    _segmentStartTime = DateTime.now();
    _segmentCurrentIntensity = intensity;
    // Registra gap (off) PRIMA del segmento corrente
    final now = DateTime.now();
    int gapMs = 0;
    if (_lastReleaseTime != null) {
      gapMs = now.difference(_lastReleaseTime!).inMilliseconds;
    } else if (_recordingStartTime != null && _currentPattern.isEmpty) {
      gapMs = now.difference(_recordingStartTime!).inMilliseconds;
    }
    // Impedisci gap troppo piccoli che si attaccano al segmento precedente
    _currentGaps.add(gapMs < _minTapGapMs ? _minTapGapMs : gapMs.clamp(0, 10000));
    
    // Gestione specifica per piattaforma - AUMENTATA DRASTICAMENTE L'INTENSITÀ
    if (PlatformService.isAndroid) {
      // Android: avvia un keep-alive della vibrazione finché il dito resta giù
      if (_hasAmplitudeControl) {
        Vibration.vibrate(duration: _liveChunkMs, amplitude: intensity);
      } else {
        Vibration.vibrate(duration: _liveChunkMs);
      }
      _vibrationTimer?.cancel();
      _vibrationTimer = Timer.periodic(const Duration(milliseconds: _liveRefreshMs), (_) async {
        if (_isVibrating) {
          if (_hasAmplitudeControl) {
            final a = _lastIntensity.clamp(1, 255);
            Vibration.vibrate(duration: _liveChunkMs, amplitude: a);
          } else {
            Vibration.vibrate(duration: _liveChunkMs);
          }
        }
      });
    } else if (PlatformService.isIOS) {
      // iOS: haptic feedback
      _triggerHapticFeedback(intensity);
      _vibrationTimer?.cancel();
      _vibrationTimer = Timer.periodic(const Duration(milliseconds: 70), (_) {
        if (_isVibrating) {
          _triggerHapticFeedback(_lastIntensity);
        }
      });
    }
  }

  void _updateVibrationIntensity(Offset position) {
    final intensity = _calculateIntensityFromPosition(position);
    _lastIntensity = intensity;

    // Split current segment if intensity changed enough and minimum time elapsed
    if (_segmentStartTime != null) {
      final elapsed = DateTime.now().difference(_segmentStartTime!).inMilliseconds;
      if (elapsed >= _minSegmentMs && (intensity - _segmentCurrentIntensity).abs() >= _intensityChangeThreshold) {
        final segmentDuration = elapsed.clamp(5, 6000);
        setState(() {
          // micro-gap per separare nettamente il cambio intensità
          if (_currentGaps.length == _currentPattern.length) {
            _currentGaps.add(10);
          }
          _currentPattern.add(segmentDuration);
          _currentIntensities.add(_segmentCurrentIntensity);
          _segmentStartTime = DateTime.now();
          _segmentCurrentIntensity = intensity;
        });
      }
    }
    
    // Gestione specifica per piattaforma - AUMENTATA DRASTICAMENTE L'INTENSITÀ
    if (PlatformService.isAndroid) {
      // Android: aggiorna vibrazione in tempo reale con intensità molto più alta
      // Usa una durata più lunga per vibrazioni continue durante il trascinamento
      if (_hasAmplitudeControl) {
        Vibration.vibrate(duration: _liveChunkMs, amplitude: intensity); // rinnova con chunk sovrapposti
      } else {
        // Mantieni vibrazione continua senza duty-cycle per evitare pulsazioni
        Vibration.vibrate(duration: _liveChunkMs);
      }
    } else if (PlatformService.isIOS) {
      // iOS: aggiorna haptic feedback
      _triggerHapticFeedback(intensity);
    }
  }

  void _triggerHapticFeedback(int intensity) {
    if (PlatformService.isIOS) {
      // Converti intensità in tipo di haptic feedback - AUMENTATA LA SENSIBILITÀ
      if (intensity > 180) {
        HapticFeedback.heavyImpact();
        // Aggiungi un secondo feedback per intensità molto alte
        Future.delayed(Duration(milliseconds: 10), () {
          HapticFeedback.heavyImpact();
        });
      } else if (intensity > 120) {
        HapticFeedback.mediumImpact();
        // Aggiungi un secondo feedback per intensità medie
        Future.delayed(Duration(milliseconds: 10), () {
          HapticFeedback.mediumImpact();
        });
      } else if (intensity > 60) {
        HapticFeedback.lightImpact();
      } else {
        HapticFeedback.selectionClick(); // Feedback più sottile per intensità basse
      }
    }
  }

  void _stopInteractiveRecording(Offset? position) {
    setState(() {
      _isVibrating = false;
    });
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
    
    // Chiudi l'ultimo segmento in corso
    if (_segmentStartTime != null) {
      final elapsed = DateTime.now().difference(_segmentStartTime!).inMilliseconds;
      final duration = elapsed.clamp(5, 6000);
      if (duration >= 5) {
        setState(() {
          _currentPattern.add(duration);
          _currentIntensities.add(_segmentCurrentIntensity);
        });
      }
      _segmentStartTime = null;
    }
    
    _vibrationStartTime = null;
    _lastReleaseTime = DateTime.now();
  }

  int _calculateIntensityFromPosition(Offset position) {
    // Ottieni l'altezza del visualizzatore in base alla dimensione dello schermo
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;
    final visualizerHeight = isSmallScreen ? 160.0 : 220.0;
    
    // Normalizza la posizione Y (0 = alto/soft, 1 = basso/hard)
    final normalizedY = position.dy / visualizerHeight;
    
    // Inverti la scala (0 = soft, 1 = hard) - AUMENTATA DRASTICAMENTE LA CURVA DI INTENSITÀ
    final intensity = (1.0 - normalizedY).clamp(0.0, 1.0);
    
    // Converti in valore per Vibration API (1-255) - AUMENTATA DRASTICAMENTE L'INTENSITÀ BASE
    final baseIntensity = (intensity * 255).round();
    
    // Applica una curva molto più aggressiva per intensità più alte
    if (baseIntensity > 128) {
      return (baseIntensity * 1.8).round().clamp(0, 255); // Aumenta dell'80% per intensità alte
    } else if (baseIntensity > 64) {
      return (baseIntensity * 1.4).round().clamp(0, 255); // Aumenta del 40% per intensità medie
    } else {
      return (baseIntensity * 1.2).round().clamp(0, 255); // Aumenta del 20% anche per intensità basse
    }
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
                      onPressed: () => _playPattern(
                        pattern.pattern,
                        // se non ci sono intensità salvate, usa valori alti di default
                        (pattern.intensities != null && pattern.intensities!.isNotEmpty)
                            ? pattern.intensities
                            : List<int>.filled(pattern.pattern.length, 220),
                        pattern.gaps,
                      ),
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

  void _playPattern([List<int>? pattern, List<int>? intensities, List<int>? gaps]) async {
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
    if (patternToPlay.isEmpty) {
      return;
    }

    setState(() {
      _isPlaying = true;
    });

    _animationController.repeat();

    try {
      if (PlatformService.isAndroid) {
        // Android: usa Vibration API con intensità per-segmento se disponibili
        final hasVibrator = await Vibration.hasVibrator() ?? false;
        if (hasVibrator) {
          final hasAmplitude = await Vibration.hasAmplitudeControl() ?? false;

          // Costruisci pattern completo [gap0, on1, gap1, on2, ...]
          final fullPattern = <int>[];
          final fullIntensities = <int>[];
          // delay iniziale/gap0
          fullPattern.add(gapsToPlay.isNotEmpty ? gapsToPlay.first.clamp(0, 10000) : 0);
          fullIntensities.add(0);

          for (int i = 0; i < patternToPlay.length; i++) {
            final rawDuration = patternToPlay[i];
            final onDuration = rawDuration.clamp(5, 6000); // durata precisa
            fullPattern.add(onDuration);

            // ampiezza: usa intensità se disponibile, alza un floor minimo
            int amplitude = (i < intensitiesToPlay.length ? intensitiesToPlay[i] : 220);
            amplitude = amplitude.clamp(1, 255);
            fullIntensities.add(amplitude);

            // gap tra impulsi (come registrato)
            final gap = (i + 1 < gapsToPlay.length) ? gapsToPlay[i + 1].clamp(0, 10000) : 0;
            if (i < patternToPlay.length - 1) {
              fullPattern.add(gap);
              fullIntensities.add(0);
            }
          }

          if (hasAmplitude) {
            await Vibration.vibrate(pattern: fullPattern, intensities: fullIntensities);
          } else {
            // Senza amplitude control: espandi ogni segmento in micro-cicli PWM per emulare l'intensità
            final pwmPattern = <int>[];
            // iniziale
            pwmPattern.add(gapsToPlay.isNotEmpty ? gapsToPlay.first.clamp(0, 10000) : 0);
            for (int i = 0; i < patternToPlay.length; i++) {
              final segMs = patternToPlay[i].clamp(5, 6000);
              final norm = ((i < intensitiesToPlay.length ? intensitiesToPlay[i] : 220) / 255.0).clamp(0.0, 1.0);
              final duty = (_dutyMin + norm * (1.0 - _dutyMin)).clamp(_dutyMin, 1.0);
              final onMs = (_microPeriodMs * duty).round().clamp(_minOnMs, _microPeriodMs);
              final offMs = (_microPeriodMs - onMs).clamp(0, _microPeriodMs);

              int remaining = segMs is int ? segMs : (segMs as num).round();
              while (remaining > 0) {
                final onChunk = remaining >= onMs ? onMs : remaining;
                pwmPattern.add(onChunk);
                remaining -= onChunk;
                if (remaining <= 0) break;
                if (offMs > 0) {
                  final offChunk = remaining >= offMs ? offMs : remaining;
                  pwmPattern.add(offChunk);
                  remaining -= offChunk;
                }
              }
              // gap tra segmenti
              if (i + 1 < gapsToPlay.length) {
                pwmPattern.add(gapsToPlay[i + 1].clamp(0, 10000));
              }
            }
            await Vibration.vibrate(pattern: pwmPattern);
          }
        }
      } else if (PlatformService.isIOS) {
        // iOS: usa haptic feedback per ogni impulso - AUMENTATA MASSIVAMENTE LA RIPRODUZIONE
        for (int i = 0; i < patternToPlay.length; i++) {
          final intensity = i < intensitiesToPlay.length ? intensitiesToPlay[i] : 128;
          
          // Ripeti il feedback per intensità più alte - AUMENTATO DRASTICAMENTE IL RIPETERE
          final repeatCount = intensity > 180 ? 5 : (intensity > 120 ? 3 : (intensity > 60 ? 2 : 1));
          for (int j = 0; j < repeatCount; j++) {
            _triggerHapticFeedback(intensity);
            if (j < repeatCount - 1) {
              await Future.delayed(Duration(milliseconds: 2)); // Pausa molto breve tra ripetizioni
            }
          }
          
          // Attendi la durata dell'impulso
          await Future.delayed(Duration(milliseconds: patternToPlay[i]));
        }
      }
    } catch (e) {
      // Gestione errori silenziosa
    }

    // Calcola durata totale reale usata in playback (inclusi gap)
    int totalMs;
    // Ricostruisci durata totale (Android/iOS): somma gap + on
    totalMs = 0;
    if (gapsToPlay.isNotEmpty) totalMs += gapsToPlay.first.clamp(0, 10000);
    for (int i = 0; i < patternToPlay.length; i++) {
      totalMs += patternToPlay[i].clamp(5, 6000);
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
      intensities: List.from(_currentIntensities),
      gaps: List.from(_currentGaps),
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
      _currentIntensities = pattern.intensities != null && pattern.intensities!.isNotEmpty
          ? List.from(pattern.intensities!)
          : List<int>.filled(pattern.pattern.length, 220);
      _currentGaps = pattern.gaps != null && pattern.gaps!.isNotEmpty
          ? List.from(pattern.gaps!)
          : _synthesizeGaps(_currentPattern.length);
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
                            _currentIntensities = List<int>.filled(values.length, 220);
                            _currentGaps = _synthesizeGaps(values.length);
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

  // Genera gap sintetici se mancanti (0 iniziale + 60ms tra impulsi)
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
