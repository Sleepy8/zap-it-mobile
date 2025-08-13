import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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

  // Search users by username (filtered to exclude blocked users and respect privacy settings)
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.isEmpty || query.length < 2) return [];

    try {
      // Convert query to lowercase for case-insensitive search
      final lowerQuery = query.toLowerCase().trim();
      
      // Get all users and filter client-side for better flexibility
      final querySnapshot = await _firestore
          .collection('users')
          .limit(50) // Increased limit to allow for filtering
          .get();

      List<Map<String, dynamic>> results = [];
      
      for (var doc in querySnapshot.docs) {
        final userData = doc.data() as Map<String, dynamic>?;
        if (userData == null) continue; // Skip documents with null data
        
        final username = userData['username']?.toString().toLowerCase() ?? '';
        
        // Check if username contains the query and is not the current user
        if (username.contains(lowerQuery) && doc.id != currentUserId) {
          // Check if user account is active (not deleted)
          final isAccountActive = userData['deleted'] != true;
          
          // Skip deleted accounts
          if (!isAccountActive) continue;
          
          // Check if query is at least 50% of the username length
          final minRequiredLength = (username.length * 0.5).ceil();
          if (lowerQuery.length >= minRequiredLength) {
            results.add({
              'id': doc.id,
              ...userData,
            });
          }
        }
      }

      // Filter out blocked users, users who blocked current user, and users with private profiles
      List<Map<String, dynamic>> filteredResults = [];
      for (var user in results) {
        final isBlocked = await isUserBlocked(user['id']);
        final isBlockedBy = await isBlockedByUser(user['id']);
        final showProfileToEveryone = user['showProfileToEveryone'] ?? true;
        
        // Additional privacy checks
        final allowFriendRequests = user['allowFriendRequests'] ?? true;
        final isAccountSuspended = user['suspended'] ?? false;
        
        if (!isBlocked && 
            !isBlockedBy && 
            showProfileToEveryone && 
            allowFriendRequests && 
            !isAccountSuspended) {
          filteredResults.add(user);
        }
      }

      // Sort results by relevance (exact matches first, then partial matches)
      filteredResults.sort((a, b) {
        final usernameA = (a['username'] ?? '').toString().toLowerCase();
        final usernameB = (b['username'] ?? '').toString().toLowerCase();
        
        // Exact match gets priority
        if (usernameA == lowerQuery && usernameB != lowerQuery) return -1;
        if (usernameB == lowerQuery && usernameA != lowerQuery) return 1;
        
        // Then sort by username length (shorter usernames first)
        if (usernameA.length != usernameB.length) {
          return usernameA.length.compareTo(usernameB.length);
        }
        
        // Finally, alphabetical order
        return usernameA.compareTo(usernameB);
      });

      // Limit to 10 results
      return filteredResults.take(10).toList();
    } catch (e) {
      return [];
    }
  }

  // Send friend request
  Future<Map<String, dynamic>> sendFriendRequest(String friendId) async {
    if (currentUserId == null) return {'success': false, 'error': 'Utente non autenticato'};

    try {
      // Check if target user accepts friend requests
      final targetUserDoc = await _firestore
          .collection('users')
          .doc(friendId)
          .get();
      
      if (!targetUserDoc.exists) {
        return {'success': false, 'error': 'Utente non trovato'};
      }
      
      final targetUserData = targetUserDoc.data() as Map<String, dynamic>;
      final allowFriendRequests = targetUserData['allowFriendRequests'] ?? true;
      
      if (!allowFriendRequests) {
        return {'success': false, 'error': 'Questo utente non accetta richieste di amicizia'};
      }

      // Check if friendship already exists
      final existingDoc = await _firestore
          .collection('friendships')
          .where('userId', isEqualTo: currentUserId)
          .where('friendId', isEqualTo: friendId)
          .get();

      if (existingDoc.docs.isNotEmpty) {
        return {'success': false, 'error': 'Richieste di amicizia già inviata'};
      }

      // Create friend request
      await _firestore.collection('friendships').add({
        'userId': currentUserId,
        'friendId': friendId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return {'success': true, 'error': null};
    } catch (e) {
      return {'success': false, 'error': 'Errore nell\'invio della richiesta'};
    }
  }

  // Accept friend request
  Future<bool> acceptFriendRequest(String friendshipId) async {
    if (currentUserId == null) return false;

    try {
      // Get the friendship document to get the sender's ID
      final friendshipDoc = await _firestore
          .collection('friendships')
          .doc(friendshipId)
          .get();
      
      if (!friendshipDoc.exists) return false;
      
      final friendshipData = friendshipDoc.data()!;
      final senderId = friendshipData['userId'];
      
      // Update the original friendship to accepted
      await _firestore
          .collection('friendships')
          .doc(friendshipId)
          .update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      // Create the reverse friendship (bidirectional)
      await _firestore.collection('friendships').add({
        'userId': currentUserId,
        'friendId': senderId,
        'status': 'accepted',
        'createdAt': FieldValue.serverTimestamp(),
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
      await _firestore
          .collection('friendships')
          .where('userId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'accepted')
          .get();

      
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

  // Check friendship status between current user and another user
  Future<String> getFriendshipStatus(String otherUserId) async {
    if (currentUserId == null) return 'none';

    try {
      // Check if there's a friendship from current user to other user
      final friendshipQuery = await _firestore
          .collection('friendships')
          .where('userId', isEqualTo: currentUserId)
          .where('friendId', isEqualTo: otherUserId)
          .get();

      if (friendshipQuery.docs.isNotEmpty) {
        final status = friendshipQuery.docs.first.data()['status'] as String;
        return status; // 'accepted' or 'pending'
      }

      // Check if there's a friendship from other user to current user
      final reverseFriendshipQuery = await _firestore
          .collection('friendships')
          .where('userId', isEqualTo: otherUserId)
          .where('friendId', isEqualTo: currentUserId)
          .get();

      if (reverseFriendshipQuery.docs.isNotEmpty) {
        final status = reverseFriendshipQuery.docs.first.data()['status'] as String;
        return status; // 'accepted' or 'pending'
      }

      return 'none'; // No friendship exists
    } catch (e) {
      
      return 'none';
    }
  }

  // Block a user
  Future<bool> blockUser(String userIdToBlock) async {
    if (currentUserId == null) return false;

    try {
      // First, remove any existing friendship
      await removeFriendship(userIdToBlock);

      // Check if block already exists
      final existingBlock = await _firestore
          .collection('blocks')
          .where('blockerId', isEqualTo: currentUserId)
          .where('blockedId', isEqualTo: userIdToBlock)
          .get();

      if (existingBlock.docs.isNotEmpty) {
        return true; // Already blocked
      }

      // Create block
      await _firestore.collection('blocks').add({
        'blockerId': currentUserId,
        'blockedId': userIdToBlock,
        'blockedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      
      return false;
    }
  }

  // Unblock a user
  Future<bool> unblockUser(String userIdToUnblock) async {
    if (currentUserId == null) return false;

    try {
      final blockQuery = await _firestore
          .collection('blocks')
          .where('blockerId', isEqualTo: currentUserId)
          .where('blockedId', isEqualTo: userIdToUnblock)
          .get();

      if (blockQuery.docs.isNotEmpty) {
        for (var doc in blockQuery.docs) {
          await doc.reference.delete();
        }
      }

      return true;
    } catch (e) {
      
      return false;
    }
  }

  // Get list of blocked users
  Stream<List<Map<String, dynamic>>> getBlockedUsers() {
    if (currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('blocks')
        .where('blockerId', isEqualTo: currentUserId)
        .snapshots()
        .asyncMap((snapshot) async {
      List<Map<String, dynamic>> blockedUsers = [];
      
      for (var doc in snapshot.docs) {
        final blockedId = doc.data()['blockedId'];
        final userData = await _firestore
            .collection('users')
            .doc(blockedId)
            .get();
        
        if (userData.exists) {
          blockedUsers.add({
            'blockId': doc.id,
            'id': blockedId,
            'blockedAt': doc.data()['blockedAt'],
            ...userData.data() as Map<String, dynamic>,
          });
        }
      }
      
      return blockedUsers;
    });
  }

  // Check if a user is blocked by current user
  Future<bool> isUserBlocked(String userId) async {
    if (currentUserId == null) return false;

    try {
      final blockQuery = await _firestore
          .collection('blocks')
          .where('blockerId', isEqualTo: currentUserId)
          .where('blockedId', isEqualTo: userId)
          .get();

      return blockQuery.docs.isNotEmpty;
    } catch (e) {
      
      return false;
    }
  }

  // Check if current user is blocked by another user
  Future<bool> isBlockedByUser(String userId) async {
    if (currentUserId == null) return false;

    try {
      final blockQuery = await _firestore
          .collection('blocks')
          .where('blockerId', isEqualTo: userId)
          .where('blockedId', isEqualTo: currentUserId)
          .get();

      return blockQuery.docs.isNotEmpty;
    } catch (e) {
      
      return false;
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
          'dailyStreak': userData['dailyStreak'] ?? 0,
          'dailyZaps': userData['dailyZaps'] ?? 0,
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
      // First, try to get the daily streak from user document
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        
        // Check if user has a daily streak field
        if (userData.containsKey('dailyStreak')) {
          return userData['dailyStreak'] ?? 0;
        }
        
        // Check if user has a daily zaps field
        if (userData.containsKey('dailyZaps')) {
          return userData['dailyZaps'] ?? 0;
        }
      }
      
      // Fallback: calculate streak from ZAPs sent in the last 30 days
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

  // Get search suggestions for better user experience
  Future<List<String>> getSearchSuggestions(String query) async {
    if (query.isEmpty || query.length < 2) return [];

    try {
      final lowerQuery = query.toLowerCase().trim();
      
      // Get recent friends for suggestions
      final friends = await getFriendsStream().first;
      List<String> suggestions = [];
      
      for (var friend in friends) {
        final username = friend['username']?.toString().toLowerCase() ?? '';
        if (username.contains(lowerQuery)) {
          suggestions.add(friend['username']);
        }
      }
      
      // Limit suggestions
      return suggestions.take(5).toList();
    } catch (e) {
      return [];
    }
  }

  // Enhanced search with additional filtering options
  Future<List<Map<String, dynamic>>> searchUsersEnhanced(String query, {
    bool includeFriends = true,
  }) async {
    if (query.isEmpty || query.length < 2) return [];

    try {
      final lowerQuery = query.toLowerCase().trim();
      
      // Get all users and filter client-side for better flexibility
      final querySnapshot = await _firestore
          .collection('users')
          .limit(100) // Increased limit for enhanced search
          .get();

      List<Map<String, dynamic>> results = [];
      
      for (var doc in querySnapshot.docs) {
        final userData = doc.data() as Map<String, dynamic>?;
        if (userData == null) continue; // Skip documents with null data
        
        final username = userData['username']?.toString().toLowerCase() ?? '';
        
        // Check if username contains the query and is not the current user
        if (username.contains(lowerQuery) && doc.id != currentUserId) {
          // Check if user account is active (not deleted)
          final isAccountActive = userData['deleted'] != true;
          
          // Skip deleted accounts
          if (!isAccountActive) continue;
          
          // Check if query is at least 50% of the username length
          final minRequiredLength = (username.length * 0.5).ceil();
          if (lowerQuery.length >= minRequiredLength) {
            results.add({
              'id': doc.id,
              ...userData,
            });
          }
        }
      }

      // Filter out blocked users, users who blocked current user, and users with private profiles
      List<Map<String, dynamic>> filteredResults = [];
      for (var user in results) {
        final isBlocked = await isUserBlocked(user['id']);
        final isBlockedBy = await isBlockedByUser(user['id']);
        final showProfileToEveryone = user['showProfileToEveryone'] ?? true;
        
        // Additional privacy checks
        final allowFriendRequests = user['allowFriendRequests'] ?? true;
        final isAccountSuspended = user['suspended'] ?? false;
        
        if (!isBlocked && 
            !isBlockedBy && 
            showProfileToEveryone && 
            allowFriendRequests && 
            !isAccountSuspended) {
          filteredResults.add(user);
        }
      }

      // Sort results by relevance
      filteredResults.sort((a, b) {
        final usernameA = (a['username'] ?? '').toString().toLowerCase();
        final usernameB = (b['username'] ?? '').toString().toLowerCase();
        
        // Exact match gets priority
        if (usernameA == lowerQuery && usernameB != lowerQuery) return -1;
        if (usernameB == lowerQuery && usernameA != lowerQuery) return 1;
        
        // Friends get priority if includeFriends is true
        if (includeFriends) {
          final isFriendA = _isUserInFriendsList(a['id']);
          final isFriendB = _isUserInFriendsList(b['id']);
          if (isFriendA && !isFriendB) return -1;
          if (isFriendB && !isFriendA) return 1;
        }
        
        // Then sort by username length (shorter usernames first)
        if (usernameA.length != usernameB.length) {
          return usernameA.length.compareTo(usernameB.length);
        }
        
        // Finally, alphabetical order
        return usernameA.compareTo(usernameB);
      });

      return filteredResults.take(15).toList();
    } catch (e) {
      // Silent error handling
      return [];
    }
  }

  // Helper method to check if user is in friends list
  bool _isUserInFriendsList(String userId) {
    // This would need to be implemented with a cached friends list
    // For now, return false as a placeholder
    return false;
  }
} 
