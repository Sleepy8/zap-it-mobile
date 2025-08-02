import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme.dart';

class ProfilePicture extends StatelessWidget {
  final String userId;
  final double size;
  final bool showBorder;
  final Color? borderColor;

  const ProfilePicture({
    Key? key,
    required this.userId,
    this.size = 40,
    this.showBorder = true,
    this.borderColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.exists) {
          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final profileImageUrl = userData['profileImageUrl'] as String?;
          final username = userData['username'] as String? ?? 'U';

          if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: showBorder
                    ? Border.all(
                        color: borderColor ?? AppTheme.limeAccent.withOpacity(0.6),
                        width: 2,
                      )
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(size / 2),
                child: Image.network(
                  profileImageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        color: AppTheme.limeAccent.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.limeAccent),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return _buildFallbackAvatar(username);
                  },
                ),
              ),
            );
          }
        }

        // Fallback to avatar with initials
        final fallbackUsername = snapshot.hasData && snapshot.data!.exists
            ? (snapshot.data!.data() as Map<String, dynamic>)['username'] as String? ?? 'U'
            : 'U';
        
        return _buildFallbackAvatar(fallbackUsername);
      },
    );
  }

  Widget _buildFallbackAvatar(String username) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.limeAccent.withOpacity(0.2),
        shape: BoxShape.circle,
        border: showBorder
            ? Border.all(
                color: borderColor ?? AppTheme.limeAccent.withOpacity(0.6),
                width: 2,
              )
            : null,
      ),
      child: Center(
        child: Text(
          username.substring(0, 1).toUpperCase(),
          style: TextStyle(
            color: AppTheme.limeAccent,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.4,
          ),
        ),
      ),
    );
  }
} 