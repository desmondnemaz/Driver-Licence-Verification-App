import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:driver_license_verifier_app/theme/app_colors.dart';

import 'package:driver_license_verifier_app/core/services/supabase_service.dart';

class AuthScreen extends StatefulWidget {
  final String role; // 'VID_REGISTRAR', 'POLICE_OFFICER', etc.

  const AuthScreen({super.key, required this.role});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _ecNumberController = TextEditingController();
  final _stationController = TextEditingController();

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    bool success = false;
    String message = '';

    if (_isLogin) {
      final error = await SupabaseService.signIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      if (error != null) {
        success = false;
        message = error;
      } else {
        success = true;
      }
    } else {
      success = await SupabaseService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        fullName: _fullNameController.text.trim(),
        ecNumber: _ecNumberController.text.trim(),
        role: widget.role,
        station: _stationController.text.trim(),
      );
      if (success) {
        message = 'Registration successful! Wait for admin approval.';
        setState(() => _isLogin = true);
      } else {
        message = 'Registration failed. Try again.';
      }
    }

    setState(() => _isLoading = false);

    if (success && _isLogin) {
      final profile = await SupabaseService.getCurrentProfile();
      if (!mounted) return;

      if (profile != null && profile['is_approved'] == true) {
        Navigator.pop(context, true); // Success
      } else if (profile == null) {
        await SupabaseService.signOut();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile not found. Please contact admin.')),
        );
      } else {
        await SupabaseService.signOut();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account waiting for admin approval (is_approved=false)')),
        );
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleName = widget.role.replaceAll('_', ' ');

    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? 'Login as $roleName' : 'Register as $roleName')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _isLogin ? 'Welcome Back' : 'Create Account',
                    style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  if (!_isLogin) ...[
                    _buildField(_fullNameController, 'Full Name', Icons.person_outline),
                    const SizedBox(height: 16),
                    _buildField(_ecNumberController, 'EC Number', Icons.badge_outlined),
                    const SizedBox(height: 16),
                    _buildField(_stationController, 'Station / Location', Icons.location_on_outlined),
                    const SizedBox(height: 16),
                  ],
                  _buildField(_emailController, 'Email', Icons.email_outlined),
                  const SizedBox(height: 16),
                  _buildField(
                    _passwordController, 
                    'Password', 
                    Icons.lock_outline, 
                    obscure: _obscurePassword,
                    isPassword: true,
                    onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  if (!_isLogin) ...[
                    const SizedBox(height: 16),
                    _buildField(
                      _confirmPasswordController,
                      'Confirm Password',
                      Icons.lock_reset_rounded,
                      obscure: _obscurePassword,
                      isPassword: true,
                      onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
                      validator: (val) {
                        if (val != _passwordController.text) return 'Passwords do not match';
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 32),
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          onPressed: _handleSubmit,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: AppColors.sadcPink,
                          ),
                          child: Text(_isLogin ? 'Login' : 'Request Access'),
                        ),
                  TextButton(
                    onPressed: () => setState(() => _isLogin = !_isLogin),
                    child: Text(_isLogin ? 'Need an account? Sign Up' : 'Already have an account? Login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController controller, 
    String label, 
    IconData icon, {
    bool obscure = false,
    bool isPassword = false,
    VoidCallback? onToggleObscure,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: isPassword 
          ? IconButton(
              icon: Icon(obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded),
              onPressed: onToggleObscure,
            ) 
          : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: validator ?? (val) => val!.isEmpty ? 'Required' : null,
    );
  }
}
