# Sistema ZAP - Spiegazione Tecnica

## Panoramica

Il sistema ZAP è il cuore dell'applicazione. Permette agli utenti di inviare "vibrazioni" agli amici attraverso notifiche push silenziose che svegliano l'app dal background e attivano la vibrazione del dispositivo.

## Architettura del Sistema

### 1. Flusso di Invio ZAP

```
Utente A → Toca ZAP → FriendsService → Firestore → Cloud Function → FCM → Utente B
```

1. **Utente A** tocca il pulsante ZAP su un amico
2. **FriendsService** crea un record ZAP in Firestore
3. **Cloud Function** intercetta il nuovo record e invia notifica push
4. **Firebase Cloud Messaging (FCM)** consegna la notifica al dispositivo dell'amico
5. **App in background** si sveglia e attiva la vibrazione

### 2. Componenti Principali

#### NotificationService
- Gestisce le notifiche push Firebase
- Richiede permessi di notifica e vibrazione
- Salva il token FCM dell'utente in Firestore
- Gestisce notifiche in foreground e background

#### BackgroundService
- Mantiene l'app attiva in background
- Timer di keep-alive per prevenire la chiusura
- Gestisce il ciclo di vita dell'app

#### FriendsService
- Integrato con NotificationService
- Invia ZAP e notifiche push
- Aggiorna statistiche utente

### 3. Vibrazione Personalizzata

Il pattern di vibrazione ZAP è progettato per essere distintivo:

```dart
pattern: [0, 150, 100, 200, 100, 300, 100, 150]
intensities: [0, 255, 0, 255, 0, 255, 0, 255]
```

- **0ms**: Pausa iniziale
- **150ms**: Vibrazione breve
- **100ms**: Pausa
- **200ms**: Vibrazione media
- **100ms**: Pausa
- **300ms**: Vibrazione lunga
- **100ms**: Pausa
- **150ms**: Vibrazione finale

### 4. Stati dell'App

#### Foreground
- App aperta e attiva
- Notifiche gestite da `onMessage`
- Vibrazione immediata

#### Background
- App minimizzata ma attiva
- Notifiche gestite da `onBackgroundMessage`
- Vibrazione automatica

#### Terminated
- App completamente chiusa
- Notifiche gestite dal sistema operativo
- App si riavvia e vibra

## Configurazione Tecnica

### Permessi Android

```xml
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
```

### Canale Notifiche Android

```dart
AndroidNotificationDetails(
  'zap_channel',
  'ZAP Notifications',
  channelDescription: 'Notifications for ZAP messages',
  importance: Importance.high,
  priority: Priority.high,
  enableVibration: true,
  playSound: true,
)
```

### Token FCM

Ogni dispositivo genera un token FCM univoco che viene salvato in Firestore:

```dart
await _firestore.collection('users').doc(user.uid).update({
  'fcmToken': token,
  'lastTokenUpdate': FieldValue.serverTimestamp(),
});
```

## Gestione degli Errori

### Problemi Comuni

1. **Token FCM non salvato**
   - Verifica autenticazione utente
   - Controlla connessione internet
   - Log: "FCM token not found"

2. **Notifiche non ricevute**
   - Verifica permessi notifiche
   - Controlla impostazioni dispositivo
   - Testa con widget di test

3. **Vibrazione non funziona**
   - Verifica permessi vibrazione
   - Controlla supporto dispositivo
   - Testa pattern personalizzato

4. **Background non funziona**
   - Verifica impostazioni batteria
   - Controlla ottimizzazioni sistema
   - Testa keep-alive timer

### Debug e Log

```dart
print('=== ZAP NOTIFICATION DEBUG ===');
print('Sender: $senderName');
print('Receiver: $friendId');
print('FCM Token: $fcmToken');
print('Vibration: ${await Vibration.hasVibrator()}');
```

## Ottimizzazioni

### 1. Rate Limiting
```dart
// Limita ZAP a 1 per 30 secondi per amico
final lastZap = await _getLastZapTime(senderId, friendId);
if (lastZap != null && DateTime.now().difference(lastZap).inSeconds < 30) {
  throw Exception('Troppi ZAP! Aspetta un po\'.');
}
```

### 2. Batch Notifications
```dart
// Raggruppa più ZAP in una notifica
if (zapCount > 1) {
  title = 'Hai ricevuto $zapCount ZAP! ⚡';
  body = 'I tuoi amici ti stanno pensando!';
}
```

### 3. Smart Notifications
```dart
// Invia notifiche solo quando offline
final userStatus = await _getUserStatus(receiverId);
if (userStatus == 'online') {
  // Solo vibrazione, no notifica
} else {
  // Vibrazione + notifica
}
```

## Test del Sistema

### Widget di Test
Il widget `ZapTestWidget` permette di testare:
- Vibrazione ZAP
- Notifiche push
- Permessi dispositivo

### Test Manuali
1. **Test Vibrazione**: Toca "Test ZAP Vibrazione"
2. **Test Notifica**: Toca "Test Notifica"
3. **Test Background**: Metti app in background e invia ZAP
4. **Test Multi-dispositivo**: Invia ZAP tra due dispositivi

## Sicurezza

### Validazione
- Verifica che gli utenti siano amici
- Controlla rate limiting
- Valida dati notifica

### Privacy
- Token FCM salvati solo per utenti autenticati
- Dati notifica minimi
- Nessun contenuto sensibile nelle notifiche

## Performance

### Ottimizzazioni
- Lazy loading delle notifiche
- Cache dei token FCM
- Compressione dati notifica
- Background processing ottimizzato

### Monitoraggio
- Metriche di consegna notifiche
- Tempo di risposta vibrazione
- Tasso di successo ZAP
- Errori e fallimenti

## Roadmap

### Funzionalità Future
1. **ZAP Personalizzati**: Pattern vibrazione personalizzati
2. **ZAP di Gruppo**: Invia ZAP a più amici
3. **ZAP Programmati**: Invia ZAP a orari specifici
4. **Analytics Avanzati**: Statistiche dettagliate ZAP
5. **Integrazione Social**: Condividi ZAP sui social

### Miglioramenti Tecnici
1. **WebSocket**: Comunicazione real-time
2. **Push Native**: Notifiche native per performance
3. **Machine Learning**: Predizione ZAP ottimali
4. **Offline Support**: ZAP in coda quando offline 