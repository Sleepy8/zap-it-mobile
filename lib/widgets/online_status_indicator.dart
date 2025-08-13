import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/online_status_service.dart';
import '../theme.dart';

class OnlineStatusIndicator extends StatelessWidget {
  final String userId;
  final double size;
  final bool showLastSeen;

  const OnlineStatusIndicator({
    Key? key,
    required this.userId,
    this.size = 12,
    this.showLastSeen = true,
  }) : super(key: key);

  String _getLastSeenText(DateTime lastSeen) {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);
    
    if (difference.inMinutes < 1) {
      return 'ora';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m fa';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h fa';
    } else {
      return '${difference.inDays}g fa';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox(
            width: size,
            height: size,
            child: const CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.limeAccent),
            ),
          );
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        if (userData == null) return const SizedBox.shrink();

        final showOnlineStatus = userData['showOnlineStatus'] ?? true;
        final showLastSeen = userData['showLastSeen'] ?? true;
        
        if (!showOnlineStatus && !showLastSeen) {
          return const SizedBox.shrink();
        }

        final isOnline = userData['isOnline'] ?? false;
        final lastSeen = userData['lastSeen'] as Timestamp?;

        if (isOnline && showOnlineStatus) {
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppTheme.limeAccent,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.primaryDark,
                width: 2,
              ),
            ),
          );
        } else if (lastSeen != null && showLastSeen) {
          return Tooltip(
            message: 'Ultimo accesso: ${_getLastSeenText(lastSeen.toDate())}',
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: AppTheme.textSecondary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.primaryDark,
                  width: 2,
                ),
              ),
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}
