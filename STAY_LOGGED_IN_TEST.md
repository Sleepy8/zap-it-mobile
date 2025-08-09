# Stay Logged In - Test Guide

## ✅ Funzionalità Implementata

La funzionalità "Rimani loggato" è stata implementata con le seguenti caratteristiche:

### Come Funziona:
1. **Login automatico**: Il login viene salvato automaticamente (come Instagram)
2. **Salvataggio in SharedPreferences**: I dati vengono salvati localmente
3. **Durata sessione**: **PERMANENTE** - rimane loggato finché non fa logout manualmente
4. **Controllo automatico**: L'app verifica la sessione all'avvio

### Test della Funzionalità:

#### Test 1: Login automatico (come Instagram)
1. Apri l'app
2. Fai login con email e password
3. Clicca "Accedi"
4. **NON serve selezionare nulla** - il login viene salvato automaticamente
5. Verifica che l'app ti porti alla home

#### Test 2: Riavvio app (senza logout)
1. Chiudi completamente l'app (swipe via dal recent apps)
2. Riapri l'app
3. **RISULTATO ATTESO**: L'app dovrebbe portarti direttamente alla home senza mostrare la schermata di login

#### Test 3: Riavvio telefono (senza logout)
1. Riavvia completamente il telefono
2. Apri l'app
3. **RISULTATO ATTESO**: L'app dovrebbe portarti direttamente alla home senza mostrare la schermata di login

#### Test 4: Riavvio app (con logout)
1. Vai nel profilo
2. Clicca "Logout"
3. Chiudi completamente l'app
4. Riapri l'app
5. **RISULTATO ATTESO**: L'app dovrebbe mostrare la schermata di login

### Note Importanti:

#### ✅ Comportamento Corretto:
- **Sessione permanente**: L'utente rimane loggato finché non fa logout manualmente
- **Come Instagram**: Stesso comportamento delle app social moderne
- **Riavvio telefono**: La sessione persiste anche dopo il riavvio del dispositivo
- **SharedPreferences**: La preferenza viene salvata localmente e persiste

#### ⚠️ Limitazioni:
- **Riavvio da Android Studio**: Quando riavvii l'app da Android Studio, la sessione Firebase viene cancellata automaticamente
- **Test su emulatore**: Il comportamento potrebbe variare rispetto a un dispositivo reale

#### 🔧 Come Testare Correttamente:
1. **Test su dispositivo reale**: Per un test completo, usa un dispositivo Android reale
2. **Test normale**: Chiudi l'app normalmente (non da Android Studio)
3. **Test riavvio telefono**: Riavvia il telefono e verifica che rimanga loggato
4. **Verifica SharedPreferences**: La preferenza viene salvata in `SharedPreferences`

### Debug Logs:
L'app stampa i seguenti log per il debug:
- `✅ Stay logged in enabled permanently (until manual logout)` - Quando la funzionalità è attivata
- `✅ Stay logged in enabled, session valid` - Quando la sessione è ancora valida
- `✅ Stay logged in disabled` - Quando la funzionalità è disabilitata

### File Modificati:
1. `lib/services/auth_service_firebase_impl.dart` - Implementazione SharedPreferences (senza limite di tempo)
2. `lib/services/auth_service.dart` - Metodi pubblici per stay logged in
3. `lib/screens/login_screen.dart` - Checkbox UI
4. `lib/main.dart` - Controllo all'avvio dell'app

### Prossimi Passi:
1. Testa la funzionalità su dispositivo reale
2. Verifica che il comportamento sia corretto anche dopo riavvio del telefono
3. Confronta con il comportamento di Instagram per verificare la similarità 