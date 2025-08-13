import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/custom_button.dart';
import '../widgets/animated_logo.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthServiceFirebaseImpl();
  
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _authService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
      
      if (success && mounted) {
        // Forza la navigazione manualmente
        
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email o password non validi'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    // Adattamento specifico per dispositivi molto piccoli (come Redmi Go)
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Redmi Go ha 1280x720, quindi se l'altezza è molto piccola
    final isVerySmallDevice = screenHeight < 650;
    
    // Dimensioni adattive solo per dispositivi molto piccoli
    final logoSize = isVerySmallDevice ? screenWidth * 0.12 : MediaQuery.of(context).size.width * 0.25;
    final topSpacing = isVerySmallDevice ? 4.0 : 20.0;
    final titleSpacing = isVerySmallDevice ? screenHeight * 0.005 : MediaQuery.of(context).size.height * 0.02;
    final subtitleSpacing = isVerySmallDevice ? screenHeight * 0.003 : MediaQuery.of(context).size.height * 0.01;
    final formSpacing = isVerySmallDevice ? screenHeight * 0.010 : MediaQuery.of(context).size.height * 0.04;
    final fieldSpacing = isVerySmallDevice ? screenHeight * 0.008 : MediaQuery.of(context).size.height * 0.02;
    final buttonSpacing = isVerySmallDevice ? screenHeight * 0.010 : MediaQuery.of(context).size.height * 0.03;
    final linkSpacing = isVerySmallDevice ? screenHeight * 0.008 : MediaQuery.of(context).size.height * 0.02;
    final padding = isVerySmallDevice ? 8.0 : 24.0;

    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Top spacer - molto ridotto per dispositivi molto piccoli
                  SizedBox(height: isVerySmallDevice ? MediaQuery.of(context).size.height * 0.02 : MediaQuery.of(context).size.height * 0.15),
                
                  // Logo and title
                  AnimatedLogo(
                    size: logoSize,
                    isSplashScreen: false,
                    showText: true,
                  ),
                  SizedBox(height: titleSpacing),
                  Text(
                    'Benvenuto',
                    style: Theme.of(context).textTheme.displaySmall,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: subtitleSpacing),
                  Text(
                    'Accedi al tuo account',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: formSpacing),
                  
                  // Form fields
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Inserisci la tua email';
                      }
                      if (!RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$')
                          .hasMatch(value)) {
                        return 'Inserisci un\'email valida';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: fieldSpacing),
                  
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Inserisci la password';
                      }
                      if (value.length < 6) {
                        return 'La password deve essere di almeno 6 caratteri';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: buttonSpacing),
                  
                  // Login button
                  CustomButton(
                    text: 'Accedi',
                    onPressed: _signIn,
                    isLoading: _isLoading,
                  ),
                  SizedBox(height: linkSpacing),
                  
                  // Register link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Non hai un account? ',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).pushNamed('/register');
                        },
                        child: Text(
                          'Registrati',
                          style: TextStyle(
                            color: AppTheme.limeAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 
