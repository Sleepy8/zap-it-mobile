import 'package:flutter/material.dart';
import '../theme.dart';

class TestScreen extends StatelessWidget {
  const TestScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Test Screen'),
        backgroundColor: AppTheme.primaryDark,
        titleTextStyle: TextStyle(color: AppTheme.textPrimary),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: AppTheme.background,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Test icon
            Icon(
              Icons.check_circle,
              size: 100,
              color: AppTheme.limeAccent,
            ),
            const SizedBox(height: 32),
            
            // Test text
            Text(
              'Flutter is working!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            
            Text(
              'If you can see this, the app is rendering correctly',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            // Test button
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Button pressed!',
                      style: TextStyle(color: AppTheme.primaryDark),
                    ),
                    backgroundColor: AppTheme.limeAccent,
                  ),
                );
              },
              child: Text('Test Button'),
            ),
            const SizedBox(height: 16),
            
            // Color test squares
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  color: AppTheme.primaryDark,
                  child: Center(
                    child: Text(
                      '1',
                      style: TextStyle(color: AppTheme.textPrimary),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 50,
                  height: 50,
                  color: AppTheme.surfaceDark,
                  child: Center(
                    child: Text(
                      '2',
                      style: TextStyle(color: AppTheme.textPrimary),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 50,
                  height: 50,
                  color: AppTheme.limeAccent,
                  child: Center(
                    child: Text(
                      '3',
                      style: TextStyle(color: AppTheme.primaryDark),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            
            // Platform info
            Text(
              'Platform: ${Theme.of(context).platform}',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
