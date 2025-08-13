import 'package:flutter/material.dart';
import '../services/friends_service.dart';
import '../theme.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({Key? key}) : super(key: key);

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final _friendsService = FriendsService();
  List<Map<String, dynamic>> _leaderboard = [];
  bool _isLoading = true;
  String _selectedFilter = 'zaps_sent'; // 'zaps_sent', 'zaps_received', 'streak'

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final leaderboard = await _friendsService.getLeaderboard(filter: _selectedFilter);
      
      setState(() {
        _leaderboard = leaderboard;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore nel caricamento della leaderboard: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  String _getFilterTitle() {
    switch (_selectedFilter) {
      case 'zaps_sent':
        return 'ZAP Inviati';
      case 'zaps_received':
        return 'ZAP Ricevuti';
      case 'streak':
        return 'Streak Infuocati';
      default:
        return 'ZAP Inviati';
    }
  }

  String _getFilterDescription() {
    switch (_selectedFilter) {
      case 'zaps_sent':
        return 'Chi ha inviato più ZAP';
      case 'zaps_received':
        return 'Chi ha ricevuto più ZAP';
      case 'streak':
        return 'Chi ha la streak più lunga';
      default:
        return 'Chi ha inviato più ZAP';
    }
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber; // Oro
      case 2:
        return Colors.grey[400]!; // Argento
      case 3:
        return Colors.brown[300]!; // Bronzo
      case 4:
        return Colors.purple[400]!; // Viola
      case 5:
        return Colors.blue[400]!; // Blu
      case 6:
        return Colors.teal[400]!; // Verde acqua
      case 7:
        return Colors.indigo[400]!; // Indaco
      case 8:
        return Colors.deepOrange[400]!; // Arancione scuro
      case 9:
        return Colors.pink[400]!; // Rosa
      case 10:
        return Colors.cyan[400]!; // Ciano
      default:
        return Colors.grey[600]!; // Grigio scuro per gli altri
    }
  }

  Widget _buildRankBadge(int rank) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: _getRankColor(rank),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _getRankColor(rank).withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Text(
          '$rank',
          style: TextStyle(
            color: rank <= 3 ? AppTheme.primaryDark : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildStreakIndicator(int streak) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        streak > 5 ? 5 : streak,
        (index) => Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: AppTheme.limeAccent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.limeAccent.withOpacity(0.5),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      appBar: AppBar(
        title: const Text('🏆 Leaderboard'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLeaderboard,
            tooltip: 'Aggiorna',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Section
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    _getFilterTitle(),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppTheme.limeAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getFilterDescription(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Filter Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildFilterButton('zaps_sent', 'ZAP Inviati', Icons.send),
                      _buildFilterButton('zaps_received', 'ZAP Ricevuti', Icons.inbox),
                      _buildFilterButton('streak', 'Streak', Icons.local_fire_department),
                    ],
                  ),
                ],
              ),
            ),
            // Leaderboard List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.limeAccent),
                      ),
                    )
                  : _leaderboard.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: AppTheme.limeAccent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(60),
                                  border: Border.all(
                                    color: AppTheme.limeAccent.withOpacity(0.3),
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.emoji_events,
                                  size: 60,
                                  color: AppTheme.limeAccent,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Nessun dato disponibile',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Inizia a inviare ZAP per apparire qui!',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _leaderboard.length,
                          itemBuilder: (context, index) {
                            final user = _leaderboard[index];
                            final rank = index + 1;
                            final isCurrentUser = user['isCurrentUser'] ?? false;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: isCurrentUser 
                                    ? AppTheme.limeAccent.withOpacity(0.1)
                                    : AppTheme.surfaceDark,
                                borderRadius: BorderRadius.circular(16),
                                border: isCurrentUser
                                    ? Border.all(color: AppTheme.limeAccent, width: 2)
                                    : null,
                              ),
                              child: ListTile(
                                leading: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildRankBadge(rank),
                                    const SizedBox(width: 12),
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: AppTheme.limeAccent.withOpacity(0.2),
                                      child: user['profileImageUrl'] != null
                                          ? ClipRRect(
                                              borderRadius: BorderRadius.circular(24),
                                              child: Image.network(
                                                user['profileImageUrl'],
                                                width: 48,
                                                height: 48,
                                                fit: BoxFit.cover,
                                                loadingBuilder: (context, child, loadingProgress) {
                                                  if (loadingProgress == null) return child;
                                                  return Container(
                                                    width: 48,
                                                    height: 48,
                                                    decoration: BoxDecoration(
                                                      color: AppTheme.limeAccent.withOpacity(0.2),
                                                      borderRadius: BorderRadius.circular(24),
                                                    ),
                                                    child: Text(
                                                      (user['username'] as String).substring(0, 1).toUpperCase(),
                                                      style: TextStyle(
                                                        color: AppTheme.limeAccent,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 18,
                                                      ),
                                                    ),
                                                  );
                                                },
                                                errorBuilder: (context, error, stackTrace) {
                                                  return Text(
                                                    (user['username'] as String).substring(0, 1).toUpperCase(),
                                                    style: TextStyle(
                                                      color: AppTheme.limeAccent,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 18,
                                                    ),
                                                  );
                                                },
                                              ),
                                            )
                                          : Text(
                                              (user['username'] as String).substring(0, 1).toUpperCase(),
                                              style: TextStyle(
                                                color: AppTheme.limeAccent,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                                title: Row(
                                  children: [
                                    Text(
                                      user['username'] as String,
                                      style: TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    if (isCurrentUser) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.limeAccent,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Text(
                                          'TU',
                                          style: TextStyle(
                                            color: AppTheme.primaryDark,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    if (_selectedFilter == 'streak' && user['streak'] > 0) ...[
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.local_fire_department,
                                            color: Colors.orange,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${user['streak']} giorni consecutivi',
                                            style: TextStyle(
                                              color: Colors.orange,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                    ],
                                    Text(
                                      _getFilterDescription(),
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _selectedFilter == 'streak' 
                                          ? '${user['streak']} 🔥'
                                          : '${user[_selectedFilter]}',
                                      style: TextStyle(
                                        color: _selectedFilter == 'streak' ? Colors.orange : AppTheme.limeAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    if (_selectedFilter != 'streak')
                                      Text(
                                        _selectedFilter == 'zaps_sent' ? 'ZAP' : 'Ricevuti',
                                        style: TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 10,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButton(String filter, String label, IconData icon) {
    final isSelected = _selectedFilter == filter;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filter;
        });
        _loadLeaderboard();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.limeAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.limeAccent : AppTheme.limeAccent.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppTheme.primaryDark : AppTheme.limeAccent,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.primaryDark : AppTheme.limeAccent,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 