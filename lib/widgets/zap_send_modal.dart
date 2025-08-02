import 'package:flutter/material.dart';
import '../services/friends_service.dart';
import '../theme.dart';
import '../services/notification_service.dart';
import 'dart:async';
import 'zap_success_toast.dart';

class ZapSendModal extends StatefulWidget {
  final FriendsService friendsService;

  const ZapSendModal({
    Key? key,
    required this.friendsService,
  }) : super(key: key);

  @override
  State<ZapSendModal> createState() => _ZapSendModalState();
}

class _ZapSendModalState extends State<ZapSendModal> with TickerProviderStateMixin {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _isLoading = false;
  late AnimationController _animationController;
  late AnimationController _scaleController;
  late Animation<double> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    _scaleController.dispose();
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

  Future<void> _sendZap(String userId, String username) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await NotificationService().sendZapNotification(userId, username);
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        if (success) {
          await showZapSuccessToast(context, message: 'ZAP inviato a @$username! ⚡');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Errore nell\'invio dello ZAP'),
              backgroundColor: AppTheme.errorColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore nell\'invio dello ZAP: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Container(
          color: Colors.black.withOpacity(0.7 * _fadeAnimation.value),
          child: Center(
            child: Transform.translate(
              offset: Offset(0, 50 * _slideAnimation.value),
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  margin: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.surfaceDark,
                        AppTheme.surfaceDark.withOpacity(0.95),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.limeAccent.withOpacity(0.15),
                        blurRadius: 30,
                        spreadRadius: 8,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 0,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle bar
                      Container(
                        margin: const EdgeInsets.only(top: 16),
                        width: 50,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppTheme.textSecondary.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 25),
                      // Header
                      Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          children: [
                            // ZAP Icon with enhanced animation
                            TweenAnimationBuilder<double>(
                              duration: const Duration(milliseconds: 800),
                              tween: Tween(begin: 0.0, end: 1.0),
                              builder: (context, value, child) {
                                return Transform.scale(
                                  scale: 0.8 + (0.2 * value),
                                  child: Container(
                                    width: 70,
                                    height: 70,
                                    decoration: BoxDecoration(
                                      gradient: RadialGradient(
                                        colors: [
                                          AppTheme.limeAccent.withOpacity(0.2),
                                          AppTheme.limeAccent.withOpacity(0.1),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(35),
                                      border: Border.all(
                                        color: AppTheme.limeAccent.withOpacity(0.4),
                                        width: 2.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.limeAccent.withOpacity(0.3),
                                          blurRadius: 15,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.flash_on,
                                      color: AppTheme.limeAccent,
                                      size: 35,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Aggiungi un amico',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),

                      // Enhanced search bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutCubic,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppTheme.primaryDark,
                                AppTheme.primaryDark.withOpacity(0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.limeAccent.withOpacity(0.1),
                                blurRadius: 10,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: _searchUsers,
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 16,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Cerca...',
                              hintStyle: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 16,
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: AppTheme.limeAccent,
                                size: 22,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(18),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Results list
                      Container(
                        constraints: const BoxConstraints(maxHeight: 320),
                        child: _isSearching
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.limeAccent),
                                    strokeWidth: 3,
                                  ),
                                ),
                              )
                            : _searchResults.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      children: [
                                        Container(
                                          width: 80,
                                          height: 80,
                                          decoration: BoxDecoration(
                                            gradient: RadialGradient(
                                              colors: [
                                                AppTheme.limeAccent.withOpacity(0.2),
                                                AppTheme.limeAccent.withOpacity(0.05),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(40),
                                          ),
                                          child: Icon(
                                            Icons.search,
                                            size: 32,
                                            color: AppTheme.limeAccent.withOpacity(0.7),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          _searchController.text.isEmpty
                                              ? 'Cerca un amico per iniziare'
                                              : 'Nessun risultato trovato per "${_searchController.text}"',
                                          style: TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 15,
                                            height: 1.3,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          _searchController.text.isEmpty
                                              ? 'Digita un username per cercare'
                                              : 'Prova con un altro username',
                                          style: TextStyle(
                                            color: AppTheme.textSecondary.withOpacity(0.7),
                                            fontSize: 13,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    padding: const EdgeInsets.symmetric(horizontal: 28),
                                    itemCount: _searchResults.length,
                                    itemBuilder: (context, index) {
                                      final friend = _searchResults[index];
                                      return AnimatedContainer(
                                        duration: Duration(milliseconds: 200 + (index * 50)),
                                        curve: Curves.easeOutCubic,
                                        margin: const EdgeInsets.only(bottom: 10),
                                        child: _buildFriendCard(friend),
                                      );
                                    },
                                  ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFriendCard(Map<String, dynamic> friend) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryDark,
            AppTheme.primaryDark.withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppTheme.limeAccent.withOpacity(0.08),
            blurRadius: 8,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                AppTheme.limeAccent.withOpacity(0.3),
                AppTheme.limeAccent.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Center(
            child: Text(
              (friend['username'] as String).substring(0, 1).toUpperCase(),
              style: TextStyle(
                color: AppTheme.limeAccent,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
        title: Text(
          friend['username'],
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 16,
            letterSpacing: 0.2,
          ),
        ),
        subtitle: Text(
          friend['name'] ?? '',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
            height: 1.2,
          ),
        ),
        trailing: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.limeAccent),
                ),
              )
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.limeAccent,
                      AppTheme.limeAccent.withOpacity(0.9),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.limeAccent.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 0,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.person_add,
                      color: AppTheme.primaryDark,
                      size: 16,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Aggiungi',
                      style: TextStyle(
                        color: AppTheme.primaryDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
        onTap: _isLoading ? null : () => _sendZap(friend['id'], friend['username']),
      ),
    );
  }
} 