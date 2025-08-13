import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:typed_data';
import '../main.dart';

// Global notification instance
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Background message handler - iOS 18 COMPLIANT
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    // Initialize local notifications for background
    await _initializeLocalNotifications();
    
    final messageType = message.data['type'];
    
    // Handle ZAP notifications - SIMPLE NOTIFICATION FOR iOS
    if (messageType == 'new_zap') {
      // iOS: Show simple notification (no haptics in background)
      // Android: Can trigger vibration in background
      if (Platform.isIOS) {
        await _showZapNotification();
      } else if (Platform.isAndroid) {
        await Future.delayed(Duration(milliseconds: 1000));
        await Vibration.vibrate(duration: 200);
      }
    }
    
    // Handle message notifications - USER-FACING WITH ALERT+SOUND
    if (messageType == 'new_message') {
      final senderName = message.data['senderName'] ?? 'Un amico';
      final conversationId = message.data['conversationId'] ?? '';
      await _showMessageNotification(senderName, conversationId);
    }
    
    // Handle friend request notifications - USER-FACING WITH ALERT+SOUND
    if (messageType == 'friend_request') {
      final senderName = message.data['senderName'] ?? 'Un amico';
      final senderUsername = message.data['senderUsername'] ?? 'amico';
      await _showFriendRequestNotification(senderName, senderUsername);
    }
  } catch (e) {
    // Silent error handling
  }
}

// Show simple ZAP notification (iOS 18 compliant)
Future<void> _showZapNotification() async {
  try {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'zap_channel',
      'ZAP Notifications',
      channelDescription: 'Notifications for ZAPs received',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
      badgeNumber: 1,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      1001, // Unique ID for ZAP notifications
      'Hai ricevuto un nuovo ZAP!',
      'Tocca per vedere chi ti ha inviato un ZAP',
      platformChannelSpecifics,
    );
  } catch (e) {
    // Silent error handling
  }
}

// Initialize local notifications
Future<void> _initializeLocalNotifications() async {
  try {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle local notification tap
        NotificationService().handleLocalNotificationTap(response.payload);
      },
    );
    
    // Android notification channels
    if (Platform.isAndroid) {
      // ZAP channel
      final AndroidNotificationChannel zapChannel = AndroidNotificationChannel(
        'zap_channel',
        'ZAP Notifications',
        description: 'Notifications for ZAPs received',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        showBadge: true,
        enableLights: true,
      );
      
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(zapChannel);
      
      // Chat messages channel
      const AndroidNotificationChannel chatChannel = AndroidNotificationChannel(
        'chat_messages',
        'Chat Messages',
        description: 'Notifications for new messages',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        showBadge: true,
        enableLights: true,
      );
      
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(chatChannel);
      
      // Friend requests channel
      const AndroidNotificationChannel friendRequestChannel = AndroidNotificationChannel(
        'friend_requests',
        'Friend Requests',
        description: 'Notifications for friend requests',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        showBadge: true,
        enableLights: true,
      );
      
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(friendRequestChannel);
    }
  } catch (e) {
    // Silent error handling
  }
}

// Handle ZAP notification in foreground
Future<void> _handleZapNotification(RemoteMessage message) async {
  try {
    // Check if ZAPs are paused
    final zapsPaused = await NotificationService()._isZapsPaused();
    if (zapsPaused) {
      return;
    }
    
    // Trigger haptics/vibration in foreground
    await _triggerZapHaptic();
  } catch (e) {
    // Silent error handling
  }
}

// Trigger ZAP haptic/vibration
Future<void> _triggerZapHaptic() async {
  try {
    if (Platform.isIOS) {
      // iOS: Core Haptics in foreground
      HapticFeedback.heavyImpact();
      Future.delayed(Duration(milliseconds: 150), () {
        HapticFeedback.mediumImpact();
      });
    } else if (Platform.isAndroid) {
      // Android: Vibration with pattern
      final hasVibrator = await Vibration.hasVibrator();
      final hasAmplitudeControl = await Vibration.hasAmplitudeControl();
      
      if (hasVibrator == true) {
        if (hasAmplitudeControl == true) {
          await Vibration.vibrate(
            pattern: [0, 200, 100, 300, 100, 400, 100, 300, 100, 200],
            intensities: [0, 128, 0, 255, 0, 255, 0, 255, 0, 128],
          );
        } else {
          await Vibration.vibrate(
            pattern: [0, 200, 100, 300, 100, 400, 100, 300, 100, 200],
          );
        }
      }
    }
  } catch (e) {
    // Silent error handling
  }
}

// Show message notification
Future<void> _showMessageNotification(String senderName, String conversationId) async {
  try {
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'chat_messages',
      'Chat Messages',
      channelDescription: 'Notifications for new messages',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      color: const Color(0xFF00FF00),
      icon: '@drawable/ic_notification_lightning',
      largeIcon: const DrawableResourceAndroidBitmap('@drawable/ic_notification_lightning'),
    );
    
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
      categoryIdentifier: 'zap_it_messages',
    );
    
    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );
    
    await flutterLocalNotificationsPlugin.show(
      2, // Unique ID for message notifications
      'Nuovo Messaggio 💬',
      '$senderName ti ha inviato un messaggio',
      platformChannelSpecifics,
      payload: 'message:$conversationId',
    );
  } catch (e) {
    // Silent error handling
  }
}

// Show friend request notification
Future<void> _showFriendRequestNotification(String senderName, String senderUsername) async {
  try {
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'friend_requests',
      'Friend Requests',
      channelDescription: 'Notifications for friend requests',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      color: const Color(0xFF00FF00),
      icon: '@drawable/ic_notification_lightning',
      largeIcon: const DrawableResourceAndroidBitmap('@drawable/ic_notification_lightning'),
    );
    
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
      categoryIdentifier: 'zap_it_friend_requests',
    );
    
    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );
    
    await flutterLocalNotificationsPlugin.show(
      3, // Unique ID for friend request notifications
      'Nuova richiesta amicizia ⚡',
      '@$senderUsername vuole essere tuo amico',
      platformChannelSpecifics,
      payload: 'friend_request:$senderUsername',
    );
  } catch (e) {
    // Silent error handling
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Notifica per forzare il refresh delle chat quando arriva un nuovo messaggio
  final ValueNotifier<bool> newMessageArrived = ValueNotifier(false);
  
  /// Callback per la navigazione dalle notifiche
  Function(String conversationId, String senderId, String senderName)? _navigationCallback;
  
  /// Set navigation callback
  void setNavigationCallback(Function(String conversationId, String senderId, String senderName) callback) {
    _navigationCallback = callback;
  }

  /// Check if user has message notifications enabled
  Future<bool> _isMessageNotificationsEnabled() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return true;
      
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        return userData['messageNotifications'] ?? true;
      }
      return true;
    } catch (e) {
      return true;
    }
  }

  /// Check if user has friend request notifications enabled
  Future<bool> _isFriendRequestNotificationsEnabled() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return true;
      
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        return userData['friendRequestNotifications'] ?? true;
      }
      return true;
    } catch (e) {
      return true;
    }
  }

  /// Check if user has ZAPs paused
  Future<bool> _isZapsPaused() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;
      
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        return userData['pauseZaps'] ?? false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Initialize push notifications - iOS 18 COMPLIANT
  Future<void> initializePushNotifications() async {
    try {
      // Initialize local notifications
      await _initializeLocalNotifications();
      
      // Request permissions for iOS 18
      try {
        NotificationSettings settings = await _firebaseMessaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
          criticalAlert: false,
          announcement: false,
        );
        
        // If permission denied, try provisional
        if (settings.authorizationStatus == AuthorizationStatus.denied) {
          await Future.delayed(Duration(seconds: 2));
          settings = await _firebaseMessaging.requestPermission(
            alert: true,
            badge: true,
            sound: true,
            provisional: true,
            criticalAlert: false,
            announcement: false,
          );
        }
      } catch (e) {
        // Silent error handling
      }
      
      // Get FCM token
      String? token;
      try {
        token = await _firebaseMessaging.getToken();
      } catch (e) {
        // Silent error handling
      }
      
      // Save token
      if (token != null) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('fcm_token', token);
          
          if (_auth.currentUser != null) {
            await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
              'fcmToken': token,
              'lastTokenUpdate': FieldValue.serverTimestamp(),
            });
          }
        } catch (e) {
          // Silent error handling
        }
      }
      
      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        if (message.data['type'] == 'new_zap') {
          await _handleZapNotification(message);
        }
        
        if (message.data['type'] == 'new_message') {
          newMessageArrived.value = true;
          await _handleMessageNotification(message);
        }
        
        if (message.data['type'] == 'friend_request') {
          await _handleFriendRequestNotification(message);
        }
      });
      
      // Set background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      
      // Handle app opened from notification
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleNotificationTap(message);
      });
      
      // Handle initial message
      try {
        RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
        if (initialMessage != null) {
          _handleNotificationTap(initialMessage);
        }
      } catch (e) {
        // Silent error handling
      }
      
    } catch (e) {
      // Silent error handling
    }
  }

  // Handle message notification in foreground
  Future<void> _handleMessageNotification(RemoteMessage message) async {
    try {
      final messageNotificationsEnabled = await _isMessageNotificationsEnabled();
      if (!messageNotificationsEnabled) {
        return;
      }
      
      final senderName = message.data['senderName'] ?? 'Un amico';
      final conversationId = message.data['conversationId'] ?? '';
      await _showMessageNotification(senderName, conversationId);
    } catch (e) {
      // Silent error handling
    }
  }

  // Handle friend request notification in foreground
  Future<void> _handleFriendRequestNotification(RemoteMessage message) async {
    try {
      final friendRequestNotificationsEnabled = await _isFriendRequestNotificationsEnabled();
      if (!friendRequestNotificationsEnabled) {
        return;
      }
      
      final senderName = message.data['senderName'] ?? 'Un amico';
      final senderUsername = message.data['senderUsername'] ?? 'amico';
      await _showFriendRequestNotification(senderName, senderUsername);
    } catch (e) {
      // Silent error handling
    }
  }

  // Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    final type = message.data['type'];
    
    if (type == 'new_message') {
      final conversationId = message.data['conversationId'];
      final senderId = message.data['senderId'];
      final senderName = message.data['senderName'] ?? 'Un amico';
      
      if (conversationId != null && senderId != null) {
        _navigateToChat(conversationId, senderId, senderName);
      }
    }
    
    if (type == 'friend_request') {
      _navigateToFriendRequests();
    }
  }

  // Navigate to chat
  void _navigateToChat(String conversationId, String senderId, String senderName) {
    if (_navigationCallback != null) {
      _navigationCallback!(conversationId, senderId, senderName);
      return;
    }
    
    try {
      _storePendingNavigation(conversationId, senderId, senderName);
      
      if (ZapItApp.navigatorKey.currentState != null) {
        ZapItApp.navigatorKey.currentState!.pushNamed(
          '/chat',
          arguments: {
            'conversationId': conversationId,
            'otherUserId': senderId,
            'otherUsername': senderName,
          },
        );
      }
    } catch (e) {
      // Silent error handling
    }
  }
  
  // Store pending navigation data
  void _storePendingNavigation(String conversationId, String senderId, String senderName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_navigation_conversationId', conversationId);
      await prefs.setString('pending_navigation_senderId', senderId);
      await prefs.setString('pending_navigation_senderName', senderName);
    } catch (e) {
      // Silent error handling
    }
  }
  
  // Check and handle pending navigation
  Future<void> checkPendingNavigation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final conversationId = prefs.getString('pending_navigation_conversationId');
      final senderId = prefs.getString('pending_navigation_senderId');
      final senderName = prefs.getString('pending_navigation_senderName');
      
      if (conversationId != null && senderId != null && senderName != null) {
        await prefs.remove('pending_navigation_conversationId');
        await prefs.remove('pending_navigation_senderId');
        await prefs.remove('pending_navigation_senderName');
        
        _navigateToChat(conversationId, senderId, senderName);
      }
    } catch (e) {
      // Silent error handling
    }
  }

  // Navigate to friend requests
  void _navigateToFriendRequests() {
    // To be implemented
  }

  // Handle local notification tap
  void handleLocalNotificationTap(String? payload) {
    if (payload == null) return;
    
    if (payload.startsWith('message:')) {
      final conversationId = payload.substring(8);
      _getConversationDataAndNavigate(conversationId);
    }
    
    if (payload.startsWith('friend_request:')) {
      _navigateToFriendRequests();
    }
  }

  // Get conversation data and navigate
  Future<void> _getConversationDataAndNavigate(String conversationId) async {
    try {
      final conversationDoc = await _firestore.collection('conversations').doc(conversationId).get();
      if (conversationDoc.exists) {
        final data = conversationDoc.data()!;
        final participants = List<String>.from(data['participants']);
        
        final currentUserId = _auth.currentUser?.uid;
        final otherUserId = participants.firstWhere((id) => id != currentUserId);
        
        final userDoc = await _firestore.collection('users').doc(otherUserId).get();
        final senderName = userDoc.exists ? userDoc.data()!['username'] ?? 'Un amico' : 'Un amico';
        
        _navigateToChat(conversationId, otherUserId, senderName);
      }
    } catch (e) {
      // Silent error handling
    }
  }

  // Compatibility methods
  Future<void> initialize() async {
    await initializePushNotifications();
  }

  Stream<int> getUnreadZapCountStream() {
    if (_auth.currentUser == null) return Stream.value(0);
    
    return _firestore
        .collection('zaps')
        .where('receiverId', isEqualTo: _auth.currentUser!.uid)
        .where('status', isEqualTo: 'sent')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.length;
        });
  }

  // Send ZAP notification
  Future<bool> sendZapNotification(String receiverId, String senderName, {
    String? vibrationPattern,
    String? vibrationIntensity,
    List<int>? customVibration,
    String? vibeComposerId,
  }) async {
    try {
      await _firestore.collection('zaps').add({
        'senderId': _auth.currentUser!.uid,
        'receiverId': receiverId,
        'senderName': senderName,
        'status': 'sent',
        'created_at': FieldValue.serverTimestamp(),
        'vibrationPattern': vibrationPattern ?? 'default',
        'vibrationIntensity': vibrationIntensity ?? 'medium',
        'customVibration': customVibration?.join(',') ?? '',
        'vibeComposerId': vibeComposerId,
      });
      
      return true;
    } catch (e) {
      return false;
    }
  }

  // Clear notifications
  Future<void> clearAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  Future<void> clearNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }

  // Legacy methods for compatibility
  Future<void> checkForUnreadZapNotifications() async {
    // Legacy method - no longer needed
  }

  Future<void> cleanupOldNotifications() async {
    // Cleanup method
  }

  Future<void> cleanupAllOldNotifications() async {
    await clearAllNotifications();
  }

  Future<void> stopListening() async {
    // Stop listening method
  }

  Future<void> markAllZapsAsRead() async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return;

      final unreadZaps = await _firestore
          .collection('zaps')
          .where('receiverId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'sent')
          .get();

      for (var doc in unreadZaps.docs) {
        await doc.reference.update({'status': 'read'});
      }
    } catch (e) {
      // Silent error handling
    }
  }

  Future<void> processPendingNotifications() async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return;
      // Process any pending notifications
    } catch (e) {
      // Silent error handling
    }
  }
} 
