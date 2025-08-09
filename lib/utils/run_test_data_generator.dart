import 'package:flutter/material.dart';
import 'test_data_generator.dart';

// Script per generare dati di test
// Puoi eseguire questo script dalla console o creare un pulsante nell'app

class TestDataGeneratorRunner {
  
  // Metodo principale per generare utenti di test
  static Future<void> generateTestData() async {
    try {
      // Genera 20 utenti di test con nomi italiani
      await TestDataGenerator.generateTestUsers(count: 20);
      
      print('\n🎉 Generazione completata!');
      print('📱 Ora accedi all\'app con uno degli account generati per vedere la home popolata.');
      
    } catch (e) {
      print('❌ Errore durante la generazione: $e');
    }
  }

  // Metodo per pulire tutti gli utenti di test
  static Future<void> cleanupTestData() async {
    try {
      await TestDataGenerator.cleanupTestUsers();
      print('\n🧹 Pulizia completata!');
    } catch (e) {
      print('❌ Errore durante la pulizia: $e');
    }
  }

  // Metodo per generare solo 5 utenti (più veloce per test rapidi)
  static Future<void> generateQuickTestData() async {
    try {
      await TestDataGenerator.generateTestUsers(count: 5);
      print('\n⚡ Generazione rapida completata!');
    } catch (e) {
      print('❌ Errore durante la generazione rapida: $e');
    }
  }
}

// Esempio di utilizzo:
// 
// 1. Per generare 20 utenti di test:
//    await TestDataGeneratorRunner.generateTestData();
//
// 2. Per generare solo 5 utenti (più veloce):
//    await TestDataGeneratorRunner.generateQuickTestData();
//
// 3. Per pulire tutti gli utenti di test:
//    await TestDataGeneratorRunner.cleanupTestData();
//
// 4. Per eseguire dalla console Flutter:
//    flutter run -d chrome --dart-define=FLUTTER_WEB_USE_SKIA=true
//    Poi nella console del browser:
//    await TestDataGeneratorRunner.generateTestData();

