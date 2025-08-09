# Firestore Index Setup

## ⚠️ UPDATED - Multiple Indexes Required

The app requires multiple composite indexes for different queries. The error shows we need indexes for different query patterns.

**Note**: The ZAP history now shows all ZAPs (both read and unread) to prevent them from disappearing immediately.

### Index 1: For Real-time ZAP Notifications (unread ZAPs)
- **Collection**: `zaps`
- **Fields**:
  1. `status` (Ascending) - 'sent' = unread, 'read' = read
  2. `receiverId` (Ascending)
  3. `created_at` (Descending)
  4. `__name__` (Descending)

### Index 2: For ZAP History (shows all ZAPs)
- **Collection**: `zaps`
- **Fields**:
  1. `receiverId` (Ascending)
  2. `created_at` (Descending)
  3. `__name__` (Descending)

### How to Create the Indexes:

#### Index 1: For Real-time ZAP Notifications (with read filter)

1. **Via Direct Link:**
   - Click this link to create the first index:
   ```
   https://console.firebase.google.com/v1/r/project/zap-it-ac442/firestore/indexes?create_composite=ClJwcm9qZWN0cy96YXAtaXQtYWM0NDIvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL3phcHMvaW5kZXhlcy9fEAEaDgoKcmVjZWl2ZXJJZBABGg4KCmNyZWF0ZWRfYXQQAhoMCghfX25hbWVfXxAC
   ```

2. **Via Firebase Console:**
   - Go to [Firebase Console](https://console.firebase.google.com)
   - Select your project: `zap-it-ac442`
   - Navigate to Firestore Database
   - Go to Indexes tab
   - Click "Create Index"
   - Collection ID: `zaps`
   - Add fields in this exact order:
     1. `status` (Ascending)
     2. `receiverId` (Ascending)
     3. `created_at` (Descending)
     4. `__name__` (Descending)
   - Click "Create"

#### Index 2: For ZAP History (shows all ZAPs)

1. **Via Direct Link:**
   - Click this link to create the second index:
   ```
   https://console.firebase.google.com/v1/r/project/zap-it-ac442/firestore/indexes?create_composite=Cklwcm9qZWN0cy96YXAtaXQtYWM0NDIvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL3phcHMvaW5kZXhlcy9fEAEaDgoKcmVjZWl2ZXJJZBABGg4KCmNyZWF0ZWRfYXQQAhoMCghfX25hbWVfXxAC
   ```

2. **Via Firebase Console:**
   - Go to [Firebase Console](https://console.firebase.google.com)
   - Select your project: `zap-it-ac442`
   - Navigate to Firestore Database
   - Go to Indexes tab
   - Click "Create Index"
   - Collection ID: `zaps`
   - Add fields in this exact order:
     1. `receiverId` (Ascending)
     2. `created_at` (Descending)
     3. `__name__` (Descending)
   - Click "Create"

### Current Status:
- ⚠️ Previous index created but incomplete
- 🔄 Two indexes needed for different query patterns
- ⏳ Waiting for both indexes to be created and active
- 📱 App will work once both indexes are active

### Index 3: For Messages (unread messages)
- **Collection**: `messages`
- **Fields**:
  1. `isRead` (Ascending)
  2. `senderId` (Ascending)
  3. `__name__` (Ascending)

### How to Create Index 3:

1. **Via Direct Link:**
   - Click this link to create the messages index:
   ```
   https://console.firebase.google.com/v1/r/project/zap-it-ac442/firestore/indexes?create_composite=Ck1wcm9qZWN0cy96YXAtaXQtYWM0NDIvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL21lc3NhZ2VzL2luZGV4ZXMvXxABGgoKBmlzUmVhZBABGgwKCHNlbmRlcklkEAEaDAoIX19uYW1lX18QAQ
   ```

2. **Via Firebase Console:**
   - Go to [Firebase Console](https://console.firebase.google.com)
   - Select your project: `zap-it-ac442`
   - Navigate to Firestore Database
   - Go to Indexes tab
   - Click "Create Index"
   - Collection ID: `messages`
   - Add fields in this exact order:
     1. `isRead` (Ascending)
     2. `senderId` (Ascending)
     3. `__name__` (Ascending)
   - Click "Create"

### Note:
The app will work properly once all three indexes are created and active:
1. **Index 1**: For real-time ZAP notifications (with read filter)
2. **Index 2**: For ZAP history (shows all ZAPs)
3. **Index 3**: For messages (unread messages)

**Behavior**: 
- Badge counter shows unread ZAPs (status = 'sent')
- ZAPs are marked as read only when user opens ZAP section
- Badge persists until user actually views the ZAPs
- ZAP history shows all ZAPs (both read and unread)
- Messages show proper preview instead of "[messaggio crittografato]" 

Perfetto! Ecco come creare una **Cloud Function** che invia una notifica push FCM ogni volta che viene scritto un nuovo messaggio in Firestore.

---

## 1. **Prerequisiti**

- **Firebase CLI** installata (`npm install -g firebase-tools`)
- **Cartella `functions/`** già presente nel tuo progetto Firebase (se non c’è, esegui `firebase init functions`)
- **Hai già associato il progetto locale a quello su Firebase Console**

---

## 2. **Codice Cloud Function (Node.js)**

Copia questo codice in `functions/index.js` (o `functions/src/index.ts` se usi TypeScript):

```js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.sendMessageNotification = functions.firestore
  .document('messages/{messageId}')
  .onCreate(async (snap, context) => {
    const message = snap.data();
    const receiverId = message.receiverId;
    const senderName = message.senderName || 'Nuovo messaggio';

    // Recupera il token FCM del destinatario
    const userDoc = await admin.firestore().collection('users').doc(receiverId).get();
    const fcmToken = userDoc.data().fcmToken;

    if (!fcmToken) return null;

    const payload = {
      notification: {
        title: senderName,
        body: message.text || 'Hai ricevuto un nuovo messaggio!',
      },
      data: {
        type: 'new_message',
        senderId: message.senderId,
        chatId: message.chatId || '',
      },
      token: fcmToken,
    };

    return admin.messaging().send(payload);
  });
```

---

## 3. **Installa le dipendenze**

Nella cartella `functions/`, esegui:

```sh
npm install firebase-admin firebase-functions
```

---

## 4. **Deploy della funzione**

Dalla root del progetto (dove c’è `firebase.json`):

```sh
firebase deploy --only functions
```

---

## 5. **Come funziona**

- Ogni volta che viene creato un nuovo documento nella collection `messages`, la funzione:
  - Prende il campo `receiverId` dal messaggio.
  - Recupera il token FCM del destinatario dalla collection `users`.
  - Invia una notifica push a quel token.

---

## 6. **Assicurati che:**
- Ogni utente abbia il campo `fcmToken` aggiornato nel proprio documento Firestore (`users/{uid}`).
- I permessi Firestore permettano alla funzione di leggere i documenti `users`.

---

## 7. **Test**

- Invia un messaggio in chat (scrivi un nuovo documento in `messages`).
- Il destinatario deve ricevere la notifica push.

---

**Vuoi anche la versione TypeScript, o hai bisogno di aiuto per la struttura delle collection/campi?**  
Se vuoi, posso fornirti anche un esempio di struttura Firestore o aiutarti a testare la funzione! 
