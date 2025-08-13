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

// Background message handler - ENHANCED FOR PHYSICAL DEVICES
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    // Initialize local notifications for background
    await _initializeLocalNotifications();
    
    // Handle ZAP notifications
    if (message.data['type'] == 'new_zap') {
      // Force vibration even in background
      await _handleZapNotification(message);
      
      // Additional vibration for physical devices in background
      if (Platform.isAndroid) {
        await Future.delayed(Duration(milliseconds: 1000));
        await Vibration.vibrate(duration: 200);
      } else if (Platform.isIOS) {
              // Haptic feedback for iOS - FIXED FOR iOS
      Future.delayed(Duration(milliseconds: 1000));
      HapticFeedback.heavyImpact();
      // Add a second haptic for emphasis
      Future.delayed(Duration(milliseconds: 200));
      HapticFeedback.mediumImpact();
      }
    }
    
    // Handle message notifications - CREATE LOCAL NOTIFICATION
    if (message.data['type'] == 'new_message') {
      // Create local notification for messages
      final senderName = message.data['senderName'] ?? 'Un amico';
      final conversationId = message.data['conversationId'] ?? '';
      await _showMessageNotification(senderName, conversationId);
      
      // Also trigger vibration for feedback
      try {
        if (Platform.isAndroid) {
          await Vibration.vibrate(duration: 200);
        } else if (Platform.isIOS) {
          HapticFeedback.lightImpact();
        }
      } catch (e) {
        // Silent error handling
      }
    }
    
    // Handle friend request notifications - CREATE LOCAL NOTIFICATION
    if (message.data['type'] == 'friend_request') {
      // Create local notification for friend requests
      final senderName = message.data['senderName'] ?? 'Un amico';
      final senderUsername = message.data['senderUsername'] ?? 'amico';
      await _showFriendRequestNotification(senderName, senderUsername);
      
      // Also trigger vibration for feedback
      try {
        if (Platform.isAndroid) {
          await Vibration.vibrate(duration: 200);
        } else if (Platform.isIOS) {
          HapticFeedback.lightImpact();
        }
      } catch (e) {
        // Silent error handling
      }
    }
  } catch (e) {
    // Last resort vibration in background
    try {
      await Vibration.vibrate(duration: 500);
    } catch (vibrationError) {
      // Silent error handling
    }
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
    
    // Configurazione canale ZAP INVISIBILE (solo Android)
    if (Platform.isAndroid) {
      final AndroidNotificationChannel zapChannel = AndroidNotificationChannel(
        'zap_vibration',
        'ZAP Vibration',
        description: 'Canale per vibrazioni ZAP invisibili',
        importance: Importance.max, // Massima importanza per dispositivi fisici
        playSound: false, // Nessun suono
        enableVibration: true, // Solo vibrazione
        showBadge: false, // Nessun badge
        enableLights: false, // Nessuna luce
        vibrationPattern: Int64List.fromList([0, 200, 100, 300, 100, 400, 100, 300, 100, 200]), // Pattern predefinito
      );
      
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(zapChannel);
      
      // Configurazione canale MESSAGGI CHAT (solo Android)
      const AndroidNotificationChannel chatChannel = AndroidNotificationChannel(
        'chat_messages',
        'Chat Messages',
        description: 'Notifiche per nuovi messaggi chat',
        importance: Importance.high,
        playSound: true, // Suono abilitato
        enableVibration: true, // Vibrazione abilitata
        showBadge: true, // Badge abilitato
        enableLights: true, // Luci abilitate
      );
      
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(chatChannel);
      
      // Configurazione canale RICHIESTE AMICIZIA (solo Android)
      const AndroidNotificationChannel friendRequestChannel = AndroidNotificationChannel(
        'friend_requests',
        'Friend Requests',
        description: 'Notifiche per richieste di amicizia',
        importance: Importance.high,
        playSound: true, // Suono abilitato
        enableVibration: true, // Vibrazione abilitata
        showBadge: true, // Badge abilitato
        enableLights: true, // Luci abilitate
      );
      
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(friendRequestChannel);
    }
  } catch (e) {
    // Silent error handling
  }
}

// Handle ZAP notification - INVISIBLE, ONLY VIBRATION
Future<void> _handleZapNotification(RemoteMessage message) async {
  try {
    // Check if ZAPs are paused
    final zapsPaused = await NotificationService()._isZapsPaused();
    if (zapsPaused) {
      return; // Don't trigger vibration if ZAPs are paused
    }
    
    // Trigger vibration immediately
    await _triggerZapVibration();
    
    // For iOS, also trigger haptic feedback as backup
    if (Platform.isIOS) {
      await _triggerHapticFeedback();
    }
  } catch (e) {
    // Silent error handling
  }
}

// Handle message notification
Future<void> _handleMessageNotification(RemoteMessage message) async {
  try {
    // Check if message notifications are enabled
    final messageNotificationsEnabled = await NotificationService()._isMessageNotificationsEnabled();
    if (!messageNotificationsEnabled) {
      return; // Don't show notification if disabled
    }
    
    final senderName = message.data['senderName'] ?? 'Un amico';
    final conversationId = message.data['conversationId'] ?? '';
    
    // Show message notification
    await _showMessageNotification(senderName, conversationId);
    
  } catch (e) {
    // Silent error handling
  }
}

// Handle friend request notification
Future<void> _handleFriendRequestNotification(RemoteMessage message) async {
  try {
    // Check if friend request notifications are enabled
    final friendRequestNotificationsEnabled = await NotificationService()._isFriendRequestNotificationsEnabled();
    if (!friendRequestNotificationsEnabled) {
      return; // Don't show notification if disabled
    }
    
    final senderName = message.data['senderName'] ?? 'Un amico';
    final senderUsername = message.data['senderUsername'] ?? 'amico';
    
    // Show friend request notification
    await _showFriendRequestNotification(senderName, senderUsername);
    
  } catch (e) {
    // Silent error handling
  }
}

// ZAP vibration pattern - ENHANCED FOR PHYSICAL DEVICES
Future<void> _triggerZapVibration() async {
  try {
    // Check vibration support
    final hasVibrator = await Vibration.hasVibrator();
    final hasAmplitudeControl = await Vibration.hasAmplitudeControl();
    
    if (Platform.isAndroid && hasVibrator == true) {
      // Enhanced vibration pattern for physical devices
      if (hasAmplitudeControl == true) {
        // Pattern avanzato con controllo ampiezza
        await Vibration.vibrate(
          pattern: [0, 200, 100, 300, 100, 400, 100, 300, 100, 200],
          intensities: [0, 128, 0, 255, 0, 255, 0, 255, 0, 128],
        );
      } else {
        // Pattern semplice per dispositivi senza controllo ampiezza
        await Vibration.vibrate(
          pattern: [0, 200, 100, 300, 100, 400, 100, 300, 100, 200],
        );
      }
    } else if (Platform.isIOS) {
      // iOS: haptic feedback semplice e diretto
      HapticFeedback.heavyImpact();
      // Aggiungi un secondo feedback dopo un breve delay
      Future.delayed(Duration(milliseconds: 150), () {
        HapticFeedback.mediumImpact();
      });
    } else {
      // Fallback per dispositivi senza vibrazione
      await _triggerHapticFeedback();
    }
  } catch (e) {
    // Last resort - simple vibration
    try {
      if (Platform.isAndroid) {
        await Vibration.vibrate();
      } else if (Platform.isIOS) {
        await _triggerHapticFeedback();
      }
    } catch (finalError) {
      // Silent error handling
    }
  }
}

// Haptic feedback for iOS - FIXED FOR iOS
Future<void> _triggerHapticFeedback() async {
  try {
    if (Platform.isIOS) {
      // Trigger haptic feedback with proper timing for iOS
      HapticFeedback.heavyImpact();
      
      // Wait and trigger again for emphasis
      Future.delayed(Duration(milliseconds: 200));
      HapticFeedback.mediumImpact();
      
      // Add a third haptic for ZAP effect
      Future.delayed(Duration(milliseconds: 150));
      HapticFeedback.lightImpact();
    } else if (Platform.isAndroid) {
      // Android fallback
      await Vibration.vibrate(duration: 200);
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
      color: const Color(0xFF00FF00), // Lime color
      icon: '@drawable/ic_notification_lightning',
      largeIcon: const DrawableResourceAndroidBitmap('@drawable/ic_notification_lightning'),
    );
    
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default', // Usa il suono di default per uniformità con Android
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
      color: const Color(0xFF00FF00), // Lime color (Zap theme)
      icon: '@drawable/ic_notification_lightning',
      largeIcon: const DrawableResourceAndroidBitmap('@drawable/ic_notification_lightning'),
    );
    
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default', // Usa il suono di default per uniformità con Android
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
      if (userId == null) return true; // Default to enabled if not logged in
      
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        return userData['messageNotifications'] ?? true;
      }
      return true; // Default to enabled
    } catch (e) {
      return true; // Default to enabled on error
    }
  }

  /// Check if user has friend request notifications enabled
  Future<bool> _isFriendRequestNotificationsEnabled() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return true; // Default to enabled if not logged in
      
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        return userData['friendRequestNotifications'] ?? true;
      }
      return true; // Default to enabled
    } catch (e) {
      return true; // Default to enabled on error
    }
  }

  /// Check if user has ZAPs paused
  Future<bool> _isZapsPaused() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false; // Default to not paused if not logged in
      
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        return userData['pauseZaps'] ?? false;
      }
      return false; // Default to not paused
    } catch (e) {
      return false; // Default to not paused on error
    }
  }

  // Call this in main/init
  Future<void> initializePushNotifications() async {
    try {
      // Initialize local notifications
      await _initializeLocalNotifications();
      
      // Request permissions with better error handling for iOS 18
      try {
        NotificationSettings settings = await _firebaseMessaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
          criticalAlert: false, // iOS 18 specific
          announcement: false, // iOS 18 specific
        );
        
        // Notification permission status logged
        
        // If permission denied, try to request again
        if (settings.authorizationStatus == AuthorizationStatus.denied) {
          // Wait a bit and try again
          await Future.delayed(Duration(seconds: 2));
          settings = await _firebaseMessaging.requestPermission(
            alert: true,
            badge: true,
            sound: true,
            provisional: true, // Try provisional permission
            criticalAlert: false,
            announcement: false,
          );
        }
      } catch (e) {
        // Error requesting notification permissions
      }
      
      // Get FCM token
      String? token;
      try {
        token = await _firebaseMessaging.getToken();
        // FCM Token obtained
      } catch (e) {
        // Error getting FCM token
      }
      
      // Save token locally first (always)
      if (token != null) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('fcm_token', token);
          
          // Save token to Firestore if user is logged in
          if (_auth.currentUser != null) {
            await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
              'fcmToken': token,
              'lastTokenUpdate': FieldValue.serverTimestamp(),
            });
            // FCM token saved to Firestore
          }
        } catch (e) {
          // Error saving FCM token
        }
      }
      
      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        // Foreground message received
        
        if (message.data['type'] == 'new_zap') {
          await _handleZapNotification(message);
        }
        
        if (message.data['type'] == 'new_message') {
          newMessageArrived.value = true;
          // Show local notification only when app is truly in foreground
          // This prevents duplicates when app is in background
          await _handleMessageNotification(message);
        }
        
        if (message.data['type'] == 'friend_request') {
          // Show local notification only when app is truly in foreground
          // This prevents duplicates when app is in background
          await _handleFriendRequestNotification(message);
        }
      });
      
      // Set background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      
      // Handle app opened from notification
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        // App opened from notification
        _handleNotificationTap(message);
      });
      
      // Handle initial message
      try {
        RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
        if (initialMessage != null) {
          // Initial message found
          _handleNotificationTap(initialMessage);
        }
      } catch (e) {
        // Error getting initial message
      }
      
    } catch (e) {
      // Error initializing push notifications
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
    // Try using navigation callback first
    if (_navigationCallback != null) {
      _navigationCallback!(conversationId, senderId, senderName);
      return;
    }
    
    // Fallback: try direct navigation if callback is not available
    try {
      // Store navigation data for when app opens
      _storePendingNavigation(conversationId, senderId, senderName);
      
      // Try to navigate directly if navigator is available
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

        
        // Clear stored data
        await prefs.remove('pending_navigation_conversationId');
        await prefs.remove('pending_navigation_senderId');
        await prefs.remove('pending_navigation_senderName');
        
        // Navigate
        _navigateToChat(conversationId, senderId, senderName);
      }
    } catch (e) {
      // Silent error handling
    }
  }

  // Navigate to friend requests
  void _navigateToFriendRequests() {
    // This will be implemented when friend requests screen is ready
  }

  // Handle local notification tap
  void handleLocalNotificationTap(String? payload) {
    if (payload == null) return;
    

    
    // Parse payload format: "message:conversationId"
    if (payload.startsWith('message:')) {
      final conversationId = payload.substring(8); // Remove "message:" prefix
      
      // Get conversation data from Firestore to get sender info
      _getConversationDataAndNavigate(conversationId);
    }
    
    // Parse payload format: "friend_request:username"
    if (payload.startsWith('friend_request:')) {
      // Navigate to friend requests screen
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
        
        // Get the other user ID (not current user)
        final currentUserId = _auth.currentUser?.uid;
        final otherUserId = participants.firstWhere((id) => id != currentUserId);
        
        // Get other user data
        final userDoc = await _firestore.collection('users').doc(otherUserId).get();
        final senderName = userDoc.exists ? userDoc.data()!['username'] ?? 'Un amico' : 'Un amico';
        
        // Navigate to chat
        _navigateToChat(conversationId, otherUserId, senderName);
      }
    } catch (e) {
      // Silent error handling
    }
  }

  // Metodi per compatibilità con il codice esistente
  Future<void> initialize() async {
    await initializePushNotifications();
  }

  Stream<int> getUnreadZapCountStream() {
    if (_auth.currentUser == null) return Stream.value(0);
    
    return _firestore
        .collection('zaps')
        .where('receiverId', isEqualTo: _auth.currentUser!.uid)
        .where('status', isEqualTo: 'sent') // 'sent' = non letto, 'read' = letto
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.length;
        });
  }

  // Send ZAP notification - NO LOCAL NOTIFICATION WHEN SENDING
  Future<bool> sendZapNotification(String receiverId, String senderName, {
    String? vibrationPattern,
    String? vibrationIntensity,
    List<int>? customVibration,
    String? vibeComposerId,
  }) async {
    try {
      // Invia il ZAP tramite Firestore, la Cloud Function si occuperà della notifica
      await _firestore.collection('zaps').add({
        'senderId': _auth.currentUser!.uid,
        'receiverId': receiverId,
        'senderName': senderName,
        'status': 'sent',
        'created_at': FieldValue.serverTimestamp(),
        // Parametri per vibrazione personalizzata (per il futuro vibe composer)
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

  // Clear all notifications
  Future<void> clearAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  // Clear specific notification
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
