# Firebase Cloud Functions Setup per Notifiche ZAP

## Configurazione Firebase Cloud Functions

Per implementare le notifiche push reali, è necessario configurare Firebase Cloud Functions.

### 1. Installazione Firebase CLI

```bash
npm install -g firebase-tools
firebase login
```

### 2. Inizializzazione Functions

```bash
firebase init functions
cd functions
npm install firebase-admin firebase-functions
```

### 3. Codice Cloud Function

Crea il file `functions/index.js`:

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Cloud Function per inviare notifiche ZAP
exports.sendZapNotification = functions.firestore
  .document('zaps/{zapId}')
  .onCreate(async (snap, context) => {
    try {
      const zapData = snap.data();
      const { senderId, receiverId } = zapData;

      // Ottieni i dati del mittente
      const senderDoc = await admin.firestore()
        .collection('users')
        .doc(senderId)
        .get();
      
      const senderName = senderDoc.data()?.name || 'Un amico';

      // Ottieni il token FCM del destinatario
      const receiverDoc = await admin.firestore()
        .collection('users')
        .doc(receiverId)
        .get();
      
      const fcmToken = receiverDoc.data()?.fcmToken;

      if (!fcmToken) {
        console.log('FCM token non trovato per:', receiverId);
        return null;
      }

      // Crea il messaggio di notifica
      const message = {
        token: fcmToken,
        notification: {
          title: 'ZAP Ricevuto! ⚡',
          body: `${senderName} ti ha inviato un ZAP!`,
        },
        data: {
          type: 'zap',
          senderId: senderId,
          senderName: senderName,
          timestamp: Date.now().toString(),
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'zap_channel',
            priority: 'high',
            defaultSound: true,
            defaultVibrateTimings: true,
            vibrateTimingsMillis: [0, 150, 100, 200, 100, 300, 100, 150],
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'zap_sound.aiff',
              badge: 1,
            },
          },
        },
      };

      // Invia la notifica
      const response = await admin.messaging().send(message);
      console.log('Notifica ZAP inviata:', response);
      
      return response;
    } catch (error) {
      console.error('Errore nell\'invio notifica ZAP:', error);
      return null;
    }
  });

// Cloud Function per aggiornare token FCM
exports.updateFCMToken = functions.firestore
  .document('users/{userId}')
  .onUpdate(async (change, context) => {
    const newData = change.after.data();
    const previousData = change.before.data();
    
    const newToken = newData.fcmToken;
    const oldToken = previousData.fcmToken;

    // Se il token è cambiato, aggiorna le sottoscrizioni
    if (newToken && newToken !== oldToken) {
      try {
        // Sottoscrivi l'utente al topic generale
        await admin.messaging().subscribeToTopic([newToken], 'zap_notifications');
        
        // Se c'era un token precedente, disiscriviti
        if (oldToken) {
          await admin.messaging().unsubscribeFromTopic([oldToken], 'zap_notifications');
        }
        
        console.log('Token FCM aggiornato per:', context.params.userId);
      } catch (error) {
        console.error('Errore nell\'aggiornamento token FCM:', error);
      }
    }
  });
```

### 4. Deploy delle Functions

```bash
firebase deploy --only functions
```

### 5. Configurazione Android

Aggiungi il file `android/app/src/main/res/raw/zap_sound.mp3` per il suono personalizzato.

### 6. Configurazione iOS

Aggiungi il file `ios/Runner/zap_sound.aiff` per il suono personalizzato.

## Regole Firestore

Aggiorna le regole Firestore per permettere le notifiche:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Regole per utenti
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      allow read: if request.auth != null; // Per cercare amici
    }
    
    // Regole per amicizie
    match /friendships/{friendshipId} {
      allow read, write: if request.auth != null;
    }
    
    // Regole per ZAP
    match /zaps/{zapId} {
      allow read, write: if request.auth != null;
    }
    
    // Regole per notifiche
    match /notifications/{notificationId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## Test delle Notifiche

1. **Test Locale**: Usa il widget di test nel profilo
2. **Test Cloud Function**: Invia un ZAP a un amico
3. **Test Background**: Metti l'app in background e invia un ZAP

## Troubleshooting

### Problemi Comuni

1. **Token FCM non salvato**: Verifica che l'utente sia autenticato
2. **Notifiche non ricevute**: Controlla le impostazioni del dispositivo
3. **Vibrazione non funziona**: Verifica i permessi di vibrazione
4. **Background non funziona**: Controlla le impostazioni di batteria del dispositivo

### Log di Debug

```bash
# Visualizza log delle functions
firebase functions:log

# Test locale delle functions
firebase emulators:start --only functions
```

## Ottimizzazioni

1. **Batch Notifications**: Raggruppa più ZAP in una notifica
2. **Rate Limiting**: Limita il numero di ZAP per minuto
3. **Smart Notifications**: Invia notifiche solo quando l'utente è offline
4. **Analytics**: Traccia l'efficacia delle notifiche 