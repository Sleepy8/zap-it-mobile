import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class VibrationPattern {
  String id;
  String name;
  List<int> pattern;
  // Optional per-segment intensities (0-255). When provided, it should map to the
  // number of ON segments in the pattern if the pattern is a full waveform
  // [delay, on, off, on, ...]. If the pattern contains only ON durations,
  // intensities should be 1:1 with pattern entries.
  List<int>? intensities;
  // Optional per-segment gaps (in ms). Each entry corresponds to the delay
  // BEFORE the matching ON segment at the same index. The first gap is the
  // initial delay from recording start.
  List<int>? gaps;
  String color; // Stored as hex string
  DateTime createdAt;
  bool isDefault;

  VibrationPattern({
    required this.id,
    required this.name,
    required this.pattern,
    this.intensities,
    this.gaps,
    required this.color,
    required this.createdAt,
    this.isDefault = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'pattern': pattern,
      'intensities': intensities,
      'gaps': gaps,
      'color': color,
      'createdAt': createdAt.toIso8601String(),
      'isDefault': isDefault,
    };
  }

  factory VibrationPattern.fromJson(Map<String, dynamic> json) {
    return VibrationPattern(
      id: json['id'],
      name: json['name'],
      pattern: List<int>.from(json['pattern']),
      intensities: json['intensities'] != null
          ? List<int>.from(json['intensities'])
          : null,
      gaps: json['gaps'] != null
          ? List<int>.from(json['gaps'])
          : null,
      color: json['color'],
      createdAt: DateTime.parse(json['createdAt']),
      isDefault: json['isDefault'] ?? false,
    );
  }
}

class VibrationPatternService {
  static const String _patternsKey = 'vibration_patterns';
  static const String _defaultPatternsKey = 'default_vibration_patterns';

  static final List<VibrationPattern> _defaultPatterns = [
    VibrationPattern(
      id: 'heartbeat',
      name: 'Heartbeat',
      pattern: [0, 200, 100, 200, 100, 400],
      color: '#FF4444',
      createdAt: DateTime.now(),
      isDefault: true,
    ),
    VibrationPattern(
      id: 'morse_sos',
      name: 'Morse SOS',
      pattern: [0, 200, 100, 200, 100, 200, 300, 400, 100, 400, 100, 400, 300, 200, 100, 200, 100, 200],
      color: '#FF8800',
      createdAt: DateTime.now(),
      isDefault: true,
    ),
    VibrationPattern(
      id: 'gentle_wave',
      name: 'Gentle Wave',
      pattern: [0, 100, 200, 100, 200, 100, 200, 100, 200, 100, 200],
      color: '#4488FF',
      createdAt: DateTime.now(),
      isDefault: true,
    ),
    VibrationPattern(
      id: 'quick_tap',
      name: 'Quick Tap',
      pattern: [0, 100, 50, 100],
      color: '#44FF44',
      createdAt: DateTime.now(),
      isDefault: true,
    ),
    VibrationPattern(
      id: 'long_vibration',
      name: 'Long Vibration',
      pattern: [0, 1000],
      color: '#FF44FF',
      createdAt: DateTime.now(),
      isDefault: true,
    ),
  ];

  // Get all patterns (default + custom)
  Future<List<VibrationPattern>> getAllPatterns() async {
    final customPatterns = await getCustomPatterns();
    return [..._defaultPatterns, ...customPatterns];
  }

  // Get only custom patterns
  Future<List<VibrationPattern>> getCustomPatterns() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final patternsJson = prefs.getString(_patternsKey);
      
      if (patternsJson != null) {
        final List<dynamic> patternsList = jsonDecode(patternsJson);
        return patternsList.map((json) => VibrationPattern.fromJson(json)).toList();
      }
    } catch (e) {
      // Handle error silently
    }
    
    return [];
  }

  // Get default patterns
  List<VibrationPattern> getDefaultPatterns() {
    return List.from(_defaultPatterns);
  }

  // Save a pattern
  Future<void> savePattern(VibrationPattern pattern) async {
    try {
      final customPatterns = await getCustomPatterns();
      
      // Check if pattern already exists
      final existingIndex = customPatterns.indexWhere((p) => p.id == pattern.id);
      if (existingIndex != -1) {
        customPatterns[existingIndex] = pattern;
      } else {
        customPatterns.add(pattern);
      }
      
      final prefs = await SharedPreferences.getInstance();
      final patternsJson = jsonEncode(customPatterns.map((p) => p.toJson()).toList());
      await prefs.setString(_patternsKey, patternsJson);
    } catch (e) {
      rethrow;
    }
  }

  // Delete a pattern
  Future<void> deletePattern(String patternId) async {
    try {
      final customPatterns = await getCustomPatterns();
      customPatterns.removeWhere((pattern) => pattern.id == patternId);
      
      final prefs = await SharedPreferences.getInstance();
      final patternsJson = jsonEncode(customPatterns.map((p) => p.toJson()).toList());
      await prefs.setString(_patternsKey, patternsJson);
    } catch (e) {
      rethrow;
    }
  }

  // Get pattern by ID
  Future<VibrationPattern?> getPatternById(String patternId) async {
    final allPatterns = await getAllPatterns();
    try {
      return allPatterns.firstWhere((pattern) => pattern.id == patternId);
    } catch (e) {
      return null;
    }
  }

  // Generate unique pattern ID
  String generatePatternId() {
    return DateTime.now().millisecondsSinceEpoch.toString() + '_${DateTime.now().microsecond}';
  }

  // Get random pattern
  Future<VibrationPattern> getRandomPattern() async {
    final allPatterns = await getAllPatterns();
    allPatterns.shuffle();
    return allPatterns.first;
  }

  // Get popular patterns (most used)
  Future<List<VibrationPattern>> getPopularPatterns() async {
    final allPatterns = await getAllPatterns();
    // For now, return default patterns as "popular"
    return allPatterns.where((pattern) => pattern.isDefault).toList();
  }

  // Check if pattern exists
  Future<bool> patternExists(String patternId) async {
    final pattern = await getPatternById(patternId);
    return pattern != null;
  }

  // Update existing pattern
  Future<void> updatePattern(VibrationPattern updatedPattern) async {
    await savePattern(updatedPattern);
  }

  // Duplicate a pattern
  Future<VibrationPattern> duplicatePattern(VibrationPattern originalPattern) async {
    final duplicatedPattern = VibrationPattern(
      id: generatePatternId(),
      name: '${originalPattern.name} (Copy)',
      pattern: List.from(originalPattern.pattern),
      color: originalPattern.color,
      createdAt: DateTime.now(),
      isDefault: false,
    );
    
    await savePattern(duplicatedPattern);
    return duplicatedPattern;
  }

  // Export pattern as JSON string
  String exportPattern(VibrationPattern pattern) {
    return jsonEncode(pattern.toJson());
  }

  // Import pattern from JSON string
  VibrationPattern importPattern(String jsonString) {
    final json = jsonDecode(jsonString);
    return VibrationPattern.fromJson(json);
  }

  // Get pattern statistics
  Future<Map<String, dynamic>> getPatternStats() async {
    final allPatterns = await getAllPatterns();
    final customPatterns = await getCustomPatterns();
    
    return {
      'totalPatterns': allPatterns.length,
      'customPatterns': customPatterns.length,
      'defaultPatterns': _defaultPatterns.length,
      'averagePatternLength': allPatterns.isEmpty 
          ? 0 
          : allPatterns.map((p) => p.pattern.length).reduce((a, b) => a + b) / allPatterns.length,
    };
  }
} 