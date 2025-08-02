# Zap It Mobile

Un'app Flutter moderna e minimale con design scuro e accenti verde lime (#CFFF04).

## Caratteristiche

- **Design Scuro**: Sfondo nero carbone (#121212) con accenti verde lime
- **Autenticazione Firebase**: Login e registrazione con email/password
- **Firestore**: Salvataggio dati utente nel cloud
- **UI Moderna**: Componenti con animazioni e transizioni fluide
- **Responsive**: Adatta a dispositivi mobili e desktop
- **Cross-Platform**: Funziona su Android, iOS, Windows (modalità mock)

## Struttura del Progetto

```
lib/
├── main.dart              # Punto di ingresso con Firebase init
├── theme.dart             # Definizione tema dark con lime accent
├── screens/
│   ├── splash_screen.dart # Schermata di benvenuto animata
│   ├── login_screen.dart  # Schermata di login
│   ├── register_screen.dart # Schermata di registrazione
│   └── home_screen.dart   # Schermata principale post-login
├── services/
│   ├── auth_service.dart      # Servizio di autenticazione principale
│   ├── auth_service_firebase.dart # Implementazione Firebase
│   └── auth_service_mock.dart # Implementazione mock per Windows/Web
├── widgets/
│   └── custom_button.dart # Bottone personalizzato con animazioni
├── firebase_init.dart     # Inizializzazione Firebase
└── firebase_init_mock.dart # Mock per Windows/Web
```

## Installazione

### Prerequisiti

- Flutter SDK (versione 3.0.0 o superiore)
- Android Studio / VS Code

### Passi

1. **Clona il repository**
   ```bash
   git clone <repository-url>
   cd zap_it_mobile
   ```

2. **Installa le dipendenze**
   ```bash
   flutter pub get
   ```

3. **Esegui l'app**
   ```bash
   flutter run
   ```

## Modalità di Sviluppo

### Modalità Mock (Windows/Web)
L'app funziona in modalità mock su Windows e Web, permettendo di testare l'interfaccia senza Firebase:

- Login/registrazione simulata
- Dati utente mock
- Nessuna dipendenza Firebase

### Modalità Firebase (Android/iOS)
Per utilizzare Firebase su Android/iOS:

1. **Abilita Firebase**:
   ```bash
   # Copia il file pubspec_firebase.yaml
   cp pubspec_firebase.yaml pubspec.yaml
   flutter pub get
   ```

2. **Configura Firebase**:
   - Crea progetto su Firebase Console
   - Abilita Authentication (Email/Password)
   - Crea database Firestore
   - Aggiungi file `google-services.json` (Android)
   - Aggiungi file `GoogleService-Info.plist` (iOS)

## Configurazione Firebase

### 1. Crea un progetto Firebase

1. Vai su [Firebase Console](https://console.firebase.google.com/)
2. Crea un nuovo progetto
3. Abilita Authentication con Email/Password
4. Crea un database Firestore

### 2. Configura l'app Android

1. Aggiungi un'app Android nel progetto Firebase
2. Scarica il file `google-services.json`
3. Posizionalo in `android/app/google-services.json`

### 3. Configura l'app iOS (opzionale)

1. Aggiungi un'app iOS nel progetto Firebase
2. Scarica il file `GoogleService-Info.plist`
3. Posizionalo in `ios/Runner/GoogleService-Info.plist`

### 4. Regole Firestore

Nel database Firestore, vai su "Regole" e imposta:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## Funzionalità

### Splash Screen
- Animazione del logo Zap It
- Transizione automatica al login

### Login
- Validazione email e password
- Gestione errori Firebase
- Link alla registrazione

### Registrazione
- Validazione campi (nome, email, password)
- Password minima 8 caratteri
- Creazione utente in Firebase Auth e Firestore

### Home Screen
- Benvenuto personalizzato con nome utente
- Statistiche placeholder
- Sezione per contenuti futuri
- Logout

## Tema e Design

### Colori
- **Primario**: #121212 (nero carbone)
- **Secondario**: #181818 (grigio scuro)
- **Accento**: #CFFF04 (verde lime)
- **Testo**: #FFFFFF (bianco)
- **Testo secondario**: #B3B3B3 (grigio chiaro)

### Componenti
- Pulsanti con angoli arrotondati (8px)
- Input con bordo lime quando attivo
- Animazioni di press/hover
- Transizioni fluide

## Struttura Database Firestore

### Collection: `users`
```json
{
  "userId": "string",
  "name": "string",
  "email": "string",
  "created_at": "timestamp"
}
```

## Risoluzione Problemi

### Errore di compilazione su Windows
Se ricevi errori di compilazione su Windows, l'app è configurata per funzionare in modalità mock. Questo è normale e permette di testare l'interfaccia senza Firebase.

### Abilitare Firebase
Per abilitare Firebase su Windows:

1. Copia `pubspec_firebase.yaml` in `pubspec.yaml`
2. Esegui `flutter pub get`
3. Configura Firebase seguendo le istruzioni sopra

## Sviluppo Futuro

- [ ] Aggiunta di funzionalità CRUD per dati personalizzati
- [ ] Implementazione di notifiche push
- [ ] Aggiunta di temi personalizzabili
- [ ] Integrazione con servizi esterni
- [ ] Test unitari e di integrazione

## Licenza

Questo progetto è rilasciato sotto licenza MIT. 