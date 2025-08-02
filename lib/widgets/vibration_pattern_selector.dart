import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/vibration_pattern_service.dart';

class VibrationPatternSelector extends StatefulWidget {
  final Function(VibrationPattern) onPatternSelected;
  final VibrationPattern? selectedPattern;

  const VibrationPatternSelector({
    Key? key,
    required this.onPatternSelected,
    this.selectedPattern,
  }) : super(key: key);

  @override
  State<VibrationPatternSelector> createState() => _VibrationPatternSelectorState();
}

class _VibrationPatternSelectorState extends State<VibrationPatternSelector> {
  final VibrationPatternService _patternService = VibrationPatternService();
  List<VibrationPattern> _patterns = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPatterns();
  }

  Future<void> _loadPatterns() async {
    try {
      final patterns = await _patternService.getAllPatterns();
      setState(() {
        _patterns = patterns;
        _isLoading = false;
      });
    } catch (e) {
      
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
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
              Icon(
                Icons.music_note_rounded,
                color: AppTheme.limeAccent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Pattern Vibrazione',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/vibe-composer');
                },
                child: Text(
                  'Composer',
                  style: TextStyle(
                    color: AppTheme.limeAccent,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: AppTheme.limeAccent,
              ),
            )
          else
            _buildPatternGrid(),
        ],
      ),
    );
  }

  Widget _buildPatternGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.2,
      ),
      itemCount: _patterns.length,
      itemBuilder: (context, index) {
        final pattern = _patterns[index];
        final isSelected = widget.selectedPattern?.id == pattern.id;
        
        return GestureDetector(
          onTap: () => widget.onPatternSelected(pattern),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected 
                  ? AppTheme.limeAccent.withOpacity(0.2)
                  : AppTheme.background.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected 
                    ? AppTheme.limeAccent 
                    : AppTheme.textSecondary.withOpacity(0.3),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Color(int.parse('0xFF${pattern.color.substring(1)}')).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.music_note_rounded,
                    color: Color(int.parse('0xFF${pattern.color.substring(1)}')),
                    size: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  pattern.name,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${pattern.pattern.length}',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 8,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SelectedPatternDisplay extends StatelessWidget {
  final VibrationPattern? pattern;

  const SelectedPatternDisplay({
    Key? key,
    this.pattern,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (pattern == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.background.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppTheme.textSecondary.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.music_note_outlined,
              color: AppTheme.textSecondary,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              'Nessun pattern',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Color(int.parse('0xFF${pattern!.color.substring(1)}')).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Color(int.parse('0xFF${pattern!.color.substring(1)}')).withOpacity(0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Color(int.parse('0xFF${pattern!.color.substring(1)}')).withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              Icons.music_note_rounded,
              color: Color(int.parse('0xFF${pattern!.color.substring(1)}')),
              size: 12,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            pattern!.name,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
} 
