import 'package:flutter/material.dart';
import '../services/friends_service.dart';
import '../theme.dart';

class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({Key? key}) : super(key: key);

  @override
  State<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen> {
  final _friendsService = FriendsService();
  List<Map<String, dynamic>> _pendingRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPendingRequests();
  }

  void _loadPendingRequests() {
    _friendsService.getPendingRequests().listen((requests) {
      if (mounted) {
        setState(() {
          _pendingRequests = requests;
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _acceptRequest(String friendshipId, String username) async {
    try {
      final success = await _friendsService.acceptFriendRequest(friendshipId);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('@$username è ora tuo amico!'),
            backgroundColor: AppTheme.limeAccent,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Errore nell\'accettazione della richiesta'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      appBar: AppBar(
        title: const Text('Richieste Amicizia'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.limeAccent),
                ),
              )
            : _pendingRequests.isEmpty
                ? _buildEmptyState()
                : _buildRequestsList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
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
                Icons.person_add_outlined,
                size: 60,
                color: AppTheme.limeAccent,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Nessuna richiesta',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Non hai richieste di amicizia in attesa',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingRequests.length,
      itemBuilder: (context, index) {
        final request = _pendingRequests[index];
        return _buildRequestCard(request);
      },
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.limeAccent.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // User avatar
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppTheme.limeAccent,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: request['profileImageUrl'] != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: Image.network(
                          request['profileImageUrl'],
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Icon(
                              Icons.person,
                              size: 30,
                              color: AppTheme.primaryDark,
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.person,
                              size: 30,
                              color: AppTheme.primaryDark,
                            );
                          },
                        ),
                      )
                    : const Icon(
                        Icons.person,
                        size: 30,
                        color: AppTheme.primaryDark,
                      ),
              ),
              const SizedBox(width: 16),
              
              // User info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request['name'] ?? 'Nome non disponibile',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${request['username'] ?? 'username'}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.limeAccent,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Vuole essere tuo amico',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _acceptRequest(
                    request['friendshipId'],
                    request['username'],
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.limeAccent,
                    foregroundColor: AppTheme.primaryDark,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Accetta',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: Implementare rifiuto richiesta
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Funzionalità in sviluppo'),
                        backgroundColor: AppTheme.textSecondary,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: AppTheme.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: AppTheme.textSecondary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Rifiuta',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
} 