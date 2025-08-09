# Firebase Storage Setup per Zap It

## 🔧 Configurazione Firebase Storage

### 1. Abilita Firebase Storage

1. **Vai su Firebase Console**: https://console.firebase.google.com/
2. **Seleziona il tuo progetto**
3. **Nel menu laterale**, clicca su "Storage"
4. **Clicca "Inizia"** se non è ancora abilitato
5. **Scegli le regole di sicurezza**:
   - Per sviluppo: "Inizia in modalità test"
   - Per produzione: "Blocca tutto"

### 2. Regole di Sicurezza Storage

Vai su **Storage > Rules** e sostituisci con:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Allow authenticated users to upload profile images
    match /profile_images/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Allow authenticated users to upload any image in their folder
    match /profile_images/{userId}/{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

### 3. Verifica Configurazione

1. **Controlla che Storage sia abilitato**:
   - Vai su Storage > Files
   - Dovresti vedere una pagina vuota (normale)

2. **Testa le regole**:
   - Vai su Storage > Rules
   - Clicca "Pubblica" per attivare le regole

### 4. Troubleshooting

#### Errore "object-not-found":
- ✅ **Causa**: Firebase Storage non abilitato
- ✅ **Soluzione**: Abilita Storage nel progetto Firebase

#### Errore "unauthorized":
- ✅ **Causa**: Regole di sicurezza troppo restrittive
- ✅ **Soluzione**: Usa le regole sopra indicate

#### Errore "bucket-not-found":
- ✅ **Causa**: Storage non inizializzato
- ✅ **Soluzione**: Clicca "Inizia" in Storage

### 5. Test Upload

Dopo la configurazione:

1. **Vai nell'app**
2. **Profilo > Cambia immagine**
3. **Seleziona un'immagine**
4. **L'upload dovrebbe funzionare**

### 6. Debug

Se continui ad avere problemi:

1. **Controlla i log** nell'app per errori specifici
2. **Verifica Firebase Console** > Storage > Files
3. **Controlla le regole** in Storage > Rules
4. **Assicurati** che l'utente sia autenticato

### 7. Regole Alternative (per sviluppo)

Se vuoi regole più permissive per testare:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

⚠️ **ATTENZIONE**: Queste regole permettono a tutti gli utenti autenticati di leggere/scrivere tutto. Usa solo per sviluppo!

## 🚀 Risultato

Dopo questa configurazione:
- ✅ Upload immagini funzionante
- ✅ Sicurezza appropriata
- ✅ Debug dettagliato
- ✅ Gestione errori robusta 