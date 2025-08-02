import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/messages_service.dart';
import '../widgets/custom_button.dart';
import '../theme.dart';
import 'main_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthServiceFirebaseImpl();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _authService.register(
        _emailController.text.trim(),
        _passwordController.text,
        _usernameController.text.trim(),
        _nameController.text.trim(),
      );
      
      if (success && mounted) {
        // Initialize E2EE after successful registration
        try {
          final messagesService = MessagesService();
          await messagesService.initializeE2EE();
        } catch (e) {
          
          // Continue anyway, E2EE can be set up later
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registrazione completata con successo!'),
            backgroundColor: AppTheme.limeAccent,
          ),
        );
        // Forza la navigazione manualmente
        
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Errore durante la registrazione'),
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
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      appBar: AppBar(
        title: const Text('Registrazione'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppTheme.limeAccent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.person_add_outlined,
                          size: 40,
                          color: AppTheme.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Crea Account',
                        style: Theme.of(context).textTheme.displaySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Inserisci i tuoi dati per registrarti',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),
                  
                  // Name field
                  TextFormField(
                    controller: _nameController,
                    keyboardType: TextInputType.name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nome completo',
                      prefixIcon: Icon(Icons.person_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Inserisci il tuo nome';
                      }
                      if (value.length < 2) {
                        return 'Il nome deve essere di almeno 2 caratteri';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Username field
                  TextFormField(
                    controller: _usernameController,
                    keyboardType: TextInputType.text,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixIcon: Icon(Icons.alternate_email),
                      hintText: 'es. mario_rossi',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Inserisci un username';
                      }
                      if (value.length < 3) {
                        return 'L\'username deve essere di almeno 3 caratteri';
                      }
                      if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
                        return 'L\'username può contenere solo lettere, numeri e underscore';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Email field
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
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                          .hasMatch(value)) {
                        return 'Inserisci un\'email valida';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Password field
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
                        return 'Inserisci una password';
                      }
                      if (value.length < 8) {
                        return 'La password deve essere di almeno 8 caratteri';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Confirm Password field
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: 'Conferma Password',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Conferma la password';
                      }
                      if (value != _passwordController.text) {
                        return 'Le password non coincidono';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  
                  // Register button
                  CustomButton(
                    text: 'Registrati',
                    onPressed: _register,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 16),
                  
                  // Security notice
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.limeAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.limeAccent.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.security,
                          color: AppTheme.limeAccent,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'I tuoi messaggi saranno protetti con crittografia end-to-end',
                            style: TextStyle(
                              color: AppTheme.limeAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Login link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Hai già un account? ',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).pop();
                        },
                        child: Text(
                          'Accedi',
                          style: TextStyle(
                            color: AppTheme.limeAccent,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
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
