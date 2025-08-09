import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

// Global notification instance
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Background message handler - ONLY ONE HANDLER
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    print('🔔 Background message received: ${message.data}');
    
    // Initialize local notifications for background
    await _initializeLocalNotifications();
    
    // Handle ZAP notifications
    if (message.data['type'] == 'new_zap') {
      print('⚡ Handling ZAP notification in background');
      await _handleZapNotification(message);
    }
    
    // Handle message notifications
    if (message.data['type'] == 'new_message') {
      print('💬 Handling message notification in background');
      await _handleMessageNotification(message);
    }
  } catch (e) {
    print('❌ Background message handler error: $e');
  }
}

// Initialize local notifications
Future<void> _initializeLocalNotifications() async {
  try {
    print('📱 Initializing local notifications...');
    
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
        print('🔔 Local notification tapped: ${response.payload}');
        // Handle local notification tap
        NotificationService().handleLocalNotificationTap(response.payload);
      },
    );
    
    print('✅ Local notifications initialized successfully');
    
    // Configurazione canale ZAP INVISIBILE (solo Android)
    if (Platform.isAndroid) {
      print('📱 Creating notification channels for Android...');
      
      const AndroidNotificationChannel zapChannel = AndroidNotificationChannel(
        'zap_vibration',
        'ZAP Vibration',
        description: 'Canale per vibrazioni ZAP invisibili',
        importance: Importance.high,
        playSound: false, // Nessun suono
        enableVibration: true, // Solo vibrazione
        showBadge: false, // Nessun badge
        enableLights: false, // Nessuna luce
      );
      
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(zapChannel);
      
      print('✅ ZAP notification channel created');
      
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
      
      print('✅ Chat messages notification channel created');
    }
  } catch (e) {
    print('❌ Local notifications initialization error: $e');
  }
}

// Handle ZAP notification - INVISIBLE, ONLY VIBRATION
Future<void> _handleZapNotification(RemoteMessage message) async {
  try {
    final senderName = message.data['senderName'] ?? 'Un amico';
    final senderId = message.data['senderId'] ?? '';
    
    print('⚡ Handling ZAP notification from: $senderName');
    
    // Trigger enhanced vibration ONLY - NO VISIBLE NOTIFICATION
    await _triggerZapVibration();
    
    print('✅ ZAP vibration triggered successfully');
    
    // RIMOSSO: _showBeautifulZapNotification - NOTIFICA INVISIBILE
    // Gli ZAP sono ora quasi invisibili, solo vibrazione
    
  } catch (e) {
    print('❌ ZAP notification error: $e');
  }
}

// Handle message notification
Future<void> _handleMessageNotification(RemoteMessage message) async {
  try {
    final senderName = message.data['senderName'] ?? 'Un amico';
    final conversationId = message.data['conversationId'] ?? '';
    
    print('💬 Handling message notification from: $senderName, conversation: $conversationId');
    
    // Show message notification
    await _showMessageNotification(senderName, conversationId);
    
    print('✅ Message notification handled successfully');
    
  } catch (e) {
    print('❌ Message notification error: $e');
  }
}

// ZAP vibration pattern - ONLY VISIBLE EFFECT with compatibility checks
Future<void> _triggerZapVibration() async {
  try {
    print('📳 Checking vibration support...');
    
    // Check vibration support
    final hasVibrator = await Vibration.hasVibrator();
    final hasAmplitudeControl = await Vibration.hasAmplitudeControl();
    final hasCustomVibrationsSupport = await Vibration.hasCustomVibrationsSupport();
    
    print('📳 Vibration support - Has vibrator: $hasVibrator, Amplitude control: $hasAmplitudeControl');
    
    if (hasVibrator == true) {
      // ZAP vibration pattern - unico effetto visibile
      if (hasAmplitudeControl == true) {
        print('📳 Triggering ZAP vibration with amplitude control');
        await Vibration.vibrate(
          pattern: [0, 100, 50, 150, 50, 200, 50, 150, 50, 100],
          intensities: [0, 255, 0, 255, 0, 255, 0, 255, 0, 255],
        );
      } else {
        // Fallback for devices without amplitude control
        print('📳 Triggering ZAP vibration without amplitude control');
        await Vibration.vibrate(
          pattern: [0, 100, 50, 150, 50, 200, 50, 150, 50, 100],
        );
      }
      print('✅ ZAP vibration completed');
    } else {
      print('⚠️ Device does not support vibration');
    }
  } catch (e) {
    print('❌ Vibration error: $e');
    // Fallback to simple vibration
    try {
      print('📳 Trying fallback vibration');
      await Vibration.vibrate();
      print('✅ Fallback vibration completed');
    } catch (fallbackError) {
      print('❌ Fallback vibration error: $fallbackError');
    }
  }
}

// NOTA: Funzione rimossa - ZAP ora invisibili, solo vibrazione
// Gli ZAP non mostrano più notifiche visibili per mantenere l'anonimato

// Show message notification
Future<void> _showMessageNotification(String senderName, String conversationId) async {
  try {
    print('📱 Showing message notification for: $senderName');
    
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'chat_messages',
      'Chat Messages',
      channelDescription: 'Notifications for new messages',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      color: const Color(0xFF2196F3), // Blue color
    );
    
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
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
    
    print('✅ Message notification shown successfully');
  } catch (e) {
    print('❌ Show message notification error: $e');
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

  // Call this in main/init
  Future<void> initializePushNotifications() async {
    try {
      print('🔔 Initializing push notifications...');
      
      // Initialize local notifications
      await _initializeLocalNotifications();
      print('✅ Local notifications initialized');
      
      // Request permissions with better error handling
      try {
        final settings = await _firebaseMessaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        print('🔔 Notification permission status: ${settings.authorizationStatus}');
      } catch (e) {
        print('❌ Permission request error: $e');
      }
      
      // Get FCM token with error handling
      String? token;
      try {
        token = await _firebaseMessaging.getToken();
        print('🔑 FCM Token obtained: ${token != null ? 'Yes' : 'No'}');
        if (token != null) {
          print('🔑 Token: ${token.substring(0, 20)}...');
        }
      } catch (e) {
        print('❌ FCM token error: $e');
      }
      
      // Save token locally first (always)
      if (token != null) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('fcm_token', token);
          
          // Save token to Firestore if user is logged in
          if (_auth.currentUser != null) {
            print('💾 Saving FCM token to Firestore for user: ${_auth.currentUser!.uid}');
            await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
              'fcmToken': token,
              'lastTokenUpdate': FieldValue.serverTimestamp(),
            });
            print('✅ FCM token saved to Firestore successfully');
          } else {
            print('⚠️ User not logged in, token not saved to Firestore');
          }
        } catch (e) {
          print('❌ Token save error: $e');
        }
      } else {
        print('⚠️ No FCM token available to save');
      }
      
      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        print('🔔 Foreground message received: ${message.data}');
        
        if (message.data['type'] == 'new_zap') {
          print('⚡ Handling ZAP notification');
          await _handleZapNotification(message);
        }
        
        if (message.data['type'] == 'new_message') {
          print('💬 Handling message notification');
          newMessageArrived.value = true;
          await _handleMessageNotification(message);
        }
      });
      
      // Set background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      
      // Handle app opened from notification
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('🔔 App opened from notification: ${message.data}');
        _handleNotificationTap(message);
      });
      
      // Handle initial message
      try {
        RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
        if (initialMessage != null) {
          print('🔔 Initial message: ${initialMessage.data}');
          _handleNotificationTap(initialMessage);
        }
      } catch (e) {
        print('❌ Initial message error: $e');
      }
      
      print('✅ Push notifications initialization completed');
      
    } catch (e) {
      print('❌ Push notifications initialization error: $e');
    }
  }

  // Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    final type = message.data['type'];
    final payload = message.data;
    
    print('🔔 Handling notification tap - Type: $type, Payload: $payload');
    
    if (type == 'new_zap') {
      print('⚡ Navigating to ZAP history');
      // Navigate to ZAP history or show ZAP animation
      
    } else if (type == 'new_message') {
      // Navigate to conversation
      final conversationId = payload['conversationId'];
      final senderId = payload['senderId'];
      final senderName = payload['senderName'] ?? 'Un amico';
      
      print('💬 Navigating to conversation: $conversationId from $senderName');
      print('💬 Navigation callback available: ${_navigationCallback != null}');
      
      // Navigate to chat screen
      _navigateToChat(conversationId, senderId, senderName);
    }
  }

  // Navigate to chat screen
  void _navigateToChat(String conversationId, String senderId, String senderName) {
    // Use navigation callback if available
    if (_navigationCallback != null) {
      print('🎯 Calling navigation callback...');
      _navigationCallback!(conversationId, senderId, senderName);
      print('✅ Navigation callback called');
    } else {
      print('❌ Navigation callback not set');
      // Fallback: try to navigate directly (for testing)
      print('🔄 Trying direct navigation as fallback...');
    }
  }

  // Handle local notification tap
  void handleLocalNotificationTap(String? payload) {
    if (payload == null) return;
    
    print('🔔 Handling local notification tap with payload: $payload');
    
    // Parse payload format: "message:conversationId"
    if (payload.startsWith('message:')) {
      final conversationId = payload.substring(8); // Remove "message:" prefix
      print('💬 Local notification tap - conversationId: $conversationId');
      
      // Get conversation data from Firestore to get sender info
      _getConversationDataAndNavigate(conversationId);
    }
  }

  // Get conversation data and navigate
  Future<void> _getConversationDataAndNavigate(String conversationId) async {
    try {
      print('🔍 Getting conversation data for: $conversationId');
      
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
        
        print('💬 Found conversation data - senderId: $otherUserId, senderName: $senderName');
        
        // Navigate to chat
        _navigateToChat(conversationId, otherUserId, senderName);
      } else {
        print('❌ Conversation not found: $conversationId');
      }
    } catch (e) {
      print('❌ Error getting conversation data: $e');
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

  // Test notification - ZAP ora invisibili
  Future<void> testNotification() async {
    // RIMOSSO: _showBeautifulZapNotification - ZAP ora invisibili
    // Test solo vibrazione
    await _triggerZapVibration();
    
  }

  // Legacy methods for compatibility
  Future<void> checkForUnreadZapNotifications() async {
    
  }

  Future<void> debugNotifications() async {
    
  }

  Future<void> cleanupOldNotifications() async {
    
  }

  Future<void> cleanupAllOldNotifications() async {
    await clearAllNotifications();
  }

  Future<void> stopListening() async {
    
  }

  Future<void> processPendingNotifications() async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return;

      final pendingNotifications = await _firestore
          .collection('pending_notifications')
          .where('receiverId', isEqualTo: currentUserId)
          .where('processed', isEqualTo: false)
          .get();

      for (var doc in pendingNotifications.docs) {
        final notification = doc.data();
        await doc.reference.update({'processed': true});

        if (notification['type'] == 'new_message') {
          
        } else if (notification['type'] == 'new_zap') {
          
        }
      }

      
    } catch (e) {
      
    }
  }

  Future<void> checkForPendingNotifications() async {
    await processPendingNotifications();
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
      
    }
  }
} 
