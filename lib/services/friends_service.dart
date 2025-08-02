import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';

class FriendsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Get friends list
  Stream<List<Map<String, dynamic>>> getFriendsStream() {
    if (currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('friendships')
        .where('userId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .asyncMap((snapshot) async {
      List<Map<String, dynamic>> friends = [];
      
      
      
      
      
      for (var doc in snapshot.docs) {
        final friendId = doc.data()['friendId'];
        
        
        final friendData = await _firestore
            .collection('users')
            .doc(friendId)
            .get();
        
        if (friendData.exists) {
          friends.add({
            'id': friendId,
            ...friendData.data() as Map<String, dynamic>,
          });
          
        } else {
          
        }
      }
      
      
      
      
      return friends;
    });
  }

  // Search users by username
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.isEmpty) return [];

    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: query)
          .where('username', isLessThan: query + '\uf8ff')
          .limit(10)
          .get();

      return querySnapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .where((user) => user['id'] != currentUserId)
          .toList();
    } catch (e) {
      
      return [];
    }
  }

  // Send friend request
  Future<bool> sendFriendRequest(String friendId) async {
    if (currentUserId == null) return false;

    try {
      // Check if friendship already exists
      final existingDoc = await _firestore
          .collection('friendships')
          .where('userId', isEqualTo: currentUserId)
          .where('friendId', isEqualTo: friendId)
          .get();

      if (existingDoc.docs.isNotEmpty) {
        return false; // Friendship already exists
      }

      // Create friend request
      await _firestore.collection('friendships').add({
        'userId': currentUserId,
        'friendId': friendId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      
      return false;
    }
  }

  // Accept friend request
  Future<bool> acceptFriendRequest(String friendshipId) async {
    if (currentUserId == null) return false;

    try {
      await _firestore
          .collection('friendships')
          .doc(friendshipId)
          .update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      
      return false;
    }
  }

  // Reject friend request
  Future<bool> rejectFriendRequest(String friendshipId) async {
    if (currentUserId == null) return false;

    try {
      await _firestore
          .collection('friendships')
          .doc(friendshipId)
          .delete();

      return true;
    } catch (e) {
      
      return false;
    }
  }

  // Remove friendship (unfriend)
  Future<bool> removeFriendship(String friendId) async {
    if (currentUserId == null) return false;

    try {
      
      
      

      // Find and delete the friendship from current user to friend
      final friendshipQuery = await _firestore
          .collection('friendships')
          .where('userId', isEqualTo: currentUserId)
          .where('friendId', isEqualTo: friendId)
          .where('status', isEqualTo: 'accepted')
          .get();

      

      if (friendshipQuery.docs.isNotEmpty) {
        for (var doc in friendshipQuery.docs) {
          
          await doc.reference.delete();
          
        }
      } else {
        
      }

      // Find and delete the reverse friendship from friend to current user
      final reverseFriendshipQuery = await _firestore
          .collection('friendships')
          .where('userId', isEqualTo: friendId)
          .where('friendId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'accepted')
          .get();

      

      if (reverseFriendshipQuery.docs.isNotEmpty) {
        for (var doc in reverseFriendshipQuery.docs) {
          
          await doc.reference.delete();
          
        }
      } else {
        
      }

      // Verify deletion by checking remaining friendships
      final remainingFriendships = await _firestore
          .collection('friendships')
          .where('userId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'accepted')
          .get();

      
      for (var doc in remainingFriendships.docs) {
        
      }

      
      return true;
    } catch (e) {
      
      return false;
    }
  }

  // Get pending friend requests
  Stream<List<Map<String, dynamic>>> getPendingRequests() {
    if (currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('friendships')
        .where('friendId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .asyncMap((snapshot) async {
      List<Map<String, dynamic>> requests = [];
      
      for (var doc in snapshot.docs) {
        final userId = doc.data()['userId'];
        final userData = await _firestore
            .collection('users')
            .doc(userId)
            .get();
        
        if (userData.exists) {
          requests.add({
            'friendshipId': doc.id,
            'id': userId,
            ...userData.data() as Map<String, dynamic>,
          });
        }
      }
      
      return requests;
    });
  }

  // Get user stats
  Future<Map<String, dynamic>> getUserStats(String userId) async {
    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) return {};

      final userData = userDoc.data() as Map<String, dynamic>;
      
      // Get friends count
      final friendsCount = await _firestore
          .collection('friendships')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'accepted')
          .count()
          .get();

      return {
        'zapsSent': userData['zapsSent'] ?? 0,
        'zapsReceived': userData['zapsReceived'] ?? 0,
        'friendsCount': friendsCount.count,
      };
    } catch (e) {
      
      return {};
    }
  }

  // Get leaderboard
  Future<List<Map<String, dynamic>>> getLeaderboard({String filter = 'zaps_sent'}) async {
    try {
      // Get all users with their stats
      final usersSnapshot = await _firestore
          .collection('users')
          .get();

      List<Map<String, dynamic>> leaderboard = [];

      for (var doc in usersSnapshot.docs) {
        final userData = doc.data() as Map<String, dynamic>;
        final userId = doc.id;
        
        // Calculate streak (consecutive days with ZAPs)
        int streak = 0;
        if (filter == 'streak') {
          streak = await _calculateStreak(userId);
        }

        leaderboard.add({
          'id': userId,
          'username': userData['username'] ?? 'Unknown',
          'profileImageUrl': userData['profileImageUrl'],
          'zaps_sent': userData['zapsSent'] ?? 0,
          'zaps_received': userData['zapsReceived'] ?? 0,
          'streak': streak,
          'isCurrentUser': userId == currentUserId,
        });
      }

      // Sort by selected filter
      leaderboard.sort((a, b) {
        int aValue = a[filter] ?? 0;
        int bValue = b[filter] ?? 0;
        return bValue.compareTo(aValue); // Descending order
      });

      // Return top 50 users
      return leaderboard.take(50).toList();
    } catch (e) {
      
      return [];
    }
  }

  // Calculate user streak (consecutive days with ZAPs)
  Future<int> _calculateStreak(String userId) async {
    try {
      // Get all ZAPs sent by user in the last 30 days
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      
      final zapsSnapshot = await _firestore
          .collection('zaps')
          .where('senderId', isEqualTo: userId)
          .where('created_at', isGreaterThan: Timestamp.fromDate(thirtyDaysAgo))
          .orderBy('created_at', descending: true)
          .get();

      if (zapsSnapshot.docs.isEmpty) return 0;

      // Group ZAPs by date
      Map<String, int> zapsByDate = {};
      for (var doc in zapsSnapshot.docs) {
        final timestamp = doc.data()['created_at'] as Timestamp;
        final date = DateTime(timestamp.toDate().year, timestamp.toDate().month, timestamp.toDate().day);
        final dateKey = date.toIso8601String().split('T')[0];
        zapsByDate[dateKey] = (zapsByDate[dateKey] ?? 0) + 1;
      }

      // Calculate consecutive days
      final sortedDates = zapsByDate.keys.toList()..sort();
      int currentStreak = 0;
      int maxStreak = 0;
      DateTime? lastDate;

      for (String dateKey in sortedDates) {
        final date = DateTime.parse(dateKey);
        
        if (lastDate == null) {
          currentStreak = 1;
        } else {
          final daysDiff = date.difference(lastDate).inDays;
          if (daysDiff == 1) {
            currentStreak++;
          } else {
            currentStreak = 1;
          }
        }
        
        maxStreak = currentStreak > maxStreak ? currentStreak : maxStreak;
        lastDate = date;
      }

      return maxStreak;
    } catch (e) {
      
      return 0;
    }
  }
} 
