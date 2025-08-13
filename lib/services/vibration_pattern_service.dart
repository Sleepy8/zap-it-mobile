import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class VibrationPattern {
  final String id;
  final String name;
  final List<double> pattern; // CORRETTO: double per intensità 0.0-1.0
  final String color;
  final DateTime createdAt;
  final bool isDefault;
  final double duration;

  VibrationPattern({
    required this.id,
    required this.name,
    required this.pattern,
    required this.color,
    required this.createdAt,
    this.isDefault = false,
    double? duration,
  }) : duration = duration ?? _calculateDuration(pattern);

  // Calcola durata pattern (stima)
  static double _calculateDuration(List<double> pattern) {
    if (pattern.isEmpty) return 0.0;
    return pattern.length * 0.1; // 100ms per step
  }

  // Conversione a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'pattern': pattern,
      'color': color,
      'createdAt': createdAt.toIso8601String(),
      'isDefault': isDefault,
      'duration': duration,
    };
  }

  // Conversione da JSON
  factory VibrationPattern.fromJson(Map<String, dynamic> json) {
    return VibrationPattern(
      id: json['id'] as String,
      name: json['name'] as String,
      pattern: (json['pattern'] as List).map((e) => (e as num).toDouble()).toList(),
      color: json['color'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isDefault: json['isDefault'] as bool? ?? false,
      duration: (json['duration'] as num?)?.toDouble(),
    );
  }

  // Copia con modifiche
  VibrationPattern copyWith({
    String? id,
    String? name,
    List<double>? pattern,
    String? color,
    DateTime? createdAt,
    bool? isDefault,
    double? duration,
  }) {
    return VibrationPattern(
      id: id ?? this.id,
      name: name ?? this.name,
      pattern: pattern ?? this.pattern,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      isDefault: isDefault ?? this.isDefault,
      duration: duration ?? this.duration,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VibrationPattern && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class VibrationPatternService {
  static const String _storageKey = 'vibration_patterns_v2';
  static const String _statsKey = 'pattern_stats_v2';

  // Pattern predefiniti con intensità moderne
  static final List<VibrationPattern> _defaultPatterns = [
    VibrationPattern(
      id: 'heartbeat_modern',
      name: 'Heartbeat',
      pattern: [0.0, 0.8, 0.2, 0.9, 0.0, 0.1, 0.0],
      color: '#FF6B6B',
      createdAt: DateTime.now(),
      isDefault: true,
    ),
    VibrationPattern(
      id: 'morse_sos_modern',
      name: 'Morse SOS',
      pattern: [0.0, 0.6, 0.0, 0.6, 0.0, 0.6, 0.0, 0.9, 0.0, 0.9, 0.0, 0.9, 0.0, 0.6, 0.0, 0.6, 0.0, 0.6, 0.0],
      color: '#FFB347',
      createdAt: DateTime.now(),
      isDefault: true,
    ),
    VibrationPattern(
      id: 'gentle_wave_modern',
      name: 'Gentle Wave',
      pattern: [0.1, 0.3, 0.5, 0.7, 0.9, 0.7, 0.5, 0.3, 0.1, 0.0],
      color: '#87CEEB',
      createdAt: DateTime.now(),
      isDefault: true,
    ),
    VibrationPattern(
      id: 'pulse_modern',
      name: 'Pulse',
      pattern: [0.0, 1.0, 0.0, 1.0, 0.0],
      color: '#98FB98',
      createdAt: DateTime.now(),
      isDefault: true,
    ),
    VibrationPattern(
      id: 'cascade_modern',
      name: 'Cascade',
      pattern: [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2, 0.1, 0.0],
      color: '#DDA0DD',
      createdAt: DateTime.now(),
      isDefault: true,
    ),
  ];

  // Cache dei pattern
  List<VibrationPattern>? _cachedPatterns;
  Map<String, dynamic>? _cachedStats;

  // Ottieni tutti i pattern (default + custom)
  Future<List<VibrationPattern>> getAllPatterns() async {
    if (_cachedPatterns != null) return _cachedPatterns!;

    final customPatterns = await getCustomPatterns();
    _cachedPatterns = [..._defaultPatterns, ...customPatterns];
    return _cachedPatterns!;
  }

  // Ottieni solo pattern custom
  Future<List<VibrationPattern>> getCustomPatterns() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final patternsJson = prefs.getString(_storageKey);

      if (patternsJson != null && patternsJson.isNotEmpty) {
        final List<dynamic> patternsList = jsonDecode(patternsJson);
        return patternsList
            .map((json) => VibrationPattern.fromJson(json as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Errore silenzioso, ritorna lista vuota
    }

    return [];
  }

  // Ottieni pattern predefiniti
  List<VibrationPattern> getDefaultPatterns() {
    return List.unmodifiable(_defaultPatterns);
  }

  // Salva un pattern
  Future<void> savePattern(VibrationPattern pattern) async {
    try {
      final customPatterns = await getCustomPatterns();

      // Rimuovi pattern esistente se presente
      customPatterns.removeWhere((p) => p.id == pattern.id);

      // Aggiungi nuovo pattern
      customPatterns.add(pattern);

      // Salva su storage
      final prefs = await SharedPreferences.getInstance();
      final patternsJson = jsonEncode(
        customPatterns.map((p) => p.toJson()).toList(),
      );
      await prefs.setString(_storageKey, patternsJson);

      // Invalida cache
      _cachedPatterns = null;

      // Aggiorna statistiche
      await _updateStats('saved');

    } catch (e) {
      rethrow;
    }
  }

  // Elimina un pattern
  Future<void> deletePattern(String patternId) async {
    try {
      // Non permettere eliminazione di pattern default
      if (_defaultPatterns.any((p) => p.id == patternId)) {
        throw Exception('Cannot delete default patterns');
      }

      final customPatterns = await getCustomPatterns();
      final removedCount = customPatterns.length;
      customPatterns.removeWhere((pattern) => pattern.id == patternId);

      if (customPatterns.length == removedCount) {
        throw Exception('Pattern not found');
      }

      final prefs = await SharedPreferences.getInstance();
      final patternsJson = jsonEncode(
        customPatterns.map((p) => p.toJson()).toList(),
      );
      await prefs.setString(_storageKey, patternsJson);

      // Invalida cache
      _cachedPatterns = null;

      // Aggiorna statistiche
      await _updateStats('deleted');

    } catch (e) {
      rethrow;
    }
  }

  // Trova pattern per ID
  Future<VibrationPattern?> getPatternById(String patternId) async {
    final allPatterns = await getAllPatterns();
    try {
      return allPatterns.firstWhere((pattern) => pattern.id == patternId);
    } catch (e) {
      return null;
    }
  }

  // Genera ID univoco per pattern
  String generatePatternId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    return 'pattern_${"$timestamp"}_$random';
  }

  // Duplica pattern esistente
  Future<VibrationPattern> duplicatePattern(VibrationPattern original) async {
    final duplicated = original.copyWith(
      id: generatePatternId(),
      name: '${"${original.name}"} (Copia)',
      createdAt: DateTime.now(),
      isDefault: false,
    );

    await savePattern(duplicated);
    return duplicated;
  }

  // Ottieni pattern casuali
  Future<List<VibrationPattern>> getRandomPatterns(int count) async {
    final allPatterns = await getAllPatterns();
    final shuffled = [...allPatterns];
    shuffled.shuffle();
    return shuffled.take(count).toList();
  }

  // Ottieni pattern popolari (più usati)
  Future<List<VibrationPattern>> getPopularPatterns() async {
    // Per ora ritorna i pattern predefiniti come "popolari"
    // In futuro si potrebbero tracciare utilizzi reali
    return getDefaultPatterns();
  }

  // Cerca pattern per nome
  Future<List<VibrationPattern>> searchPatterns(String query) async {
    if (query.isEmpty) return getAllPatterns();

    final allPatterns = await getAllPatterns();
    final lowercaseQuery = query.toLowerCase();

    return allPatterns.where((pattern) {
      return pattern.name.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  // Valida pattern
  bool validatePattern(List<double> pattern) {
    if (pattern.isEmpty) return false;
    if (pattern.length > 100) return false; // Limite ragionevole

    // Tutti i valori devono essere tra 0.0 e 1.0
    return pattern.every((intensity) => intensity >= 0.0 && intensity <= 1.0);
  }

  // Ottimizza pattern (rimuove ridondanze)
  List<double> optimizePattern(List<double> pattern) {
    if (pattern.length <= 2) return pattern;

    final optimized = <double>[pattern.first];

    for (int i = 1; i < pattern.length - 1; i++) {
      final current = pattern[i];
      final previous = optimized.last;
      final next = pattern[i + 1];

      // Mantieni solo punti significativi (non lineari)
      if ((current - previous).abs() > 0.05 || (next - current).abs() > 0.05) {
        optimized.add(current);
      }
    }

    optimized.add(pattern.last);
    return optimized;
  }

  // Esporta pattern come JSON
  String exportPattern(VibrationPattern pattern) {
    return jsonEncode(pattern.toJson());
  }

  // Importa pattern da JSON
  VibrationPattern importPattern(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return VibrationPattern.fromJson(json);
  }

  // Esporta tutti i pattern custom
  Future<String> exportAllCustomPatterns() async {
    final customPatterns = await getCustomPatterns();
    return jsonEncode({
      'version': '2.0',
      'exportDate': DateTime.now().toIso8601String(),
      'patterns': customPatterns.map((p) => p.toJson()).toList(),
    });
  }

  // Importa pattern multipli
  Future<int> importPatterns(String jsonString, {bool overwrite = false}) async {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final patterns = (data['patterns'] as List)
          .map((json) => VibrationPattern.fromJson(json as Map<String, dynamic>))
          .toList();

      int importedCount = 0;

      for (final pattern in patterns) {
        final exists = await getPatternById(pattern.id) != null;

        if (!exists || overwrite) {
          await savePattern(pattern);
          importedCount++;
        }
      }

      return importedCount;
    } catch (e) {
      rethrow;
    }
  }

  // Ottieni statistiche pattern
  Future<Map<String, dynamic>> getPatternStats() async {
    if (_cachedStats != null) return _cachedStats!;

    try {
      final prefs = await SharedPreferences.getInstance();
      final statsJson = prefs.getString(_statsKey);

      if (statsJson != null) {
        _cachedStats = jsonDecode(statsJson) as Map<String, dynamic>;
      } else {
        _cachedStats = _createDefaultStats();
      }

      return _cachedStats!;
    } catch (e) {
      return _createDefaultStats();
    }
  }

  // Crea statistiche default
  Map<String, dynamic> _createDefaultStats() {
    return {
      'totalCreated': 0,
      'totalDeleted': 0,
      'totalPlayed': 0,
      'lastActivity': DateTime.now().toIso8601String(),
      'averagePatternLength': 0.0,
    };
  }

  // Aggiorna statistiche
  Future<void> _updateStats(String action) async {
    try {
      final stats = await getPatternStats();
      final allPatterns = await getAllPatterns();

      switch (action) {
        case 'saved':
          stats['totalCreated'] = (stats['totalCreated'] as int? ?? 0) + 1;
          break;
        case 'deleted':
          stats['totalDeleted'] = (stats['totalDeleted'] as int? ?? 0) + 1;
          break;
        case 'played':
          stats['totalPlayed'] = (stats['totalPlayed'] as int? ?? 0) + 1;
          break;
      }

      stats['lastActivity'] = DateTime.now().toIso8601String();

      // Calcola lunghezza media pattern
      if (allPatterns.isNotEmpty) {
        final avgLength = allPatterns
            .map((p) => p.pattern.length)
            .reduce((a, b) => a + b) / allPatterns.length;
        stats['averagePatternLength'] = avgLength;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_statsKey, jsonEncode(stats));

      _cachedStats = stats;
    } catch (e) {
      // Errore silenzioso per le statistiche
    }
  }

  // Registra utilizzo pattern
  Future<void> recordPatternUsage(String patternId) async {
    await _updateStats('played');
  }

  // Pulisci cache
  void clearCache() {
    _cachedPatterns = null;
    _cachedStats = null;
  }


  Future<void> resetAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
      await prefs.remove(_statsKey);
      clearCache();
    } catch (e) {
      rethrow;
    }
  }
}
