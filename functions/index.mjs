import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { onDocumentDeleted } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { getAuth } from "firebase-admin/auth";
// Use default credentials provided by Cloud Functions runtime (recommended)
initializeApp();
const db = getFirestore();
const messaging = getMessaging();
const auth = getAuth();

// Elimina account Firebase Auth quando viene eliminato il documento utente
export const deleteUserAccount = onDocumentDeleted(
  "users/{userId}",
  async (event) => {
    try {
      const userId = event.params.userId;
      console.log('🗑️ Eliminazione account per utente:', userId);
      
      // Elimina l'account Firebase Auth
      await auth.deleteUser(userId);
      console.log('✅ Account Firebase Auth eliminato per:', userId);
      
      // Elimina tutte le amicizie dell'utente
      const friendships = await db
        .collection("friendships")
        .where("userId", "==", userId)
        .get();
      
      const friendFriendships = await db
        .collection("friendships")
        .where("friendId", "==", userId)
        .get();
      
      const batch = db.batch();
      friendships.docs.forEach(doc => {
        batch.delete(doc.ref);
      });
      friendFriendships.docs.forEach(doc => {
        batch.delete(doc.ref);
      });
      
      await batch.commit();
      console.log(`✅ Eliminate ${friendships.docs.length + friendFriendships.docs.length} amicizie per:`, userId);
      
      // Elimina tutte le conversazioni dell'utente
      const conversations = await db
        .collection("conversations")
        .where("participants", "array-contains", userId)
        .get();
      
      const conversationBatch = db.batch();
      conversations.docs.forEach(doc => {
        conversationBatch.delete(doc.ref);
      });
      
      await conversationBatch.commit();
      console.log(`✅ Eliminate ${conversations.docs.length} conversazioni per:`, userId);
      
      // Elimina tutti i ZAP dell'utente
      const sentZaps = await db
        .collection("zaps")
        .where("senderId", "==", userId)
        .get();
      
      const receivedZaps = await db
        .collection("zaps")
        .where("receiverId", "==", userId)
        .get();
      
      const zapBatch = db.batch();
      sentZaps.docs.forEach(doc => {
        zapBatch.delete(doc.ref);
      });
      receivedZaps.docs.forEach(doc => {
        zapBatch.delete(doc.ref);
      });
      
      await zapBatch.commit();
      console.log(`✅ Eliminati ${sentZaps.docs.length + receivedZaps.docs.length} ZAP per:`, userId);
      
      return { success: true, userId: userId };
    } catch (error) {
      console.error('❌ Errore eliminazione account:', error);
      return { success: false, error: error.message };
    }
  }
);

// Notifica messaggi chat - UPDATED FOR iOS 18.6
export const sendMessageNotification = onDocumentCreated(
  "conversations/{conversationId}/messages/{messageId}",
  async (event) => {
    try {
      const messageData = event.data.data();
      const senderId = messageData.senderId;
      const receiverId = messageData.receiverId;
      const conversationId = event.params.conversationId;
      const message = messageData;

      // Ottieni i dati del mittente
      const senderDoc = await db.collection("users").doc(senderId).get();
      const senderData = senderDoc.exists ? senderDoc.data() : {};
      const senderName = senderData.username || "Un amico";

      // Ottieni il token FCM del destinatario e le impostazioni notifiche
      const receiverDoc = await db.collection("users").doc(receiverId).get();
      const receiverData = receiverDoc.exists ? receiverDoc.data() : {};
      const fcmToken = receiverData.fcmToken;
      const messageNotifications = receiverData.messageNotifications !== false; // Default to true
      
      if (!fcmToken) {
        console.log('❌ Token FCM non trovato per:', receiverId);
        return;
      }
      
      // Controlla se le notifiche messaggi sono abilitate
      if (!messageNotifications) {
        console.log('🔕 Message notifications disabled for user:', receiverId);
        return;
      }
      
      console.log('📱 FCM Token found for receiver:', fcmToken.substring(0, 20) + '...');
      
      // Per tutti i messaggi, ma con testo generico per quelli crittografati
      let messageText;
      if (message.isEncrypted) {
        messageText = "Nuovo messaggio"; // Testo generico per messaggi crittografati
      } else {
        messageText = message.text || "Nuovo messaggio";
      }
      
      const payload = {
        notification: {
          title: "Zap It - $senderName",
          body: messageText,
        },
        data: {
          type: "new_message",
          senderId: senderId,
          conversationId: conversationId,
          messageId: event.data.id,
          senderName: senderName,
          timestamp: Date.now().toString(),
        },
        android: {
          priority: "high",
          notification: {
            channelId: "chat_messages",
            priority: "high",
            defaultSound: true,
            defaultVibrateTimings: true,
            vibrateTimingsMillis: [0, 200, 100, 200],
            icon: "@drawable/ic_notification_lightning",
            color: "#00FF00",
            clickAction: "FLUTTER_NOTIFICATION_CLICK",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
              alert: {
                title: "Zap It - $senderName",
                body: messageText,
              },
              "content-available": 1,
              "mutable-content": 1,
              category: "zap_it_messages",
              threadId: "chat_messages",
            },
            data: {
              type: "new_message",
              senderId: senderId,
              conversationId: conversationId,
              messageId: event.data.id,
              senderName: senderName,
              timestamp: Date.now().toString(),
            },
          },
          headers: {
            "apns-priority": "10",
            "apns-push-type": "alert",
          },
        },
        token: fcmToken,
      };

      const response = await messaging.send(payload);
      console.log('✅ Message notification sent successfully:', response);
    } catch (error) {
      console.error('❌ Error sending message notification:', error);
    }
  }
);

// Notifica ZAP - UPDATED FOR iOS 18.6
export const sendZapNotification = onDocumentCreated(
  "zaps/{zapId}",
  async (event) => {
    try {
      const zapData = event.data.data();
      const senderId = zapData.senderId;
      const receiverId = zapData.receiverId;
      const zap = zapData;

      // Ottieni i dati del mittente
      const senderDoc = await db.collection("users").doc(senderId).get();
      const senderData = senderDoc.exists ? senderDoc.data() : {};
      const senderName = senderData.username || "Un amico";

      // Ottieni il token FCM del destinatario e le impostazioni
      const receiverDoc = await db.collection("users").doc(receiverId).get();
      const receiverData = receiverDoc.exists ? receiverDoc.data() : {};
      const fcmToken = receiverData.fcmToken;
      const pauseZaps = receiverData.pauseZaps || false;

      if (!fcmToken) {
        console.log('Token FCM non trovato per:', receiverId);
        return;
      }
      
      // Controlla se i ZAP sono in pausa
      if (pauseZaps) {
        console.log('⏸️ ZAPs paused for user:', receiverId);
        return;
      }
      
      // Configurazione vibrazione personalizzata - UPDATED FOR iOS 18.6
      const vibrationPattern = zap.vibrationPattern || "default";
      const vibrationIntensity = zap.vibrationIntensity || "medium";
      const customVibration = zap.customVibration || "";
      const vibeComposerId = zap.vibeComposerId || "";
      
      // Pattern di vibrazione per ZAP - UPDATED FOR iOS 18.6
      let vibrateTimings = [0, 150, 100, 200, 100, 300, 100, 150];
      switch (vibrationPattern) {
        case "intense":
          vibrateTimings = [0, 200, 100, 200, 100, 400, 100, 200];
          break;
        case "gentle":
          vibrateTimings = [0, 50, 25, 50, 25, 100, 25, 50];
          break;
        case "custom":
          if (customVibration) {
            vibrateTimings = customVibration.split(',').map(Number);
          }
          break;
        default:
          break;
      }
      
      switch (vibrationIntensity) {
        case "high":
          vibrateTimings = vibrateTimings.map(t => Math.round(t * 1.5));
          break;
        case "low":
          vibrateTimings = vibrateTimings.map(t => Math.round(t * 0.7));
          break;
        default:
          break;
      }

      const payload = {
        // NOTIFICA QUASI INVISIBILE - SOLO VIBRAZIONE - UPDATED FOR iOS 18.6
        data: {
          type: "new_zap",
          senderId: senderId,
          zapId: event.data.id,
          senderName: senderName,
          vibrationPattern: vibrationPattern,
          vibrationIntensity: vibrationIntensity,
          customVibration: customVibration,
          vibeComposerId: vibeComposerId,
          timestamp: Date.now().toString(),
        },
        android: {
          priority: "high",
          notification: {
            channelId: "zap_vibration",
            priority: "high",
            defaultSound: false,
            defaultVibrateTimings: false,
            vibrateTimingsMillis: vibrateTimings,
            // NOTIFICA INVISIBILE - NESSUN TESTO
            title: "",
            body: "",
            icon: "@drawable/ic_notification_lightning",
            color: "#00FF00",
            clickAction: "FLUTTER_NOTIFICATION_CLICK",
            visibility: "private",
            showWhen: false,
            autoCancel: false,
            ongoing: false,
            silent: true,
          },
        },
        apns: {
          payload: {
            aps: {
              // iOS 18.6: Notifica silenziosa con haptic feedback
              "content-available": 1,
              "mutable-content": 1,
              sound: "default",
              badge: 1,
              alert: {
                title: "Hai ricevuto un ZAP!",
                body: "Tocca per vedere chi ti ha inviato un ZAP",
              },
              category: "zap_it_zaps",
              threadId: "zap_notifications",
              // iOS 18.6: Haptic feedback specifico
              "haptic-feedback": {
                type: "impact",
                intensity: vibrationIntensity === "high" ? "heavy" : 
                          vibrationIntensity === "low" ? "light" : "medium",
              },
            },
            data: {
              type: "new_zap",
              senderId: senderId,
              zapId: event.data.id,
              senderName: senderName,
              vibrationPattern: vibrationPattern,
              vibrationIntensity: vibrationIntensity,
              customVibration: customVibration,
              vibeComposerId: vibeComposerId,
              timestamp: Date.now().toString(),
            },
          },
          headers: {
            "apns-priority": "10",
            "apns-push-type": "alert",
            "apns-collapse-id": "zap_notification",
          },
        },
        token: fcmToken,
      };

      const response = await messaging.send(payload);
      console.log('✅ ZAP notification sent successfully:', response);
    } catch (error) {
      console.error('❌ Error sending ZAP notification:', error);
    }
  }
);

// Notifica richieste amicizia - UPDATED FOR iOS 18.6
export const sendFriendRequestNotification = onDocumentCreated(
  "friendRequests/{requestId}",
  async (event) => {
    try {
      const requestData = event.data.data();
      const senderId = requestData.senderId;
      const receiverId = requestData.receiverId;

      // Ottieni i dati del mittente
      const senderDoc = await db.collection("users").doc(senderId).get();
      const senderData = senderDoc.exists ? senderDoc.data() : {};
      const senderName = senderData.username || "Un amico";
      const senderUsername = senderData.username || "amico";

      // Ottieni il token FCM del destinatario
      const receiverDoc = await db.collection("users").doc(receiverId).get();
      const receiverData = receiverDoc.exists ? receiverDoc.data() : {};
      const fcmToken = receiverData.fcmToken;
      const friendRequestNotifications = receiverData.friendRequestNotifications !== false;

      if (!fcmToken) {
        console.log('❌ Token FCM non trovato per:', receiverId);
        return;
      }

      if (!friendRequestNotifications) {
        console.log('🔕 Friend request notifications disabled for user:', receiverId);
        return;
      }

      const payload = {
        notification: {
          title: "Nuova richiesta amicizia ⚡",
          body: "@$senderUsername vuole essere tuo amico",
        },
        data: {
          type: "friend_request",
          senderId: senderId,
          senderName: senderName,
          senderUsername: senderUsername,
          timestamp: Date.now().toString(),
        },
        android: {
          priority: "high",
          notification: {
            channelId: "friend_requests",
            priority: "high",
            defaultSound: true,
            defaultVibrateTimings: true,
            vibrateTimingsMillis: [0, 200, 100, 200],
            icon: "@drawable/ic_notification_lightning",
            color: "#00FF00",
            clickAction: "FLUTTER_NOTIFICATION_CLICK",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
              alert: {
                title: "Nuova richiesta amicizia ⚡",
                body: "@$senderUsername vuole essere tuo amico",
              },
              "content-available": 1,
              "mutable-content": 1,
              category: "zap_it_friend_requests",
              threadId: "friend_requests",
            },
            data: {
              type: "friend_request",
              senderId: senderId,
              senderName: senderName,
              senderUsername: senderUsername,
              timestamp: Date.now().toString(),
            },
          },
          headers: {
            "apns-priority": "10",
            "apns-push-type": "alert",
          },
        },
        token: fcmToken,
      };

      const response = await messaging.send(payload);
      console.log('✅ Friend request notification sent successfully:', response);
    } catch (error) {
      console.error('❌ Error sending friend request notification:', error);
    }
  }
);

// Aggiorna token FCM
export const updateFCMToken = onDocumentUpdated(
  "users/{userId}",
  async (event) => {
    try {
      const newData = event.data.after.data();
      const previousData = event.data.before.data();
      const newToken = newData.fcmToken;
      const oldToken = previousData.fcmToken;
      if (newToken && newToken !== oldToken) {
        await messaging.subscribeToTopic([newToken], "zap_notifications");
        if (oldToken) {
          await messaging.unsubscribeFromTopic([oldToken], "zap_notifications");
        }
        console.log('✅ Token FCM aggiornato per:', event.params.userId);
      }
    } catch (error) {
      console.error('❌ Errore aggiornamento token FCM:', error);
    }
  }
);

// Pulizia ZAP vecchi
export const cleanupOldZaps = onSchedule({ schedule: "every 24 hours" }, async (event) => {
  try {
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
    const oldZaps = await db
      .collection("zaps")
      .where("created_at", "<", thirtyDaysAgo)
      .limit(1000)
      .get();
    const batch = db.batch();
    oldZaps.docs.forEach(doc => {
      batch.delete(doc.ref);
    });
    await batch.commit();
    console.log(`🧹 Puliti ${oldZaps.docs.length} ZAP vecchi`);
  } catch (error) {
    console.error('❌ Errore pulizia ZAP:', error);
  }
});

// Cleanup old messages (TTL and auto-destruction) - SIMPLIFIED
export const cleanupOldMessages = onSchedule(
  { schedule: "every 1 hours" },
  async (event) => {
    try {
      console.log('🧹 Starting message cleanup...');
      
      const now = new Date();
      const fifteenDaysAgo = new Date(now.getTime() - (15 * 24 * 60 * 60 * 1000));
      
      // Get all conversations
      const conversationsSnapshot = await db.collection('conversations').get();
      
      for (const conversationDoc of conversationsSnapshot.docs) {
        const conversationId = conversationDoc.id;
        
        // Get all messages in this conversation
        const messagesSnapshot = await db
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .get();
        
        for (const messageDoc of messagesSnapshot.docs) {
          const messageData = messageDoc.data();
          const hardDeleteAt = messageData.hardDeleteAt;
          const isAutoDestroyed = messageData.isAutoDestroyed || false;
          
          let shouldDelete = false;
          let deleteReason = '';
          
          // Check TTL (15 days)
          if (hardDeleteAt && hardDeleteAt.toDate() < now) {
            shouldDelete = true;
            deleteReason = 'TTL expired (15 days)';
          }
          
          // Check if message is marked as auto-destroyed and older than 1 hour
          if (isAutoDestroyed && messageData.createdAt) {
            const messageAge = now.getTime() - messageData.createdAt.toDate().getTime();
            const oneHour = 60 * 60 * 1000;
            
            if (messageAge > oneHour) {
              shouldDelete = true;
              deleteReason = 'Auto-destroyed message older than 1 hour';
            }
          }
          
          if (shouldDelete) {
            try {
              await messageDoc.ref.delete();
              console.log(`🗑️ Deleted message ${messageDoc.id} in conversation ${conversationId}: ${deleteReason}`);
            } catch (deleteError) {
              console.error(`❌ Error deleting message ${messageDoc.id}:`, deleteError);
            }
          }
        }
      }
      
      console.log('✅ Message cleanup completed');
    } catch (error) {
      console.error('❌ Error in message cleanup:', error);
    }
  }
);

// Eliminazione automatica messaggi - RIPRISTINATA PER CANCELLARE SOLO I MESSAGGI
export const autoDeleteMessages = onDocumentUpdated(
  "conversations/{conversationId}",
  async (event) => {
    try {
      const beforeData = event.data.before.data();
      const afterData = event.data.after.data();
      const conversationId = event.params.conversationId;
      
      // Check if purgeAt has changed for any user
      const beforePurgeAt = beforeData?.purgeAt || {};
      const afterPurgeAt = afterData?.purgeAt || {};
      
      // Find which user has a new purge time
      let userWithNewPurge = null;
      for (const [userId, purgeTime] of Object.entries(afterPurgeAt)) {
        if (purgeTime && beforePurgeAt[userId] !== purgeTime) {
          userWithNewPurge = userId;
          break;
        }
      }
      
      if (!userWithNewPurge) {
        return; // No new purge times, nothing to do
      }
      
      console.log(`⏰ User ${userWithNewPurge} has new purge time for conversation: ${conversationId}`);
      
      // Schedule check after 10 seconds to see if ALL users have purged
      setTimeout(async () => {
        try {
          // Get current conversation state
          const currentConversationDoc = await db
            .collection('conversations')
            .doc(conversationId)
            .get();
          
          if (!currentConversationDoc.exists) {
            console.log(`Conversation ${conversationId} no longer exists`);
            return;
          }
          
          const currentData = currentConversationDoc.data();
          const participants = currentData.participants || [];
          const currentIsInChat = currentData?.isInChat || {};
          const currentPurgeAt = currentData?.purgeAt || {};
          const lastSeenInChatAt = currentData?.lastSeenInChatAt || {};
          
          // Check if ALL participants have either:
          // 1. A purge time that has passed, OR
          // 2. Are not currently in chat
          let allUsersPurged = true;
          let anyUserStillInChat = false;
          
          for (const participant of participants) {
            const isInChat = currentIsInChat[participant] === true;
            const purgeTime = currentPurgeAt[participant];
            const lastSeen = lastSeenInChatAt[participant];
            
            if (isInChat) {
              anyUserStillInChat = true;
              allUsersPurged = false;
              break; // If any user is in chat, don't delete
            }
            
            // User must have seen the messages (lastSeen exists) AND purge time has passed
            if (!lastSeen) {
              allUsersPurged = false; // User hasn't seen the messages yet
              break;
            }
            
            if (purgeTime) {
              const now = new Date();
              const purgeDateTime = purgeTime.toDate ? purgeTime.toDate() : new Date(purgeTime);
              
              if (now < purgeDateTime) {
                allUsersPurged = false; // This user's purge time hasn't passed yet
                break;
              }
            } else {
              allUsersPurged = false; // This user has no purge time set
              break;
            }
          }
          
          if (anyUserStillInChat) {
            console.log(`Some users are still in chat, keeping messages for conversation: ${conversationId}`);
            return;
          }
          
          if (!allUsersPurged) {
            console.log(`Not all users have purged yet, keeping messages for conversation: ${conversationId}`);
            return;
          }
          
          // ALL users have seen and purged - delete ALL messages from database
          console.log(`🗑️ ALL users have seen and purged, deleting ALL messages for conversation: ${conversationId}`);
          
          const messagesSnapshot = await db
            .collection('conversations')
            .doc(conversationId)
            .collection('messages')
            .get();
          
          const batch = db.batch();
          messagesSnapshot.docs.forEach(doc => {
            batch.delete(doc.ref);
          });
          
          // Reset conversation data but KEEP the conversation document
          batch.update(
            db.collection('conversations').doc(conversationId),
            {
              lastMessage: '',
              lastMessageAt: null,
              isLastMessageEncrypted: false,
              lastMessageSenderId: '',
              exitAt: {},
              purgeAt: {},
              isInChat: {},
              lastSeenInChatAt: {},
              // DO NOT delete the conversation document - only clear the messages
            }
          );
          
          await batch.commit();
          console.log(`✅ Deleted ALL ${messagesSnapshot.docs.length} messages from conversation: ${conversationId} (conversation kept)`);
          
        } catch (error) {
          console.error(`❌ Error in delayed deletion check:`, error);
        }
      }, 10000); // 10 seconds delay
      
    } catch (error) {
      console.error('❌ Error in autoDeleteMessages:', error);
    }
  }
);

// Update daily counter for user
async function updateDailyCounter(userId) {
  try {
    const userDoc = await db.collection("users").doc(userId).get();
    if (!userDoc.exists) return;

    const userData = userDoc.data();
    const today = new Date().toISOString().split('T')[0]; // YYYY-MM-DD format
    const lastZapDate = userData.lastZapDate || null;
    
    // If this is the first ZAP of the day
    if (lastZapDate !== today) {
      const currentDailyZaps = userData.dailyZaps || 0;
      const currentDailyStreak = userData.dailyStreak || 0;
      
      // Check if yesterday was consecutive
      const yesterday = new Date();
      yesterday.setDate(yesterday.getDate() - 1);
      const yesterdayStr = yesterday.toISOString().split('T')[0];
      
      let newDailyStreak = 1; // Start with 1 for today
      
      if (lastZapDate === yesterdayStr) {
        // Consecutive day - increment streak
        newDailyStreak = currentDailyStreak + 1;
      } else if (lastZapDate && lastZapDate !== yesterdayStr) {
        // Not consecutive - reset streak to 1
        newDailyStreak = 1;
      }
      
      // Update user document
      await db.collection("users").doc(userId).update({
        dailyZaps: currentDailyZaps + 1,
        dailyStreak: newDailyStreak,
        lastZapDate: today,
      });
      
      console.log(`🔥 Updated daily counter for user ${userId}: dailyZaps=${currentDailyZaps + 1}, dailyStreak=${newDailyStreak}`);
    } else {
      // Same day - just increment daily ZAPs
      const currentDailyZaps = userData.dailyZaps || 0;
      await db.collection("users").doc(userId).update({
        dailyZaps: currentDailyZaps + 1,
      });
      
      console.log(`🔥 Incremented daily ZAPs for user ${userId}: ${currentDailyZaps + 1}`);
    }
  } catch (error) {
    console.error(`❌ Error updating daily counter for user ${userId}:`, error);
  }
} 