# Generatore Dati di Test per Zap It Mobile

Questo strumento ti permette di generare rapidamente account di test con nomi utenti italiani per popolare la schermata home dell'app.

## 🚀 Come Utilizzare

### Metodo 1: Widget nell'App (Raccomandato)

1. **Aggiungi il widget alla schermata home** (temporaneamente):
   ```dart
   // In home_screen.dart, aggiungi questo import
   import '../widgets/test_data_generator_widget.dart';
   
   // E aggiungi questo widget nella build method (dopo la lista degli amici)
   if (kDebugMode) // Solo in modalità debug
     const TestDataGeneratorWidget(),
   ```

2. **Esegui l'app** e usa i pulsanti del widget per:
   - Generare 20 utenti di test
   - Generare 5 utenti di test (più veloce)
   - Pulire tutti gli utenti di test

### Metodo 2: Console Flutter

1. **Esegui l'app in modalità web**:
   ```bash
   flutter run -d chrome --dart-define=FLUTTER_WEB_USE_SKIA=true
   ```

2. **Apri la console del browser** (F12 → Console)

3. **Esegui uno di questi comandi**:
   ```javascript
   // Genera 20 utenti
   await TestDataGeneratorRunner.generateTestData();
   
   // Genera solo 5 utenti (più veloce)
   await TestDataGeneratorRunner.generateQuickTestData();
   
   // Pulisci tutti gli utenti di test
   await TestDataGeneratorRunner.cleanupTestData();
   ```

### Metodo 3: Codice Diretto

```dart
import 'package:your_app/utils/test_data_generator.dart';

// Genera 20 utenti
await TestDataGenerator.generateTestUsers(count: 20);

// Genera solo 5 utenti
await TestDataGenerator.generateTestUsers(count: 5);

// Pulisci tutti gli utenti di test
await TestDataGenerator.cleanupTestUsers();
```

## 📱 Account Generati

### Credenziali di Accesso
- **Password per tutti gli utenti**: `Test123!`
- **Email**: `username@test.it` (dove username è generato automaticamente)

### Esempi di Account
- `marco_rossi123@test.it` / `Test123!`
- `giulia_ferrari456@test.it` / `Test123!`
- `alessandro_russo789@test.it` / `Test123!`

### Dati Generati
- **Nomi e cognomi italiani** autentici
- **Username unici** combinando nome e cognome
- **Statistiche casuali** di ZAP inviati/ricevuti
- **Flag `isTestUser`** per identificare gli account di test

## 🎯 Cosa Vedrai nella Home

Dopo aver generato gli utenti e aver fatto login con uno di essi:

1. **Lista amici popolata** con i nomi italiani
2. **Statistiche diverse** per ogni utente
3. **Leaderboard popolata** con i nuovi utenti
4. **Interfaccia più realistica** per testare le funzionalità

## ⚠️ Note Importanti

### Sicurezza
- **Solo per sviluppo e test**
- **Non utilizzare in produzione**
- **Gli utenti hanno password semplici**

### Limitazioni
- **Rate limiting** di Firebase (pausa di 500ms tra creazioni)
- **Max 20 utenti** per sessione (evita sovraccarico)
- **Richiede autenticazione Firebase** configurata

### Pulizia
- **Usa sempre "Pulisci"** dopo i test
- **Gli utenti di test** sono marcati con `isTestUser: true`
- **Pulizia completa** rimuove sia Auth che Firestore

## 🔧 Personalizzazione

### Modificare i Nomi
```dart
// In test_data_generator.dart, modifica queste liste:
static const List<String> _italianNames = [
  'Il_Tuo_Nome', 'Altro_Nome', // ...
];

static const List<String> _italianSurnames = [
  'Il_Tuo_Cognome', 'Altro_Cognome', // ...
];
```

### Modificare le Statistiche
```dart
// Modifica i range delle statistiche casuali:
final zapsSent = 10 + (DateTime.now().millisecondsSinceEpoch % 100);
final zapsReceived = 5 + (DateTime.now().millisecondsSinceEpoch % 50);
```

### Modificare il Numero di Utenti
```dart
// Cambia il numero predefinito:
await TestDataGenerator.generateTestUsers(count: 30); // 30 utenti
```

## 🚨 Risoluzione Problemi

### Errore "Email già in uso"
- Usa "Pulisci" per rimuovere gli utenti esistenti
- Riavvia l'app e riprova

### Errore di Autenticazione
- Verifica che Firebase sia configurato correttamente
- Controlla le regole di sicurezza di Firestore

### Rate Limiting
- Riduci il numero di utenti (usa 5 invece di 20)
- Aumenta la pausa tra le creazioni (modifica `Duration(milliseconds: 500)`)

## 📝 Esempi di Utilizzo

### Test Rapido
```dart
// Genera 5 utenti velocemente
await TestDataGeneratorRunner.generateQuickTestData();

// Fai login con uno degli account generati
// Testa la funzionalità della home
// Pulisci alla fine
await TestDataGeneratorRunner.cleanupTestData();
```

### Test Completo
```dart
// Genera 20 utenti per un test completo
await TestDataGeneratorRunner.generateTestData();

// Testa tutte le funzionalità con dati realistici
// Verifica la leaderboard, le statistiche, ecc.
// Pulisci alla fine
await TestDataGeneratorRunner.cleanupTestData();
```

## 🎉 Risultato Finale

Dopo aver utilizzato il generatore, avrai:
- ✅ **Home popolata** con utenti italiani realistici
- ✅ **Statistiche variegate** per testare tutte le funzionalità
- ✅ **Leaderboard funzionante** con dati di test
- ✅ **Interfaccia più coinvolgente** per i test

Buon testing! 🚀

