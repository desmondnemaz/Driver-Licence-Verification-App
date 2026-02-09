import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:driver_license_verifier_app/theme/app_colors.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:driver_license_verifier_app/utils/responsive_sizes.dart';
import 'package:driver_license_verifier_app/features/driver_management/domain/models/driver_model.dart';
import 'package:driver_license_verifier_app/core/services/supabase_service.dart';
import 'package:driver_license_verifier_app/features/driver_management/presentation/screens/registration_screen.dart';
import 'package:intl/intl.dart';

class ResultScreen extends StatefulWidget {
  final Driver? driver;
  final bool isValid;

  const ResultScreen({
    super.key,
    this.driver,
    required this.isValid,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  String? _imageUrl;
  bool _isLoadingImage = false;
  Map<String, dynamic>? _userProfile;

  @override
  void initState() {
    super.initState();
    _fetchImageUrl();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final profile = await SupabaseService.getCurrentProfile();
    if (mounted) {
      setState(() => _userProfile = profile);
    }
  }

  Future<void> _fetchImageUrl() async {
    if (widget.driver?.driverImagePath != null) {
      if (mounted) setState(() => _isLoadingImage = true);
      final url = await SupabaseService.getImageUrl(widget.driver!.driverImagePath);
      if (mounted) {
        setState(() {
          _imageUrl = url;
          _isLoadingImage = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final res = ResponsiveSize(context);
    final isValid = widget.isValid;
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Verification Result', style: TextStyle(fontSize: res.pick(mobile: 18.0, tablet: 22.0, desktop: 26.0))),
        backgroundColor: isValid ? AppColors.zimGreen : AppColors.sadcPink,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildStatusHeader(res),
            Padding(
              padding: EdgeInsets.all(res.pick(mobile: 16.0, tablet: 24.0, desktop: 32.0)),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildLicenseCard(res),
                      if (widget.driver != null && widget.driver!.certificates.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildDefensiveCertificateCard(res, widget.driver!.certificates.first),
                      ],
                      const SizedBox(height: 24),
                      _buildExtractionDetail(res),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        label: Text('Scan New Document', style: TextStyle(fontSize: res.bodyFont)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          backgroundColor: isValid ? AppColors.zimGreen : AppColors.sadcPink,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(res.borderRadius)),
                        ),
                      ),
                      if (isValid && widget.driver != null && _userProfile?['role'] == 'VID_REGISTRAR') ...[
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final updated = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RegistrationScreen(existingDriver: widget.driver),
                              ),
                            );
                            if (updated == true) {
                              if (!context.mounted) return;
                              Navigator.pop(context); // Go back to scanner to refresh data
                            }
                          },
                          icon: const Icon(Icons.edit_document),
                          label: const Text('Edit Driver Data'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            side: const BorderSide(color: AppColors.zimGreen, width: 2),
                            foregroundColor: AppColors.zimGreen,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader(ResponsiveSize res) {
    final isValid = widget.isValid;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: res.pick(mobile: 24, tablet: 32, desktop: 40)),
      decoration: BoxDecoration(
        color: isValid ? AppColors.zimGreen : AppColors.sadcPink,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          Icon(
            isValid ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
            size: res.pick(mobile: 60.0, tablet: 80.0, desktop: 100.0),
            color: Colors.white,
          ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 16),
          Text(
            isValid ? 'VERIFIED SYSTEM MATCH' : 'INVALID OR NOT FOUND',
            style: GoogleFonts.outfit(
              fontSize: res.pick(mobile: 20.0, tablet: 24.0, desktop: 30.0),
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ).animate().fadeIn(delay: 200.ms),
          Text(
            isValid ? 'Document matches database record' : 'Warning: Manual check required',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: res.bodyFont),
          ).animate().fadeIn(delay: 400.ms),
        ],
      ),
    );
  }

  Widget _buildLicenseCard(ResponsiveSize res) {
    final driver = widget.driver;
    return Container(
      padding: EdgeInsets.all(res.pick(mobile: 16.0, tablet: 24.0, desktop: 32.0)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(res.borderRadius * 1.5),
        border: Border.all(color: AppColors.textMain.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DRIVING LICENCE',
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: res.pick(mobile: 14.0, tablet: 16.0, desktop: 20.0)),
              ),
              Image.network(
                'https://upload.wikimedia.org/wikipedia/commons/thumb/6/6a/Flag_of_Zimbabwe.svg/2000px-Flag_of_Zimbabwe.svg.png',
                height: res.pick(mobile: 20.0, tablet: 30.0, desktop: 40.0),
              ),
            ],
          ),
          const Divider(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: res.pick(mobile: 80.0, tablet: 120.0, desktop: 150.0),
                height: res.pick(mobile: 100.0, tablet: 150.0, desktop: 180.0),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(res.borderRadius),
                ),
                clipBehavior: Clip.antiAlias,
                child: _isLoadingImage 
                  ? const Center(child: CircularProgressIndicator())
                  : _imageUrl != null 
                    ? Image.network(_imageUrl!, fit: BoxFit.cover)
                    : Icon(Icons.person, size: res.pick(mobile: 40.0, tablet: 60.0, desktop: 80.0), color: Colors.grey[400]),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _dataRow('1. Surname', driver?.surname ?? '---', res),
                    _dataRow('2. Name(s)', driver?.givenNames ?? '---', res),
                    _dataRow('3. DOB', driver?.dob ?? '---', res),
                    _dataRow('4d ID No', driver?.idNumber ?? '---', res),
                    _dataRow('5. License No', (driver?.licenses.isNotEmpty ?? false) ? driver!.licenses.first.licenseNumber : '---', res),
                    if (driver?.restrictions?.isNotEmpty ?? false)
                      _dataRow('12. Restrictions', driver!.restrictions!, res),
                  ],
                ),
              ),
            ],
          ).animate().fadeIn(delay: 600.ms),
        ],
      ),
    );
  }

  Widget _buildDefensiveCertificateCard(ResponsiveSize res, DefensiveCertificate cert) {
    // Determine validity
    bool isValid = false;
    final now = DateTime.now();
    try {
      DateTime? expiry = DateTime.tryParse(cert.expiryDate);
      if (expiry == null) {
        try { expiry = DateFormat('dd/MM/yyyy').parse(cert.expiryDate); } catch(_) {}
      }
      
      if (expiry != null) {
        final today = DateTime(now.year, now.month, now.day);
        if (expiry.compareTo(today) >= 0) {
          isValid = true;
        }
      }
    } catch (_) {}

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (isValid ? AppColors.zimGreen : AppColors.sadcPink).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(res.borderRadius),
        border: Border.all(color: (isValid ? AppColors.zimGreen : AppColors.sadcPink).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.verified_user_rounded, color: isValid ? AppColors.zimGreen : AppColors.sadcPink, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'DEFENSIVE DRIVING (TSCZ)',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: isValid ? AppColors.zimGreen : AppColors.sadcPink,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isValid ? AppColors.zimGreen : AppColors.sadcPink,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isValid ? 'VALID' : 'EXPIRED',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start, // Align to top
            children: [
              Expanded( // Use expanded to avoid overflow
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Certificate No:', style: TextStyle(fontSize: res.captionFont, color: AppColors.textSecondary)),
                    Text(cert.certificateNumber, style: TextStyle(fontWeight: FontWeight.bold, fontSize: res.bodyFont)),
                    const SizedBox(height: 8), // Gap
                    Text('Issue Date:', style: TextStyle(fontSize: res.captionFont, color: AppColors.textSecondary)),
                    Text(cert.issueDate, style: TextStyle(fontWeight: FontWeight.bold, fontSize: res.bodyFont)),
                  ],
                ),
              ),
              Expanded( // Use expanded
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                     // Empty spacer or maybe Status text if needed, but we have the chip now.
                     // Let's put Expiry here.
                    Text('Expiry Date:', style: TextStyle(fontSize: res.captionFont, color: AppColors.textSecondary)),
                    Text(
                      cert.expiryDate, 
                      style: TextStyle(
                        fontWeight: FontWeight.bold, 
                        fontSize: res.bodyFont,
                        color: isValid ? AppColors.zimGreen : AppColors.sadcPink,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().slideX(begin: 0.2, duration: 400.ms);
  }

  Widget _dataRow(String label, String value, ResponsiveSize res) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: res.captionFont, color: AppColors.textSecondary, fontWeight: FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: res.bodyFont, fontWeight: FontWeight.bold, color: AppColors.textMain)),
        ],
      ),
    );
  }

  Widget _buildExtractionDetail(ResponsiveSize res) {
    final driver = widget.driver;
    final isValid = widget.isValid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Security Analysis',
          style: TextStyle(fontSize: res.pick(mobile: 18.0, tablet: 20.0, desktop: 24.0), fontWeight: FontWeight.bold, color: AppColors.textMain),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(res.borderRadius),
          ),
          child: Column(
            children: [
              if (isValid && driver != null) ...[
                _logRow('DB Match', 'SUCCESS', Icons.storage_rounded, res),
                _logRow('Codes', driver.licenses.map((l) => l.licenseCode).join(', '), Icons.category_outlined, res),
                _logRow('Sync Status', 'ONLINE (SUPABASE)', Icons.cloud_done_rounded, res),
                if (driver.certificates.isNotEmpty) ...[
                  const Divider(),
                  const SizedBox(height: 8),
                  Text('Defensive Driving (TSCZ)', style: TextStyle(fontSize: res.captionFont, fontWeight: FontWeight.bold, color: AppColors.sadcPink)),
                  const SizedBox(height: 4),
                  _logRow(
                    'Cert #${driver.certificates.first.certificateNumber}', 
                    'Expires: ${driver.certificates.first.expiryDate}', 
                    Icons.verified_rounded, 
                    res
                  ),
                ],
              ] else ...[
                _logRow('DB Match', 'NOT FOUND', Icons.error_outline_rounded, res),
                _logRow('Alert Code', 'VER-404', Icons.warning_amber_rounded, res),
                _logRow('Sync Status', 'ONLINE', Icons.cloud_done_rounded, res),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _logRow(String label, String value, IconData icon, ResponsiveSize res) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: res.icon * 0.7, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(fontSize: res.labelFont, color: AppColors.textSecondary)),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: res.bodyFont, fontWeight: FontWeight.bold, color: AppColors.textMain)),
        ],
      ),
    );
  }
}
