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
  final _nameKey = GlobalKey<FormFieldState>();
  final _usernameKey = GlobalKey<FormFieldState>();
  final _emailKey = GlobalKey<FormFieldState>();
  final _passwordKey = GlobalKey<FormFieldState>();
  final _confirmPasswordKey = GlobalKey<FormFieldState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthServiceFirebaseImpl();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _usernameExists = false;
  bool _isCheckingUsername = false;
  bool _emailExists = false;
  bool _isCheckingEmail = false;
  bool _hasInteracted = false; // Track if user has interacted with form
  bool _showAllErrors = false; // Track if we should show all validation errors

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _checkUsername(String username) async {
    if (username.length < 3) {
      setState(() {
        _usernameExists = false;
        _isCheckingUsername = false;
      });
      return;
    }

    setState(() {
      _isCheckingUsername = true;
    });

    try {
      final usernameQuery = await _authService.checkUsernameExists(username);
      setState(() {
        _usernameExists = usernameQuery;
        _isCheckingUsername = false;
      });
    } catch (e) {
      setState(() {
        _usernameExists = false;
        _isCheckingUsername = false;
      });
    }
  }

  Future<void> _checkEmail(String email) async {
    if (email.isEmpty || !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      setState(() {
        _emailExists = false;
        _isCheckingEmail = false;
      });
      return;
    }

    setState(() {
      _isCheckingEmail = true;
    });

    try {
      final emailQuery = await _authService.checkEmailExists(email);
      setState(() {
        _emailExists = emailQuery;
        _isCheckingEmail = false;
      });
    } catch (e) {
      setState(() {
        _emailExists = false;
        _isCheckingEmail = false;
      });
    }
  }

  Future<void> _register() async {
    // Set hasInteracted to true when user tries to register
    _hasInteracted = true;
    _showAllErrors = true; // Show all validation errors when registering
    
    if (!_formKey.currentState!.validate()) return;
    
    // Controllo finale prima della registrazione
    setState(() {
      _isLoading = true;
    });

    try {
      // Controlla username
      final usernameExists = await _authService.checkUsernameExists(_usernameController.text.trim());
      if (usernameExists) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Username già in uso. Scegli un username diverso.'),
            backgroundColor: AppTheme.errorColor,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      // Controlla email
      final emailExists = await _authService.checkEmailExists(_emailController.text.trim());
      if (emailExists) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Email già registrata. Usa un\'email diversa.'),
            backgroundColor: AppTheme.errorColor,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      // Se arriviamo qui, username ed email sono disponibili
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
            content: Text('✅ Registrazione completata con successo!'),
            backgroundColor: AppTheme.limeAccent,
            duration: Duration(seconds: 3),
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
        String errorMessage = '❌ Errore durante la registrazione';
        
        // Handle specific error cases
        if (e.toString().contains('Email già registrata')) {
          errorMessage = '❌ Email già registrata. Usa un\'email diversa.';
        } else if (e.toString().contains('Username già in uso')) {
          errorMessage = '❌ Username già in uso (anche con maiuscole/minuscole diverse). Scegli un username diverso.';
        } else if (e.toString().contains('weak-password')) {
          errorMessage = '❌ La password deve essere di almeno 8 caratteri';
        } else if (e.toString().contains('invalid-email')) {
          errorMessage = '❌ Email non valida';
        } else if (e.toString().contains('network')) {
          errorMessage = '❌ Errore di connessione. Verifica la tua connessione internet.';
        } else {
          errorMessage = '❌ Errore: ${e.toString()}';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 4),
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
                    key: _nameKey,
                    controller: _nameController,
                    keyboardType: TextInputType.name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nome completo',
                      prefixIcon: Icon(Icons.person_outlined),
                    ),
                    onChanged: (value) {
                      _hasInteracted = true;
                      // Only validate this specific field
                      _nameKey.currentState?.validate();
                    },
                    validator: (value) {
                      // Only show errors if user has interacted or we're showing all errors
                      if (!_hasInteracted && !_showAllErrors) return null;
                      
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
                    key: _usernameKey,
                    controller: _usernameController,
                    keyboardType: TextInputType.text,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      prefixIcon: const Icon(Icons.alternate_email),
                      hintText: 'es. mario_rossi',
                      suffixIcon: _isCheckingUsername 
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : _usernameExists 
                              ? const Icon(Icons.error, color: Colors.red)
                              : null,
                      errorText: _usernameExists ? 'Username già in uso' : null,
                    ),
                    onChanged: (value) {
                      _hasInteracted = true;
                      // Reset username exists state when user starts typing
                      if (_usernameExists) {
                        setState(() {
                          _usernameExists = false;
                          _isCheckingUsername = false;
                        });
                      }
                      if (value.length >= 3) {
                        _checkUsername(value);
                      } else {
                        setState(() {
                          _usernameExists = false;
                          _isCheckingUsername = false;
                        });
                      }
                      // Only validate this specific field
                      _usernameKey.currentState?.validate();
                    },
                    onEditingComplete: () {
                      if (_usernameController.text.length >= 3) {
                        _checkUsername(_usernameController.text);
                      }
                    },
                    validator: (value) {
                      // Only show errors if user has interacted or we're showing all errors
                      if (!_hasInteracted && !_showAllErrors) return null;
                      
                      if (value == null || value.isEmpty) {
                        return 'Inserisci un username';
                      }
                      if (value.length < 3) {
                        return 'L\'username deve essere di almeno 3 caratteri';
                      }
                      if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
                        return 'L\'username può contenere solo lettere, numeri e underscore';
                      }
                      if (_usernameExists) {
                        return 'Username già in uso';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Email field
                  TextFormField(
                    key: _emailKey,
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: const Icon(Icons.email_outlined),
                      suffixIcon: _isCheckingEmail 
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : _emailExists 
                              ? const Icon(Icons.error, color: Colors.red)
                              : null,
                      errorText: _emailExists ? 'Email già registrata' : null,
                    ),
                    onChanged: (value) {
                      _hasInteracted = true;
                      // Reset email exists state when user starts typing
                      if (_emailExists) {
                        setState(() {
                          _emailExists = false;
                          _isCheckingEmail = false;
                        });
                      }
                      if (value.isNotEmpty && RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        _checkEmail(value);
                      } else {
                        setState(() {
                          _emailExists = false;
                          _isCheckingEmail = false;
                        });
                      }
                      // Only validate this specific field
                      _emailKey.currentState?.validate();
                    },
                    onEditingComplete: () {
                      if (_emailController.text.isNotEmpty && 
                          RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(_emailController.text)) {
                        _checkEmail(_emailController.text);
                      }
                    },
                    validator: (value) {
                      // Only show errors if user has interacted or we're showing all errors
                      if (!_hasInteracted && !_showAllErrors) return null;
                      
                      if (value == null || value.isEmpty) {
                        return 'Inserisci la tua email';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                          .hasMatch(value)) {
                        return 'Inserisci un\'email valida';
                      }
                      if (_emailExists) {
                        return 'Email già registrata';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Password field
                  TextFormField(
                    key: _passwordKey,
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
                    onChanged: (value) {
                      _hasInteracted = true;
                      // Only validate this specific field
                      _passwordKey.currentState?.validate();
                    },
                    validator: (value) {
                      // Only show errors if user has interacted or we're showing all errors
                      if (!_hasInteracted && !_showAllErrors) return null;
                      
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
                    key: _confirmPasswordKey,
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
                    onChanged: (value) {
                      _hasInteracted = true;
                      // Only validate this specific field
                      _confirmPasswordKey.currentState?.validate();
                    },
                    validator: (value) {
                      // Only show errors if user has interacted or we're showing all errors
                      if (!_hasInteracted && !_showAllErrors) return null;
                      
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
