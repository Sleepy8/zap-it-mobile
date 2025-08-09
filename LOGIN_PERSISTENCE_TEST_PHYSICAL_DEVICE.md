# Test Login Persistente - Dispositivo Fisico

## ✅ Pronto per il Test

Ora che hai un dispositivo fisico collegato ad Android Studio, puoi testare il login persistente. Il sistema ora salva automaticamente il login **come Instagram** - senza checkbox.

## 🧪 Procedura di Test

### Test 1: Primo Login (Prima Installazione)

**⚠️ COMPORTAMENTO NORMALE**: Al primo avvio su un dispositivo fisico, l'app chiederà il login. Questo è normale!

1. **Installa l'app sul dispositivo fisico**
   ```bash
   flutter run
   ```

2. **Primo login** (l'app chiederà le credenziali)
   - Email: `mariorossi@gmail.com`
   - Password: `Prova123`
   - Clicca "Accedi"
   - **NON serve selezionare nulla** - il login viene salvato automaticamente

3. **Verifica che l'app ti porti alla home**
   - Dovresti vedere la schermata principale dell'app

### Test 2: Riavvio app (senza logout)

1. **Chiudi completamente l'app**
   - Vai nelle app recenti (quadrato)
   - Swipe via l'app Zap It
   - Oppure: Impostazioni → App → Zap It → Forza chiusura

2. **Riapri l'app**
   - Tocca l'icona Zap It

3. **RISULTATO ATTESO**: 
   - ✅ L'app dovrebbe portarti direttamente alla home
   - ✅ NON dovrebbe mostrare la schermata di login

### Test 3: Riavvio telefono (senza logout)

1. **Riavvia completamente il telefono**
   - Spegni e riaccendi il dispositivo

2. **Apri l'app**
   - Tocca l'icona Zap It

3. **RISULTATO ATTESO**:
   - ✅ L'app dovrebbe portarti direttamente alla home
   - ✅ NON dovrebbe mostrare la schermata di login

### Test 4: Riavvio app (con logout)

1. **Vai nel profilo**
   - Tocca l'icona profilo in basso

2. **Fai logout**
   - Tocca "Logout"

3. **Chiudi completamente l'app**
   - Swipe via dalle app recenti

4. **Riapri l'app**

5. **RISULTATO ATTESO**:
   - ✅ L'app dovrebbe mostrare la schermata di login

## 🔍 Debug e Verifica

### Controllo SharedPreferences

Se vuoi verificare che i dati siano salvati correttamente:

1. **Vai nel profilo**
2. **Tocca "Test Login Persistence"** (se disponibile)
3. **Controlla i log in Android Studio**

### Log da controllare in Android Studio:

```
🔐 LOGIN STATE SAVED:
🔐 User ID: [user_id]
🔐 Email: mariorossi@gmail.com
🔐 isLoggedIn: true
```

## 🚀 Login Rapido (DEV MODE)

Per testare più velocemente, usa i pulsanti di login rapido:

- **Mario**: Login automatico (salvato automaticamente)
- **Francesco**: Login automatico (salvato automaticamente)

## ⚠️ Note Importanti

### ✅ Comportamento come Instagram:
- **Primo login**: L'app chiede le credenziali (normale)
- **Login automatico**: Il login viene salvato automaticamente
- **Nessuna checkbox**: Non serve selezionare "Rimani loggato"
- **Sessione permanente**: Rimane loggato fino al logout manuale
- **Riavvio telefono**: La sessione persiste anche dopo il riavvio

### 🔧 Perché chiede il login al primo avvio:

1. **Prima installazione**: Firebase Auth non ha ancora una sessione
2. **Comportamento normale**: Come Instagram, WhatsApp, ecc.
3. **Dopo il primo login**: La sessione viene salvata automaticamente
4. **Riavvii successivi**: L'app va direttamente alla home

### ✅ Vantaggi del Dispositivo Fisico:
- **File system reale**: I dati persistono correttamente
- **Comportamento realistico**: Come nell'uso reale
- **Test completo**: Riavvio telefono, chiusura app, ecc.

### 🔧 Se il test non funziona:

1. **Verifica i permessi**:
   - L'app deve avere permessi di storage
   - Controlla le impostazioni del dispositivo

2. **Pulisci i dati**:
   - Impostazioni → App → Zap It → Storage → Cancella dati
   - Reinstalla l'app

3. **Controlla i log**:
   - Apri Android Studio → Logcat
   - Filtra per "Zap It" o il nome del pacchetto

## 📱 Test delle Notifiche ZAP

Dopo aver testato il login persistente, puoi anche testare le notifiche ZAP invisibili:

1. **Fai login su due dispositivi**
2. **Invia uno ZAP da un dispositivo all'altro**
3. **Verifica che arrivi solo la vibrazione senza notifica visibile**

## 🎯 Risultato Atteso

Con un dispositivo fisico, il login persistente dovrebbe funzionare perfettamente:
- ✅ **Primo login** (normale, come Instagram)
- ✅ **Login automatico** dopo il primo accesso
- ✅ **Sessione permanente** fino al logout manuale
- ✅ **Persistenza** anche dopo riavvio telefono
- ✅ **Comportamento moderno** come le app social 