import 'package:flutter/material.dart';
import 'auth_services/auth_service.dart';
import '../core/constants/app_colors.dart';
import '../core/theme/app_theme.dart';

const _kAdminCode = 'MGC@ADMIN2026';

class Register extends StatefulWidget {
  const Register({super.key});

  @override
  State<Register> createState() => _RegisterState();
}

class _RegisterState extends State<Register> {
  final _formKey = GlobalKey<FormState>();

  final _adminCodeController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _adminCodeController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_adminCodeController.text.trim() != _kAdminCode) {
      setState(() => _errorMessage = 'Invalid admin code.');
      return;
    }
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      await AuthService().register(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      if (mounted) Navigator.pop(context);
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
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
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
                const SizedBox(height: 24),
                // Header
                Center(
                  child: Column(
                    children: [
                      Text(
                        'Create Account',
                        style: TextStyle(
                          color: context.color.textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Register for Library Management System',
                        style: TextStyle(color: context.color.textSecondary, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                // Form Fields
                _buildLabel('ADMIN CODE'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _adminCodeController,
                  hint: 'Enter admin invite code',
                  icon: Icons.admin_panel_settings_outlined,
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('FIRST NAME'),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _firstNameController,
                            hint: 'First name',
                            icon: Icons.person_outline,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('LAST NAME'),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _lastNameController,
                            hint: 'Last name',
                            icon: Icons.person_outline,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                _buildLabel('EMAIL ADDRESS'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _emailController,
                  hint: 'admin@library.com',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  isEmail: true,
                ),
                const SizedBox(height: 16),
                
                _buildLabel('MOBILE NUMBER'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _mobileController,
                  hint: 'Enter mobile number',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                
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
                
                // Register Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _register,
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
                            'CREATE ACCOUNT',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Login link
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "ALREADY HAVE AN ACCOUNT? SIGN IN",
                      style: TextStyle(color: context.color.accent, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    bool isEmail = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: TextStyle(color: context.color.textPrimary),
      decoration: _inputDecoration(hint, icon),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'This field is required';
        if (isEmail && !v.contains('@')) return 'Enter a valid email';
        return null;
      },
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
