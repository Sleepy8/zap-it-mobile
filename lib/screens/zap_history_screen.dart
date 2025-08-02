import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme.dart';
import 'dart:async';

class ZapHistoryScreen extends StatefulWidget {
  const ZapHistoryScreen({Key? key}) : super(key: key);

  @override
  State<ZapHistoryScreen> createState() => _ZapHistoryScreenState();
}

class _ZapHistoryScreenState extends State<ZapHistoryScreen> with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    // Non marcare automaticamente tutti i ZAP come letti
    // I ZAP verranno marcati come letti solo quando l'utente li tocca
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Non marcare automaticamente tutti i ZAP come letti
    // I ZAP verranno marcati come letti solo quando l'utente li tocca
  }

  @override
  void dispose() {
    // Marca tutti i ZAP come letti quando si esce dalla schermata
    _markAllZapsAsRead();
    super.dispose();
  }

  Future<void> _markAllZapsAsRead() async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return;

      // Ottieni tutti i ZAP non letti dell'utente
      final unreadZaps = await _firestore
          .collection('zaps')
          .where('receiverId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'sent')
          .get();

      if (unreadZaps.docs.isEmpty) return;

      // Usa un batch per aggiornare tutti i ZAP contemporaneamente
      final batch = _firestore.batch();
      
      for (var doc in unreadZaps.docs) {
        batch.update(doc.reference, {'status': 'read'});
      }

      // Esegui il batch in una singola operazione
      await batch.commit();

      
    } catch (e) {
      
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      appBar: AppBar(
        title: const Text('Storico ZAP'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('zaps')
              .where('receiverId', isEqualTo: _auth.currentUser?.uid)
              .orderBy('created_at', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.limeAccent),
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Errore nel caricamento: ${snapshot.error}',
                  style: TextStyle(color: AppTheme.errorColor),
                ),
              );
            }

            final notifications = snapshot.data?.docs ?? [];

            if (notifications.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.flash_on,
                      size: 64,
                      color: AppTheme.limeAccent.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Nessun ZAP ricevuto',
                      style: TextStyle(
                        fontSize: 18,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Gli ZAP ricevuti appariranno qui',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                return _buildZapCardItem(context, index, notifications);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildZapCardItem(BuildContext context, int index, List<QueryDocumentSnapshot> notifications) {
    final zap = notifications[index].data() as Map<String, dynamic>;
    final senderId = zap['senderId'] as String;
    final createdAt = zap['created_at'] as Timestamp?;
    final status = zap['status'] as String? ?? 'sent';

    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('users').doc(senderId).get(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingZapCard();
        }

        final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
        final senderName = userData?['name'] ?? 'Utente Sconosciuto';
        final senderUsername = userData?['username'] ?? 'unknown';

        return AnimatedContainer(
          duration: Duration(milliseconds: 300 + (index * 50)),
          curve: Curves.easeOutCubic,
          margin: EdgeInsets.only(
            bottom: 12,
            left: index * 2.0,
            right: index * 2.0,
          ),
          child: _buildZapCard(
            senderName: senderName,
            senderUsername: senderUsername,
            timestamp: createdAt,
            isRead: status == 'read', // Corretto: 'read' = letto, 'sent' = non letto
            profileImageUrl: userData?['profileImageUrl'],
            zapId: notifications[index].id,
          ),
        );
      },
    );
  }

  Widget _buildLoadingZapCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.limeAccent.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.limeAccent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.limeAccent),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 120,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 80,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZapCard({
    required String senderName,
    required String senderUsername,
    required Timestamp? timestamp,
    required bool isRead,
    String? profileImageUrl,
    required String zapId,
  }) {
    return GestureDetector(
      onTap: () {
        // Mark this specific ZAP as read when user taps on it
        if (!isRead) {
          _markZapAsRead(zapId);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRead 
                ? AppTheme.textSecondary.withOpacity(0.1)
                : AppTheme.limeAccent.withOpacity(0.4),
            width: isRead ? 1 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isRead 
                  ? Colors.transparent
                  : AppTheme.limeAccent.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Profile Picture with Animation
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.elasticOut,
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: isRead 
                      ? AppTheme.textSecondary.withOpacity(0.2)
                      : AppTheme.limeAccent.withOpacity(0.6),
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: profileImageUrl != null
                    ? Image.network(
                        profileImageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: AppTheme.limeAccent.withOpacity(0.2),
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.limeAccent),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: AppTheme.limeAccent,
                            child: const Icon(
                              Icons.person,
                              color: AppTheme.primaryDark,
                              size: 24,
                            ),
                          );
                        },
                      )
                    : Container(
                        color: AppTheme.limeAccent,
                        child: const Icon(
                          Icons.person,
                          color: AppTheme.primaryDark,
                          size: 24,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 16),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          senderName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isRead ? AppTheme.textSecondary : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      if (!isRead)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppTheme.limeAccent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.limeAccent.withOpacity(0.4),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '@$senderUsername',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.flash_on,
                        size: 14,
                        color: AppTheme.limeAccent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'ti ha zappato alle ore ${_formatTime(timestamp)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return 'ora sconosciuta';

    final time = timestamp.toDate();
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _getTimeAgo(Timestamp? timestamp) {
    if (timestamp == null) return 'Ora sconosciuta';

    final now = DateTime.now();
    final time = timestamp.toDate();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${difference.inDays} giorni fa';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ore fa';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minuti fa';
    } else {
      return 'Ora';
    }
  }

  Future<void> _markZapAsRead(String zapId) async {
    try {
      await _firestore
          .collection('zaps')
          .doc(zapId)
          .update({'status': 'read'});
      
    } catch (e) {
      
    }
  }
} 
