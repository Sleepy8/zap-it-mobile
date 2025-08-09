import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
// Use default credentials provided by Cloud Functions runtime (recommended)
initializeApp();
const db = getFirestore();
const messaging = getMessaging();

// Notifica messaggi chat
export const sendMessageNotification = onDocumentCreated(
  "conversations/{conversationId}/messages/{messageId}",
  async (event) => {
    try {
      const message = event.data.data();
      const conversationId = event.params.conversationId;
      // Ottieni i dati della conversazione
      const conversationDoc = await db
        .collection("conversations")
        .doc(conversationId)
        .get();
      if (!conversationDoc.exists) {
        console.log('Conversazione non trovata:', conversationId);
        return;
      }
      const conversationData = conversationDoc.data();
      const participants = conversationData.participants || [];
      const senderId = message.senderId;
      // Trova il destinatario (l'altro partecipante)
      const receiverId = participants.find(id => id !== senderId);
      if (!receiverId) {
        console.log('Destinatario non trovato per conversazione:', conversationId);
        return;
      }
      // Ottieni i dati del mittente
      const senderDoc = await db.collection("users").doc(senderId).get();
      const senderName = senderDoc.exists ? senderDoc.data().username || 'Un amico' : 'Un amico';
      // Ottieni il token FCM del destinatario
      const receiverDoc = await db.collection("users").doc(receiverId).get();
      const fcmToken = receiverDoc.exists ? receiverDoc.data().fcmToken : null;
      if (!fcmToken) {
        console.log('Token FCM non trovato per:', receiverId);
        return;
      }
      // Decripta il messaggio se necessario
      let messageText = message.text || "Nuovo messaggio";
      if (message.isEncrypted) {
        messageText = "🔒 Messaggio crittografato";
      }
      const payload = {
        notification: {
          title: senderName,
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
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
              alert: {
                title: senderName,
                body: messageText,
              },
            },
          },
        },
        token: fcmToken,
      };
      const response = await messaging.send(payload);
      console.log('✅ Notifica messaggio inviata:', response);
      return response;
    } catch (error) {
      console.error('❌ Errore invio notifica messaggio:', error);
      return;
    }
  }
);

// Notifica ZAP (silenziosa)
export const sendZapNotification = onDocumentCreated(
  "zaps/{zapId}",
  async (event) => {
    try {
      const zap = event.data.data();
      const receiverId = zap.receiverId;
      const senderId = zap.senderId;
      // Ottieni i dati del mittente
      const senderDoc = await db.collection("users").doc(senderId).get();
      const senderName = senderDoc.exists ? senderDoc.data().username || 'Un amico' : 'Un amico';
      // Ottieni il token FCM del destinatario
      const receiverDoc = await db.collection("users").doc(receiverId).get();
      const fcmToken = receiverDoc.exists ? receiverDoc.data().fcmToken : null;
      if (!fcmToken) {
        console.log('Token FCM non trovato per:', receiverId);
        return;
      }
      // Configurazione vibrazione personalizzata
      const vibrationPattern = zap.vibrationPattern || "default";
      const vibrationIntensity = zap.vibrationIntensity || "medium";
      const customVibration = zap.customVibration || "";
      const vibeComposerId = zap.vibeComposerId || "";
      // Pattern di vibrazione per ZAP
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
        // NOTIFICA QUASI INVISIBILE - SOLO VIBRAZIONE
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
            title: "", // Titolo vuoto
            body: "", // Corpo vuoto
            icon: "@mipmap/ic_launcher",
            color: "#000000", // Nero (invisibile)
            visibility: "private", // Privata
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "silence.aiff",
              badge: 1,
              // NOTIFICA INVISIBILE SU iOS
              alert: {
                title: "",
                body: "",
              },
              "content-available": 1,
            },
          },
        },
        token: fcmToken,
      };
      const response = await messaging.send(payload);
      console.log('⚡ Notifica ZAP invisibile inviata:', response);
      // Aggiorna statistiche utente
      await db.collection("users").doc(senderId).update({
        zapsSent: FieldValue.increment(1),
      });
      await db.collection("users").doc(receiverId).update({
        zapsReceived: FieldValue.increment(1),
      });
      return response;
    } catch (error) {
      console.error('❌ Errore invio notifica ZAP:', error);
      return;
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