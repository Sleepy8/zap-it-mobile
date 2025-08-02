import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Global notification instance
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Background message handler - ONLY ONE HANDLER
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  
  
  
  
  // Initialize local notifications for background
  await _initializeLocalNotifications();
  
  // Handle ZAP notifications
  if (message.data['type'] == 'new_zap') {
    await _handleZapNotification(message);
  }
  
  // Handle message notifications
  if (message.data['type'] == 'new_message') {
    await _handleMessageNotification(message);
  }
}

// Initialize local notifications
Future<void> _initializeLocalNotifications() async {
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
      
    },
  );
  
  // Configurazione canale ZAP INVISIBILE
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
  
  
}

// Handle ZAP notification - INVISIBLE, ONLY VIBRATION
Future<void> _handleZapNotification(RemoteMessage message) async {
  try {
    final senderName = message.data['senderName'] ?? 'Un amico';
    final senderId = message.data['senderId'] ?? '';
    
    // Trigger enhanced vibration ONLY - NO VISIBLE NOTIFICATION
    await _triggerZapVibration();
    
    // RIMOSSO: _showBeautifulZapNotification - NOTIFICA INVISIBILE
    // Gli ZAP sono ora quasi invisibili, solo vibrazione
    
    
  } catch (e) {
    
  }
}

// Handle message notification
Future<void> _handleMessageNotification(RemoteMessage message) async {
  try {
    final senderName = message.data['senderName'] ?? 'Un amico';
    final conversationId = message.data['conversationId'] ?? '';
    
    // Show message notification
    await _showMessageNotification(senderName, conversationId);
    
    
  } catch (e) {
    
  }
}

// ZAP vibration pattern - ONLY VISIBLE EFFECT with compatibility checks
Future<void> _triggerZapVibration() async {
  try {
    // Check vibration support
    final hasVibrator = await Vibration.hasVibrator();
    final hasAmplitudeControl = await Vibration.hasAmplitudeControl();
    final hasCustomVibrationsSupport = await Vibration.hasCustomVibrationsSupport();
    
    
    
    
    
    
    if (hasVibrator == true) {
      // ZAP vibration pattern - unico effetto visibile
      if (hasAmplitudeControl == true) {
        await Vibration.vibrate(
          pattern: [0, 100, 50, 150, 50, 200, 50, 150, 50, 100],
          intensities: [0, 255, 0, 255, 0, 255, 0, 255, 0, 255],
        );
      } else {
        // Fallback for devices without amplitude control
        await Vibration.vibrate(
          pattern: [0, 100, 50, 150, 50, 200, 50, 150, 50, 100],
        );
      }
      
    } else {
      
    }
  } catch (e) {
    
    // Fallback to simple vibration
    try {
      await Vibration.vibrate();
      
    } catch (fallbackError) {
      
    }
  }
}

// NOTA: Funzione rimossa - ZAP ora invisibili, solo vibrazione
// Gli ZAP non mostrano più notifiche visibili per mantenere l'anonimato

// Show message notification
Future<void> _showMessageNotification(String senderName, String conversationId) async {
  final AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'message_channel',
    'Message Notifications',
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

  // Call this in main/init
  Future<void> initializePushNotifications() async {
    try {
      
      
      // Initialize local notifications
      await _initializeLocalNotifications();
      
      // Request permissions
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      
      
      // Get FCM token
      String? token = await _firebaseMessaging.getToken();
      
      
      // Save token locally first (always)
      if (token != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', token);
        
        
        // Save token to Firestore if user is logged in
        if (_auth.currentUser != null) {
          await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
            'fcmToken': token,
            'lastTokenUpdate': FieldValue.serverTimestamp(),
          });
          
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
      });
      
      // Set background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      
      // Handle app opened from notification
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        
        _handleNotificationTap(message);
      });
      
      // Handle initial message
      RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        
        _handleNotificationTap(initialMessage);
      }
      
      
    } catch (e) {
      
    }
  }

  // Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    final type = message.data['type'];
    final payload = message.data;
    
    if (type == 'new_zap') {
      // Navigate to ZAP history or show ZAP animation
      
    } else if (type == 'new_message') {
      // Navigate to conversation
      final conversationId = payload['conversationId'];
      
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
