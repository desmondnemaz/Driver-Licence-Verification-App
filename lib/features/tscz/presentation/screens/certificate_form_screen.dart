import 'package:driver_license_verifier_app/core/services/supabase_service.dart';
import 'package:driver_license_verifier_app/features/driver_management/domain/models/driver_model.dart';
import 'package:driver_license_verifier_app/theme/app_colors.dart';
import 'package:driver_license_verifier_app/utils/responsive_sizes.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class CertificateFormScreen extends StatefulWidget {
  final String driverId;
  final String driverName; // For display
  final DefensiveCertificate? existingCertificate;

  const CertificateFormScreen({
    super.key,
    required this.driverId,
    required this.driverName,
    this.existingCertificate,
  });

  @override
  State<CertificateFormScreen> createState() => _CertificateFormScreenState();
}

class _CertificateFormScreenState extends State<CertificateFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _certNumberController = TextEditingController();
  
  DateTime? _issueDate;
  DateTime? _expiryDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingCertificate != null) {
      _certNumberController.text = widget.existingCertificate!.certificateNumber;
      _issueDate = _tryParseDate(widget.existingCertificate!.issueDate);
      _expiryDate = _tryParseDate(widget.existingCertificate!.expiryDate);
    } else {
      // Default: Issue today, expires in 4 years
      _issueDate = DateTime.now();
      _expiryDate = DateTime.now().add(const Duration(days: 365 * 4)); 
    }
  }

  DateTime? _tryParseDate(String dateStr) {
    try {
      return DateFormat('dd/MM/yyyy').parse(dateStr);
    } catch (_) {
      try {
         return DateFormat('yyyy-MM-dd').parse(dateStr); 
      } catch(__) {
        return null;
      }
    }
  }

  Future<void> _selectDate(BuildContext context, bool isExpiry) async {
    final initial = isExpiry ? (_expiryDate ?? DateTime.now()) : (_issueDate ?? DateTime.now());
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2050),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.sadcPink,
              onPrimary: Colors.white,
              onSurface: AppColors.textMain,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isExpiry) {
          _expiryDate = picked;
        } else {
          _issueDate = picked;
          // Auto update expiry if it was default
          _expiryDate ??= picked.add(const Duration(days: 365 * 4));
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_issueDate == null || _expiryDate == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select dates')));
       return;
    }

    setState(() => _isLoading = true);

    bool success;
    final issueStr = DateFormat('dd/MM/yyyy').format(_issueDate!);
    final expiryStr = DateFormat('dd/MM/yyyy').format(_expiryDate!);

    if (widget.existingCertificate != null) {
      success = await SupabaseService.updateDefensiveCertificate(
        certificateNumber: widget.existingCertificate!.certificateNumber, // Identifying logic needs review if ID not available
        newCertificateNumber: _certNumberController.text.toUpperCase(),
        originalCertificateNumber: widget.existingCertificate!.certificateNumber,
        issueDate: issueStr,
        expiryDate: expiryStr,
      );
    } else {
      success = await SupabaseService.addDefensiveCertificate(
        driverId: widget.driverId,
        certificateNumber: _certNumberController.text.toUpperCase(),
        issueDate: issueStr,
        expiryDate: expiryStr,
      );
    }

    setState(() => _isLoading = false);

    if (success && mounted) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Certificate saved successfully'),
            backgroundColor: AppColors.zimGreen),
      );
    } else if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save certificate')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final res = ResponsiveSize(context);
    final isEdit = widget.existingCertificate != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Certificate' : 'Issue Certificate'),
        backgroundColor: AppColors.sadcPink,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(res.pick(mobile: 16.0, tablet: 24.0, desktop: 32.0)),
          child: Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: res.pick(mobile: double.infinity, tablet: 600, desktop: 800)),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.driverName,
                      style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text('Defensive Driving Certificate (TSCZ)', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 32),
                    
                    TextFormField(
                      controller: _certNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Certificate Number',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.verified_user_outlined),
                      ),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 24),
                    
                    Row(
                      children: [
                        Expanded(
                          child: _buildDateTile('Issue Date', _issueDate, () => _selectDate(context, false)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildDateTile('Expiry Date', _expiryDate, () => _selectDate(context, true)),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 32),
                    
                    _isLoading 
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          onPressed: _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.sadcPink,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            foregroundColor: Colors.white,
                          ),
                          child: Text(isEdit ? 'Update Certificate' : 'Issue Certificate', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateTile(String label, DateTime? date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(
          date != null ? DateFormat('dd/MM/yyyy').format(date) : 'Select',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
