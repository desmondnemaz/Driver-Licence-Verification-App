import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:driver_license_verifier_app/theme/app_colors.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:driver_license_verifier_app/utils/responsive_sizes.dart';
import 'package:driver_license_verifier_app/features/driver_management/domain/models/driver_model.dart';
import 'package:driver_license_verifier_app/core/services/supabase_service.dart';
import 'package:intl/intl.dart';

class GuestResultScreen extends StatefulWidget {
  final Driver? driver;
  final bool isValid;

  const GuestResultScreen({super.key, this.driver, required this.isValid});

  @override
  State<GuestResultScreen> createState() => _GuestResultScreenState();
}

class _GuestResultScreenState extends State<GuestResultScreen> {
  String? _imageUrl;
  bool _isLoadingImage = false;

  @override
  void initState() {
    super.initState();
    _fetchImageUrl();
  }

  Future<void> _fetchImageUrl() async {
    if (widget.driver?.driverImagePath != null) {
      if (mounted) setState(() => _isLoadingImage = true);
      try {
        final url = await SupabaseService.getImageUrl(
          widget.driver!.driverImagePath,
        );
        if (mounted) {
          setState(() {
            _imageUrl = url;
            _isLoadingImage = false;
          });
        }
      } catch (e) {
        debugPrint('Error in GuestResultScreen _fetchImageUrl: $e');
        if (mounted) setState(() => _isLoadingImage = false);
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
        title: Text(
          'Verification Result',
          style: TextStyle(
            fontSize: res.pick(mobile: 18.0, tablet: 22.0, desktop: 26.0),
          ),
        ),
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
              padding: EdgeInsets.all(
                res.pick(mobile: 16.0, tablet: 24.0, desktop: 32.0),
              ),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildLicenseCard(res),
                      if (widget.driver != null &&
                          widget.driver!.certificates.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildDefensiveCertificateCard(
                          res,
                          widget.driver!.certificates.first,
                        ),
                      ],
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        label: Text(
                          'Verify Another',
                          style: TextStyle(fontSize: res.bodyFont),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          backgroundColor: isValid
                              ? AppColors.zimGreen
                              : AppColors.sadcPink,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              res.borderRadius,
                            ),
                          ),
                        ),
                      ),
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
      padding: EdgeInsets.symmetric(
        vertical: res.pick(mobile: 24, tablet: 32, desktop: 40),
      ),
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
            isValid
                ? Icons.check_circle_outline_rounded
                : Icons.error_outline_rounded,
            size: res.pick(mobile: 60.0, tablet: 80.0, desktop: 100.0),
            color: Colors.white,
          ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 16),
          Text(
            isValid ? 'OFFICIALLY VERIFIED' : 'NOT VERIFIED',
            style: GoogleFonts.outfit(
              fontSize: res.pick(mobile: 20.0, tablet: 24.0, desktop: 30.0),
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ).animate().fadeIn(delay: 200.ms),
          Text(
            isValid
                ? 'Your document matches our secure records'
                : 'Check details or contact VID',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: res.bodyFont,
            ),
          ).animate().fadeIn(delay: 400.ms),
        ],
      ),
    );
  }

  Widget _buildLicenseCard(ResponsiveSize res) {
    final driver = widget.driver;
    return Container(
      padding: EdgeInsets.all(
        res.pick(mobile: 16.0, tablet: 24.0, desktop: 32.0),
      ),
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
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  fontSize: res.pick(mobile: 14.0, tablet: 16.0, desktop: 20.0),
                ),
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
                    : Icon(
                        Icons.person,
                        size: res.pick(
                          mobile: 40.0,
                          tablet: 60.0,
                          desktop: 80.0,
                        ),
                        color: Colors.grey[400],
                      ),
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
                    _dataRow(
                      '5. License No',
                      (driver?.licenses.isNotEmpty ?? false)
                          ? driver!.licenses.first.licenseNumber
                          : '---',
                      res,
                    ),
                  ],
                ),
              ),
            ],
          ).animate().fadeIn(delay: 600.ms),
        ],
      ),
    );
  }

  Widget _buildDefensiveCertificateCard(
    ResponsiveSize res,
    DefensiveCertificate cert,
  ) {
    bool isValid = false;
    final now = DateTime.now();
    try {
      DateTime? expiry = DateTime.tryParse(cert.expiryDate);
      if (expiry == null) {
        try {
          expiry = DateFormat('dd/MM/yyyy').parse(cert.expiryDate);
        } catch (_) {}
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
        color: (isValid ? AppColors.zimGreen : AppColors.sadcPink).withValues(
          alpha: 0.05,
        ),
        borderRadius: BorderRadius.circular(res.borderRadius),
        border: Border.all(
          color: (isValid ? AppColors.zimGreen : AppColors.sadcPink).withValues(
            alpha: 0.3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.verified_user_rounded,
                    color: isValid ? AppColors.zimGreen : AppColors.sadcPink,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'DEFENSIVE DRIVING',
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Certificate No:',
                      style: TextStyle(
                        fontSize: res.captionFont,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      cert.certificateNumber,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: res.bodyFont,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Expiry Date:',
                      style: TextStyle(
                        fontSize: res.captionFont,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      cert.expiryDate,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: res.bodyFont,
                        color: isValid
                            ? AppColors.zimGreen
                            : AppColors.sadcPink,
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
          Text(
            label,
            style: TextStyle(
              fontSize: res.captionFont,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: res.bodyFont,
              fontWeight: FontWeight.bold,
              color: AppColors.textMain,
            ),
          ),
        ],
      ),
    );
  }
}
