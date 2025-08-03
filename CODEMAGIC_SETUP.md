# Codemagic Setup - Zap It Mobile

## Configurazione Corretta per iOS

### 1. Build Arguments da Configurare

**Android:**
```
--release
--target=lib/main_prod.dart
```

**iOS:**
```
--release
--target=lib/main_prod.dart
```

**Web:**
```
--release
--target=lib/main_prod.dart
```

### 2. Impostazioni Codemagic da Modificare

#### Build Settings:
- **Mode:** Release (non Debug)
- **Flutter version:** Stable
- **Xcode version:** Latest (16.4)
- **CocoaPods version:** Default

#### iOS Code Signing:
- **iOS code signing:** Enabled
- **Select code signing method:** Automatic
- **App Store Connect:** Enabled per TestFlight

#### Environment Variables da Aggiungere:
```
FLUTTER_VERSION=stable
BUNDLE_ID=com.example.zapItMobile
XCODE_PROJECT=ios/Runner.xcworkspace
XCODE_SCHEME=Runner
```

### 3. File di Configurazione

#### GoogleService-Info.plist
- ✅ Presente in `ios/Runner/GoogleService-Info.plist`
- ✅ Configurazione Firebase corretta

#### exportOptions.plist
- ✅ Configurato per App Store
- ✅ exportOptions-adhoc.plist per distribuzione ad-hoc

#### main_prod.dart
- ✅ Creato per build di produzione
- ✅ Ottimizzazioni per iOS
- ✅ Logging ridotto in produzione

### 4. Workflow Codemagic

#### iOS Workflow:
```yaml
ios-workflow:
  name: iOS Build
  environment:
    vars:
      XCODE_PROJECT: "ios/Runner.xcworkspace"
      XCODE_SCHEME: "Runner"
      BUNDLE_ID: "com.example.zapItMobile"
      FLUTTER_VERSION: "stable"
    flutter: stable
    xcode: latest
    cocoapods: default
  scripts:
    - name: Set up code signing settings on Xcode project
      script: |
        keychain initialize
        app-store-connect fetch-signing-files "com.example.zapItMobile" --type IOS_APP_STORE --create
        xcode-project use-profiles
    - name: Get Flutter packages
      script: flutter pub get
    - name: Flutter build ipa for App Store
      script: |
        flutter build ipa --release \
          --export-options-plist=ios/exportOptions.plist \
          --target=lib/main_prod.dart
    - name: Build IPA for ad-hoc distribution
      script: |
        flutter build ipa --release \
          --export-options-plist=ios/exportOptions-adhoc.plist \
          --target=lib/main_prod.dart
```

### 5. Passi per Configurare Codemagic

1. **Vai su Codemagic e accedi al progetto**
2. **Modifica le impostazioni di build:**
   - Cambia Mode da Debug a Release
   - Aggiorna i build arguments per iOS
   - Abilita iOS code signing

3. **Configura le variabili d'ambiente:**
   - Aggiungi FLUTTER_VERSION=stable
   - Verifica BUNDLE_ID=com.example.zapItMobile

4. **Abilita App Store Connect:**
   - Vai su Distribution → App Store Connect
   - Abilita "iOS code signing"
   - Seleziona "Automatic" per code signing method

5. **Testa il build:**
   - Avvia un nuovo build
   - Verifica che non ci siano errori
   - Controlla i log per problemi

### 6. Troubleshooting

#### Se il build fallisce:
1. **Controlla i log di build**
2. **Verifica che main_prod.dart sia presente**
3. **Controlla le variabili d'ambiente**
4. **Verifica la configurazione Firebase**

#### Se l'app crasha su iPhone:
1. **Usa il build di produzione (main_prod.dart)**
2. **Verifica i certificati iOS**
3. **Controlla i permessi nell'Info.plist**
4. **Testa su dispositivo fisico**

### 7. Build Arguments Corretti

**Sostituisci le build arguments attuali con:**

**Android:**
```
--release
--target=lib/main_prod.dart
```

**iOS:**
```
--release
--target=lib/main_prod.dart
```

**Web:**
```
--release
--target=lib/main_prod.dart
```

### 8. Verifica Finale

Dopo aver configurato tutto:
1. ✅ Build arguments corretti
2. ✅ Mode: Release
3. ✅ iOS code signing abilitato
4. ✅ main_prod.dart presente
5. ✅ GoogleService-Info.plist configurato
6. ✅ exportOptions.plist configurato

### 9. Test del Build

```bash
# Test locale
flutter build ios --release --target=lib/main_prod.dart

# Verifica che l'app si avvii senza crash
flutter run --release --target=lib/main_prod.dart
``` 