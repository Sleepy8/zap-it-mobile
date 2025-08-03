# Debug iOS - Zap It Mobile

## Problemi Comuni e Soluzioni

### 1. App Crasha all'Avvio

**Possibili Cause:**
- Firebase non inizializzato correttamente
- Servizi di notifica che falliscono
- Background service che causa problemi
- Permessi iOS non configurati

**Soluzioni Implementate:**
- ✅ Gestione errori robusta in `main.dart`
- ✅ Inizializzazione Firebase con configurazione iOS specifica
- ✅ Servizi opzionali che non bloccano l'avvio dell'app
- ✅ Debug helper per logging dettagliato

### 2. Come Verificare i Log

**Su Xcode:**
1. Apri Xcode
2. Window → Devices and Simulators
3. Seleziona il tuo iPhone
4. Clicca su "Open Console"
5. Filtra per "ZapIt" per vedere i log dell'app

**Su Console di macOS:**
1. Apri Console.app
2. Seleziona il tuo iPhone dalla sidebar
3. Cerca "ZapIt" nei log

### 3. Test di Stabilità

**Test 1: Avvio App**
```bash
flutter run --release
```
Verifica che l'app si avvii senza crash.

**Test 2: Permessi**
- Verifica che i permessi per notifiche siano richiesti correttamente
- Controlla che la vibrazione funzioni

**Test 3: Firebase**
- Verifica che l'autenticazione funzioni
- Controlla che le notifiche push arrivino

### 4. Configurazioni iOS Modificate

**Info.plist:**
- ✅ Background modes aggiunti
- ✅ Permessi per notifiche configurati
- ✅ Configurazioni di stabilità aggiunte

**Firebase:**
- ✅ Configurazione iOS specifica
- ✅ Gestione errori migliorata

### 5. Debug Helper

Il file `debug_helper.dart` fornisce:
- Logging dettagliato
- Informazioni sulla piattaforma
- Controlli di stato Firebase
- Monitoraggio del ciclo di vita dell'app

### 6. Comandi Utili

**Pulizia e Rebuild:**
```bash
flutter clean
flutter pub get
cd ios && pod install && cd ..
flutter run --release
```

**Verifica Dependencies:**
```bash
flutter doctor
flutter pub deps
```

### 7. Controlli di Sicurezza

**Verifica che:**
- GoogleService-Info.plist sia presente
- Bundle ID sia corretto
- Certificati iOS siano validi
- Provisioning profile sia configurato

### 8. Log di Debug

I log ora includono:
- Stato inizializzazione Firebase
- Stato servizi di notifica
- Errori di autenticazione
- Informazioni piattaforma

### 9. Fallback Implementati

Se un servizio fallisce:
- ✅ L'app continua a funzionare
- ✅ I log mostrano l'errore specifico
- ✅ L'utente può ancora usare l'app

### 10. Contatti per Supporto

Se l'app continua a crashare:
1. Controlla i log in Xcode
2. Verifica la configurazione Firebase
3. Testa su dispositivo fisico (non simulatore)
4. Controlla i permessi iOS nelle impostazioni 