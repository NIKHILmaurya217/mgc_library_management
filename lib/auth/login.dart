import 'package:flutter/material.dart';
import 'auth_services/auth_service.dart';
import '../core/constants/app_colors.dart';
import 'register.dart';
import '../core/theme/app_theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final user = await AuthService().signIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      if (user == null && mounted) {
        setState(() => _errorMessage = 'Invalid email or password. Please try again.');
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString();
        if (errorMsg.startsWith('Exception: ')) {
          errorMsg = errorMsg.substring(11);
        }
        setState(() => _errorMessage = errorMsg);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.color.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                // Logo
                Center(
                  child: Hero(
                    tag: 'app_logo',
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.color.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: context.color.border, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: context.color.accent.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          )
                        ]
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/MGC_logo.png',
                          width: 80,
                          height: 80,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Header
                Center(
                  child: Column(
                    children: [
                      Text(
                        'Welcome Back',
                        style: TextStyle(
                          color: context.color.textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in to Library Management System',
                        style: TextStyle(color: context.color.textSecondary, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                // Email
                _buildLabel('EMAIL ADDRESS'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: context.color.textPrimary),
                  decoration: _inputDecoration('admin@library.com', Icons.email_outlined),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email is required';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                // Password
                _buildLabel('PASSWORD'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: TextStyle(color: context.color.textPrimary),
                  decoration: _inputDecoration('••••••••', Icons.lock_outline).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: context.color.textSecondary,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (v.length < 6) return 'Password must be at least 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                // Error message
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_errorMessage!, style: const TextStyle(color: AppColors.error, fontSize: 13))),
                      ],
                    ),
                  ),
                const SizedBox(height: 32),
                // Sign In Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.color.accent,
                      foregroundColor: context.color.background,
                      disabledBackgroundColor: context.color.accent.withValues(alpha: 0.3),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(color: context.color.background, strokeWidth: 2.5),
                          )
                        : const Text(
                            'SIGN IN',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                          ),
                  ),
                ),
                const SizedBox(height: 40),
                // Register link
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const Register()),
                    ),
                    child: Text(
                      "Don't have an account? Register",
                      style: TextStyle(color: context.color.accent, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Footer
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(width: 40, height: 1, color: context.color.border),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('LIBRARY RFID SYSTEM', style: TextStyle(color: context.color.textSecondary, fontSize: 10, letterSpacing: 1.5)),
                      ),
                      Container(width: 40, height: 1, color: context.color.border),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(color: context.color.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: context.color.textSecondary),
      prefixIcon: Icon(icon, color: context.color.textSecondary, size: 20),
      filled: true,
      fillColor: context.color.surface,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: context.color.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: context.color.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error),
      ),
    );
  }
}
