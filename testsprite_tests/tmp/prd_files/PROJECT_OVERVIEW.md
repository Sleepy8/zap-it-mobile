# Zap it - Project Overview

## 🚀 Idea del Progetto

**Zap it** è un'app mobile Flutter che permette agli utenti di inviare "zap" (vibrazioni personalizzate) ai propri amici. L'app combina messaggistica, notifiche push e un sistema di vibrazione unico per creare un'esperienza sociale interattiva.

### Funzionalità Principali

- **Sistema di Autenticazione**: Login/registrazione con Firebase Auth
- **Gestione Amici**: Aggiungere, rimuovere e gestire la lista amici
- **Sistema di Zap**: Inviare vibrazioni personalizzate agli amici
- **Notifiche Push**: Notifiche in tempo reale per nuovi zap
- **Leaderboard**: Classifica degli utenti più attivi
- **Profilo Utente**: Gestione del profilo e statistiche
- **Crittografia E2EE**: Messaggi crittografati end-to-end

## 🛠️ Tecnologie Utilizzate

- **Frontend**: Flutter/Dart
- **Backend**: Firebase
  - Firebase Auth (autenticazione)
  - Firestore (database)
  - Firebase Functions (logica server)
  - Firebase Storage (file)
  - Firebase Cloud Messaging (notifiche)
- **Crittografia**: Implementazione E2EE personalizzata
- **Piattaforme**: Android, iOS, Web

## 🔧 Problemi Attuali

### 1. Autologin Persistente
**Problema**: L'utente non rimane loggato tra le sessioni dell'app
- Implementato sistema di persistenza con SharedPreferences
- Problemi con la sincronizzazione tra Firebase Auth e stato locale
- Test in corso per verificare la persistenza su dispositivi fisici

### 2. Notifiche Push
**Problema**: Le notifiche non sempre arrivano correttamente
- Configurazione Firebase Cloud Messaging
- Gestione token di notifica
- Problemi con notifiche su background

### 3. Crittografia E2EE
**Problema**: Implementazione complessa della crittografia end-to-end
- Generazione e scambio di chiavi
- Crittografia messaggi in tempo reale
- Gestione delle chiavi perse

### 4. Compatibilità Dispositivi
**Problema**: Problemi su dispositivi Android più vecchi
- Gestione delle API di vibrazione
- Compatibilità con diverse versioni Android
- Ottimizzazione performance

## 📱 Struttura dell'App

### Schermate Principali
- **Splash Screen**: Schermata di caricamento iniziale
- **Login/Register**: Autenticazione utente
- **Home Screen**: Dashboard principale
- **Messages**: Chat e messaggi
- **Friends**: Gestione amici e richieste
- **Profile**: Profilo utente e impostazioni
- **Leaderboard**: Classifica utenti
- **Zap History**: Cronologia zap inviati/ricevuti

### Servizi
- **AuthService**: Gestione autenticazione Firebase
- **MessagesService**: Gestione messaggi e chat
- **FriendsService**: Gestione amici
- **NotificationService**: Gestione notifiche push
- **EncryptionService**: Crittografia E2EE
- **BackgroundService**: Servizi in background

## 🎯 Obiettivi Futuri

### Vibe Composer (Nuova Funzionalità)
Implementare una nuova sezione "Vibe Composer" con:
- **Interfaccia Moderna**: Design grafico eccezionale e moderno
- **Composizione Vibrazioni**: Creare pattern di vibrazione personalizzati
- **Anteprima in Tempo Reale**: Sentire la vibrazione mentre la si crea
- **Salvataggio Pattern**: Salvare e condividere pattern personalizzati
- **Integrazione Zap**: Usare i pattern creati negli zap

### Miglioramenti Tecnici
- Risolvere problemi di autologin
- Ottimizzare notifiche push
- Migliorare performance su dispositivi vecchi
- Completare implementazione E2EE

## 🔍 Test e Debug

### File di Test e Debug
- `LOGIN_DEBUG_GUIDE.md`: Guida debug autenticazione
- `NOTIFICATION_FIXES_SUMMARY.md`: Risoluzioni notifiche
- `E2EE_IMPLEMENTATION.md`: Documentazione crittografia
- `FINAL_TEST_GUIDE.md`: Guida test finale

### Configurazione Firebase
- `firebase.json`: Configurazione Firebase
- `functions/`: Cloud Functions
- `firebase_config_example.md`: Setup Firebase

## 📊 Stato Attuale

**Completato**:
- ✅ Struttura base dell'app
- ✅ Autenticazione Firebase
- ✅ Sistema di amici
- ✅ Messaggistica base
- ✅ Notifiche push (parzialmente)
- ✅ Crittografia E2EE (base)

**In Sviluppo**:
- 🔄 Persistenza autologin
- 🔄 Ottimizzazione notifiche
- 🔄 Compatibilità dispositivi
- 🔄 Vibe Composer (nuovo)

**Prossimi Passi**:
1. Risolvere problemi di autologin
2. Implementare Vibe Composer
3. Ottimizzare performance
4. Test completi su dispositivi fisici 