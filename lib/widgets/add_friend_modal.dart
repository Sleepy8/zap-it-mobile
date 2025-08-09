import 'package:flutter/material.dart';
import '../services/friends_service.dart';
import '../theme.dart';

class AddFriendModal extends StatefulWidget {
  final FriendsService friendsService;

  const AddFriendModal({
    Key? key,
    required this.friendsService,
  }) : super(key: key);

  @override
  State<AddFriendModal> createState() => _AddFriendModalState();
}

class _AddFriendModalState extends State<AddFriendModal> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await widget.friendsService.searchUsers(query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  Future<void> _sendFriendRequest(String userId, String username) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await widget.friendsService.sendFriendRequest(userId);
      if (success) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Richiesta inviata a @$username!'),
              backgroundColor: AppTheme.limeAccent,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Errore nell\'invio della richiesta'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Text(
                  'Aggiungi Amico',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                color: AppTheme.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Search field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.primaryDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.limeAccent.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.search,
                  color: AppTheme.limeAccent,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'Cerca per @username...',
                      hintStyle: TextStyle(color: AppTheme.textSecondary),
                      border: InputBorder.none,
                    ),
                    onChanged: (value) {
                      if (value.length >= 2) {
                        _searchUsers(value);
                      } else {
                        setState(() {
                          _searchResults = [];
                        });
                      }
                    },
                  ),
                ),
                if (_isSearching)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.limeAccent),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Search results
          if (_searchResults.isNotEmpty) ...[
            Text(
              'Risultati (${_searchResults.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.limeAccent,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final user = _searchResults[index];
                  return _buildUserCard(user);
                },
              ),
            ),
          ] else if (_searchController.text.isNotEmpty && !_isSearching) ...[
            Container(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.search_off,
                    size: 48,
                    color: AppTheme.textSecondary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nessun utente trovato',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Prova con un username diverso',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.person_search,
                    size: 48,
                    color: AppTheme.limeAccent.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Cerca utenti',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Inizia a digitare un username per cercare utenti',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 24),
          
          // Close button
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Chiudi',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.limeAccent.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // User avatar
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppTheme.limeAccent,
              borderRadius: BorderRadius.circular(25),
            ),
            child: const Icon(
              Icons.person,
              size: 25,
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
                  user['name'] ?? 'Nome non disponibile',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '@${user['username'] ?? 'username'}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.limeAccent,
                  ),
                ),
              ],
            ),
          ),
          
          // Add friend button
          SizedBox(
            width: 70,
            height: 36,
            child: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () => _sendFriendRequest(user['id'], user['username']),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.limeAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryDark),
                      ),
                    )
                  : const Text(
                      'ADD',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: AppTheme.primaryDark,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
} 