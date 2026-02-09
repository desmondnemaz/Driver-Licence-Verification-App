import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:driver_license_verifier_app/theme/app_colors.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:driver_license_verifier_app/utils/responsive_sizes.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:driver_license_verifier_app/features/driver_management/domain/models/driver_model.dart';
import 'package:driver_license_verifier_app/features/license_verifier/presentation/screens/result_screen.dart';
import 'package:driver_license_verifier_app/core/services/supabase_service.dart';

import 'package:driver_license_verifier_app/features/license_verifier/presentation/screens/manual_search_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    returnImage: false,
    formats: [BarcodeFormat.qrCode, BarcodeFormat.pdf417],
    cameraResolution: const Size(
      1280,
      720,
    ), // Requesting specific resolution for better clarity
  );
  bool _isScanning = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_isScanning) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      setState(() {
        _isScanning = false;
      });
      _controller.stop();

      final String? rawValue = barcodes.first.rawValue;
      if (rawValue != null) {
        // Log the scan attempt
        SupabaseService.logAudit(
          action: 'SCAN_ATTEMPT',
          details: {'raw_data': rawValue},
        );
        _processScannedData(rawValue);
      } else {
        _showErrorDialog('Failed to read QR code data');
      }
    }
  }

  Future<void> _processScannedData(String rawData) async {
    debugPrint('SCANNED RAW: $rawData');
    final Map<String, String> parsedData = _parseQRData(rawData);

    // Extract likely keys
    String? idNumber = parsedData['Identification number'];
    final String? refNumber = parsedData['Application Reference Number'];

    // Trim first 3 characters (e.g. "01/") from ID Number if present
    if (idNumber != null && idNumber.length > 3) {
      idNumber = idNumber.substring(3);
    }

    // Strip hyphens and spaces if present in QR data
    if (idNumber != null) {
      idNumber = idNumber.replaceAll(RegExp(r'[-\s]'), '').toUpperCase();
    }

    // Debug parsed
    debugPrint('PARSED: $parsedData');
    debugPrint('SEARCHING ID: $idNumber');

    // Show loading indicator or toast if needed, but for now we just wait
    // Ideally we might want a loading overlay here.

    final Driver? foundDriver = await SupabaseService.getDriver(
      idNumber ?? '',
      refNumber,
    );

    if (!mounted) return;

    if (foundDriver != null) {
      SupabaseService.logAudit(
        action: 'VERIFY_LICENSE',
        targetEntityId: foundDriver.id,
        details: {
          'status': 'SUCCESS',
          'id_number': idNumber,
          'driver_name': '${foundDriver.surname} ${foundDriver.givenNames}',
        },
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ResultScreen(driver: foundDriver, isValid: true),
        ),
      );
    } else {
      SupabaseService.logAudit(
        action: 'VERIFY_LICENSE',
        details: {
          'status': 'FAILURE',
          'id_number': idNumber ?? 'UNKNOWN',
          'raw_scan': rawData,
        },
      );

      _showResultDialog(rawData, isError: true);
    }
  }

  Map<String, String> _parseQRData(String raw) {
    final Map<String, String> data = {};
    final lines = raw.split('\n');

    for (var line in lines) {
      if (line.contains('|')) {
        final parts = line.split('|');
        if (parts.length >= 2) {
          data[parts[0].trim()] = parts[1].trim();
        }
      }
    }
    return data;
  }

  void _showErrorDialog(String message) {
    _showResultDialog(message, isError: true);
  }

  void _showResultDialog(String data, {bool isError = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(isError ? 'Driver Not Found' : 'Scanned Data'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isError)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    'No matching driver found in the database. Raw scan data:',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              SelectableText(data),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              setState(() {
                _isScanning = true;
              });
              _controller.start(); // Resume scanning
            },
            child: const Text('Scan Again'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back
            },
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final res = ResponsiveSize(context);

    // Calculate scan window size based on margins
    // Horizontal margin: mobile: 60, tablet: 150, desktop: 300
    // Vertical margin: mobile: 200, tablet: 250, desktop: 300
    final double horizontalMargin = res.pick(
      mobile: 60.0,
      tablet: 150.0,
      desktop: 300.0,
    );
    final double verticalMargin = res.pick(
      mobile: 200.0,
      tablet: 250.0,
      desktop: 300.0,
    );

    final screenSize = MediaQuery.of(context).size;
    final double scanWidth = screenSize.width - (horizontalMargin * 2);
    final double scanHeight = screenSize.height - (verticalMargin * 2);

    // Ensure we don't have negative sizes
    final Rect scanWindow = Rect.fromCenter(
      center: Offset(screenSize.width / 2, screenSize.height / 2),
      width: scanWidth > 0 ? scanWidth : 200,
      height: scanHeight > 0 ? scanHeight : 200,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        toolbarHeight: res.appBarHeight,
        title: Text(
          'Roadside Verifier',
          style: TextStyle(fontSize: res.appBarTitleFont),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: res.appBarIcon),
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            scanWindow: scanWindow, // Only scan inside the box
            errorBuilder: (context, error, child) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error, color: Colors.white, size: 32),
                    const SizedBox(height: 16),
                    Text(
                      'Camera Error: ${error.errorCode}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              );
            },
          ),
          // Darken the area outside the scan window
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.5),
              BlendMode.srcOut,
            ),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: horizontalMargin,
                    vertical: verticalMargin,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(res.borderRadius * 2),
                  ),
                ),
              ],
            ),
          ),
          // Visually border the scan window
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: _isScanning
                    ? AppColors.zimYellow
                    : Colors.white.withValues(alpha: 0.5),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(res.borderRadius * 2),
            ),
            margin: EdgeInsets.symmetric(
              horizontal: horizontalMargin,
              vertical: verticalMargin,
            ),
          ),
          if (_isScanning)
            _buildScanningAnimation(res, verticalMargin, scanHeight),
          Positioned(
            bottom: res.pick(mobile: 40.0, tablet: 60.0, desktop: 80.0),
            left: 0,
            right: 0,
            child: _buildControls(res),
          ),
        ],
      ),
    );
  }

  Widget _buildScanningAnimation(
    ResponsiveSize res,
    double verticalMargin,
    double scanHeight,
  ) {
    return Positioned(
      top: verticalMargin,
      left: res.pick(mobile: 60.0, tablet: 150.0, desktop: 300.0),
      right: res.pick(mobile: 60.0, tablet: 150.0, desktop: 300.0),
      child:
          Container(
                height: 2,
                decoration: BoxDecoration(
                  color: AppColors.zimYellow,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.zimYellow.withValues(alpha: 0.5),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              )
              .animate(onPlay: (controller) => controller.repeat())
              .moveY(
                begin: 0,
                end: scanHeight,
                duration: 1500.ms,
                curve: Curves.easeInOut,
              ),
    );
  }

  double _zoomFactor = 0.0;
  bool _isTorchOn = false;

  Widget _buildControls(ResponsiveSize res) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: res.pick(mobile: 40.0, tablet: 80.0, desktop: 150.0),
          ),
          child: Row(
            children: [
              const Icon(Icons.zoom_out_rounded, color: Colors.white),
              Expanded(
                child: Slider(
                  value: _zoomFactor,
                  onChanged: (value) {
                    setState(() => _zoomFactor = value);
                    _controller.setZoomScale(value);
                  },
                  activeColor: AppColors.zimYellow,
                  inactiveColor: Colors.white.withValues(alpha: 0.3),
                ),
              ),
              const Icon(Icons.zoom_in_rounded, color: Colors.white),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.filled(
              onPressed: () {
                _controller.toggleTorch();
                setState(() => _isTorchOn = !_isTorchOn);
              },
              style: IconButton.styleFrom(
                backgroundColor: _isTorchOn
                    ? AppColors.zimYellow
                    : Colors.white.withValues(alpha: 0.2),
                foregroundColor: _isTorchOn ? Colors.black : Colors.white,
                padding: const EdgeInsets.all(16),
              ),
              icon: Icon(
                _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                size: 28,
              ),
            ),
            const SizedBox(width: 32),
            IconButton.filled(
              onPressed: () => _controller.switchCamera(),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
              icon: const Icon(Icons.cameraswitch_rounded, size: 28),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Shiny Surface?',
          style: GoogleFonts.outfit(
            color: AppColors.zimYellow,
            fontSize: res.bodyFont,
            fontWeight: FontWeight.bold,
          ),
        ).animate().fadeIn(),
        const SizedBox(height: 4),
        Text(
          'Tilt slightly or use Flash',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: res.captionFont,
          ),
        ).animate().fadeIn(),
        const SizedBox(height: 24),
        TextButton.icon(
          onPressed: () {
            _controller.stop(); // Pause scanner when entering manually
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ManualSearchScreen(),
              ),
            ).then((_) {
              if (mounted) _controller.start(); // Resume when returning
            });
          },
          icon: const Icon(Icons.keyboard_outlined, color: Colors.white70),
          label: const Text(
            'Cannot scan? Enter details manually',
            style: TextStyle(
              color: Colors.white70,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}
