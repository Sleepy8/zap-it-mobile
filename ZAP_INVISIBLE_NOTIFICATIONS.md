# Sistema Notifiche ZAP Invisibili

## Panoramica

Le notifiche ZAP sono state modificate per essere **quasi invisibili e anonime**, mostrando solo la vibrazione personalizzata senza testo visibile. Questo mantiene l'elemento di sorpresa e l'anonimato degli ZAP.

## Modifiche Implementate

### 1. Cloud Function (functions/index.mjs)

**Prima:**
- Notifiche con titolo e corpo visibili
- Suono personalizzato
- Icona e colori visibili

**Dopo:**
- Titolo e corpo vuoti (`title: "", body: ""`)
- Nessun suono (`defaultSound: false`)
- Icona trasparente (`color: "#00000000"`)
- Visibilità privata (`visibility: "private"`)
- Solo vibrazione personalizzata

### 2. NotificationService (lib/services/notification_service.dart)

**Prima:**
- Mostrava notifica locale visibile
- Funzione `_showBeautifulZapNotification`

**Dopo:**
- Rimossa notifica locale visibile
- Solo vibrazione (`_triggerZapVibration`)
- Canale di notifiche silenzioso configurato

### 3. Canale di Notifiche ZAP

```dart
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
```

## Comportamento Attuale

### Quando Arriva uno ZAP:

1. **Vibrazione Personalizzata**: Il pattern di vibrazione personalizzato viene eseguito
2. **Nessuna Notifica Visibile**: Non appare alcun testo o icona
3. **Silenzio**: Nessun suono di notifica
4. **Anonimato**: Chiunque guardi il telefono non sa che è arrivato uno ZAP

### Vantaggi:

- ✅ **Maggior Anonimato**: Gli ZAP sono completamente discreti
- ✅ **Elemento di Sorpresa**: L'utente non sa chi ha inviato lo ZAP
- ✅ **Vibrazione Personalizzata**: Mantiene l'esperienza tattile unica
- ✅ **Privacy**: Nessuna informazione visibile su schermo bloccato

### Configurazione Tecnica:

#### Android:
```javascript
android: {
  notification: {
    title: "", // Vuoto
    body: "", // Vuoto
    defaultSound: false,
    defaultVibrateTimings: false,
    vibrateTimingsMillis: [0, 150, 100, 200, 100, 300, 100, 150],
  }
}
```

#### iOS:
```javascript
apns: {
  payload: {
    aps: {
      sound: "silence.aiff",
      alert: {
        title: "",
        body: "",
      }
    }
  }
}
```

## Test

Per testare le notifiche ZAP invisibili:

1. Invia uno ZAP a un amico
2. Verifica che arrivi solo la vibrazione
3. Controlla che non appaia alcuna notifica visibile
4. Verifica che non ci sia suono di notifica

## Note Importanti

- Le notifiche ZAP sono ora completamente discrete
- Solo la vibrazione personalizzata indica l'arrivo di uno ZAP
- L'utente deve aprire l'app per vedere chi ha inviato lo ZAP
- Il sistema mantiene tutte le funzionalità di vibrazione personalizzata 