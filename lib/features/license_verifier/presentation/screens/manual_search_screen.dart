import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:driver_license_verifier_app/theme/app_colors.dart';

import 'package:driver_license_verifier_app/core/services/supabase_service.dart';
import 'package:driver_license_verifier_app/features/license_verifier/presentation/screens/result_screen.dart';

class ManualSearchScreen extends StatefulWidget {
  const ManualSearchScreen({super.key});

  @override
  State<ManualSearchScreen> createState() => _ManualSearchScreenState();
}

class _ManualSearchScreenState extends State<ManualSearchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _licenseController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleSearch() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Strip hyphens and spaces from ID number
      final cleanId = _idController.text.replaceAll(RegExp(r'[-\s]'), '').toUpperCase();
      final cleanLicense = _licenseController.text.trim().toUpperCase();

      final driver = await SupabaseService.getDriver(cleanId, cleanLicense);

      if (!mounted) return;

      if (driver != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ResultScreen(driver: driver, isValid: true),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No matching driver found. Please check the details.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual Search'),
        centerTitle: true,
      ),
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
                  const Icon(Icons.search_rounded, size: 80, color: AppColors.sadcPink),
                  const SizedBox(height: 24),
                  Text(
                    'Verification Backup',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter details exactly as they appear on the document.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  _buildTextField(
                    _idController,
                    'ID Number (e.g. 12345678A12)',
                    Icons.credit_card_outlined,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    _licenseController,
                    'License Number (e.g. 12345)',
                    Icons.numbers_rounded,
                  ),
                  const SizedBox(height: 32),
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          onPressed: _handleSearch,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            backgroundColor: AppColors.sadcPink,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Search Database', style: TextStyle(fontSize: 18)),
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.sadcPink),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: (val) => val!.isEmpty ? 'Field required' : null,
    );
  }
}
