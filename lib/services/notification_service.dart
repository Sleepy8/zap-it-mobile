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

// Background message handler - UPDATED FOR iOS 18.6
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    // Initialize local notifications for background
    await _initializeLocalNotifications();
    
    final messageType = message.data['type'];
    
    // Handle ZAP notifications - UPDATED FOR iOS 18.6
    if (messageType == 'new_zap') {
      // iOS 18.6: Show notification with haptic feedback
      if (Platform.isIOS) {
        await _showZapNotification();
        // Trigger haptic feedback for iOS 18.6
        await _triggerZapHapticForBackground();
      } else if (Platform.isAndroid) {
        await Future.delayed(Duration(milliseconds: 1000));
        await Vibration.vibrate(duration: 200);
      }
    }
    
    // Handle message notifications - UPDATED FOR iOS 18.6
    if (messageType == 'new_message') {
      final senderName = message.data['senderName'] ?? 'Un amico';
      final conversationId = message.data['conversationId'] ?? '';
      await _showMessageNotification(senderName, conversationId);
    }
    
    // Handle friend request notifications - UPDATED FOR iOS 18.6
    if (messageType == 'friend_request') {
      final senderName = message.data['senderName'] ?? 'Un amico';
      final senderUsername = message.data['senderUsername'] ?? 'amico';
      await _showFriendRequestNotification(senderName, senderUsername);
    }
  } catch (e) {
    // Silent error handling
  }
}

// Trigger ZAP haptic for background - NEW FOR iOS 18.6
Future<void> _triggerZapHapticForBackground() async {
  try {
    if (Platform.isIOS) {
      // iOS 18.6: Use system haptic feedback
      HapticFeedback.heavyImpact();
      await Future.delayed(Duration(milliseconds: 150));
      HapticFeedback.mediumImpact();
    }
  } catch (e) {
    // Silent error handling
  }
}

// Show simple ZAP notification (UPDATED FOR iOS 18.6)
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
      categoryIdentifier: 'zap_it_zaps',
      threadIdentifier: 'zap_notifications',
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

// Initialize local notifications - UPDATED FOR iOS 18.6
Future<void> _initializeLocalNotifications() async {
  try {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      onDidReceiveLocalNotification: (id, title, body, payload) async {
        // Handle local notification
      },
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

// Handle ZAP notification in foreground - UPDATED FOR iOS 18.6
Future<void> _handleZapNotification(RemoteMessage message) async {
  try {
    // Check if ZAPs are paused
    final zapsPaused = await NotificationService()._isZapsPaused();
    if (zapsPaused) {
      return;
    }
    
    // Trigger haptics/vibration in foreground - UPDATED FOR iOS 18.6
    await _triggerZapHaptic();
  } catch (e) {
    // Silent error handling
  }
}

// Trigger ZAP haptic/vibration - UPDATED FOR iOS 18.6
Future<void> _triggerZapHaptic() async {
  try {
    if (Platform.isIOS) {
      // iOS 18.6: Enhanced haptic feedback
      HapticFeedback.heavyImpact();
      await Future.delayed(Duration(milliseconds: 100));
      HapticFeedback.mediumImpact();
      await Future.delayed(Duration(milliseconds: 100));
      HapticFeedback.lightImpact();
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

// Show message notification - UPDATED FOR iOS 18.6
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
      threadIdentifier: 'chat_messages',
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

// Show friend request notification - UPDATED FOR iOS 18.6
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
      threadIdentifier: 'friend_requests',
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

  // Initialize push notifications - UPDATED FOR iOS 18.6
  Future<void> initializePushNotifications() async {
    try {
      // Initialize local notifications
      await _initializeLocalNotifications();
      
      // Request permissions for iOS 18.6
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
          
          // Save to Firestore
          final userId = _auth.currentUser?.uid;
          if (userId != null) {
            await _firestore.collection('users').doc(userId).update({
              'fcmToken': token,
              'lastTokenUpdate': FieldValue.serverTimestamp(),
            });
          }
        } catch (e) {
          // Silent error handling
        }
      }
      
      // Set up foreground message handler - UPDATED FOR iOS 18.6
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        try {
          final messageType = message.data['type'];
          
          if (messageType == 'new_zap') {
            await _handleZapNotification(message);
          } else if (messageType == 'new_message') {
            final senderName = message.data['senderName'] ?? 'Un amico';
            final conversationId = message.data['conversationId'] ?? '';
            final messageNotifications = await _isMessageNotificationsEnabled();
            
            if (messageNotifications) {
              await _showMessageNotification(senderName, conversationId);
            }
            
            // Trigger UI refresh
            newMessageArrived.value = true;
          } else if (messageType == 'friend_request') {
            final senderName = message.data['senderName'] ?? 'Un amico';
            final senderUsername = message.data['senderUsername'] ?? 'amico';
            final friendRequestNotifications = await _isFriendRequestNotificationsEnabled();
            
            if (friendRequestNotifications) {
              await _showFriendRequestNotification(senderName, senderUsername);
            }
          }
        } catch (e) {
          // Silent error handling
        }
      });
      
      // Set up background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      
      // Handle notification taps
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleNotificationTap(message);
      });
      
      // Handle initial notification
      RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }
      
    } catch (e) {
      // Silent error handling
    }
  }

  // Handle notification tap - UPDATED FOR iOS 18.6
  void _handleNotificationTap(RemoteMessage message) {
    try {
      final messageType = message.data['type'];
      
      if (messageType == 'new_message') {
        final conversationId = message.data['conversationId'] ?? '';
        final senderId = message.data['senderId'] ?? '';
        final senderName = message.data['senderName'] ?? '';
        
        if (_navigationCallback != null) {
          _navigationCallback!(conversationId, senderId, senderName);
        }
      }
    } catch (e) {
      // Silent error handling
    }
  }

  // Handle local notification tap - UPDATED FOR iOS 18.6
  void handleLocalNotificationTap(String? payload) {
    try {
      if (payload != null && payload.startsWith('message:')) {
        final conversationId = payload.substring(7);
        if (_navigationCallback != null) {
          _navigationCallback!(conversationId, '', '');
        }
      }
    } catch (e) {
      // Silent error handling
    }
  }

  // Update FCM token - UPDATED FOR iOS 18.6
  Future<void> updateFCMToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        final userId = _auth.currentUser?.uid;
        if (userId != null) {
          await _firestore.collection('users').doc(userId).update({
            'fcmToken': token,
            'lastTokenUpdate': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      // Silent error handling
    }
  }

  // Delete FCM token - UPDATED FOR iOS 18.6
  Future<void> deleteFCMToken() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        await _firestore.collection('users').doc(userId).update({
          'fcmToken': FieldValue.delete(),
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      // Silent error handling
    }
  }
} 
