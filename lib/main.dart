import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:driver_license_verifier_app/theme/light_theme.dart';
import 'package:driver_license_verifier_app/theme/app_colors.dart';
import 'package:driver_license_verifier_app/features/license_verifier/presentation/screens/scanner_screen.dart';
import 'package:driver_license_verifier_app/features/admin/presentation/screens/admin_dashboard.dart';
import 'package:driver_license_verifier_app/utils/responsive_sizes.dart';
import 'package:driver_license_verifier_app/features/auth/presentation/screens/auth_screen.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:driver_license_verifier_app/core/config/supabase_config.dart';
import 'package:driver_license_verifier_app/core/services/supabase_service.dart';
import 'package:driver_license_verifier_app/features/driver_management/presentation/screens/vid_dashboard_screen.dart';
import 'package:driver_license_verifier_app/features/tscz/presentation/screens/tscz_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  
  runApp(const DriverVerifierApp());
}

class DriverVerifierApp extends StatelessWidget {
  const DriverVerifierApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zim Driver License Verifier',
      theme: sadcLicenseTheme.copyWith(
        textTheme: GoogleFonts.interTextTheme(sadcLicenseTheme.textTheme),
      ),
      home: const RoleSelectionScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}



class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final user = SupabaseService.client.auth.currentUser;
    if (user != null) {
      final profile = await SupabaseService.getCurrentProfile();
      if (mounted) {
        setState(() {
          _profile = profile;
        });
      }
    }
  }

  Future<void> _logout() async {
    await SupabaseService.signOut();
    if (mounted) {
      setState(() {
        _profile = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logged out successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final res = ResponsiveSize(context);
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.sadcPink.withValues(alpha: 0.1),
              AppColors.zimWhite,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              if (_profile != null) 
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(_profile!['full_name'] ?? 'Staff', 
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(_profile!['role']?.toString().replaceAll('_', ' ') ?? '', 
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                        const SizedBox(width: 12),
                        IconButton.filled(
                          onPressed: _logout,
                          style: IconButton.styleFrom(backgroundColor: AppColors.sadcPink),
                          icon: const Icon(Icons.logout_rounded, size: 20),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: res.pick(mobile: 24.0, tablet: 48.0, desktop: 60.0),
                      vertical: 24.0,
                    ),
                    child: res.isDesktop 
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Side: Branding
                            Expanded(
                              flex: 1,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.verified_user_rounded,
                                    size: 120,
                                    color: AppColors.sadcPink,
                                  ).animate().scale(delay: 200.ms, duration: 600.ms, curve: Curves.easeOutBack),
                                  const SizedBox(height: 40),
                                  Text(
                                    'Zimbabwe Driver License\nVerification System',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.outfit(
                                      fontSize: 48,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textMain,
                                    ),
                                  ).animate().fadeIn(delay: 400.ms),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Select your role to access the registration, roadside verification, or administration dashboard.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 20,
                                      color: AppColors.textSecondary,
                                    ),
                                  ).animate().fadeIn(delay: 600.ms),
                                ],
                              ),
                            ),
                            const SizedBox(width: 60),
                            // Right Side: Cards
                            SizedBox(
                              width: 450,
                              child: _buildRoleCards(context, res),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Icon(
                              Icons.verified_user_rounded,
                              size: res.pick(mobile: 80.0, tablet: 100.0, desktop: 120.0),
                              color: AppColors.sadcPink,
                            ).animate().scale(delay: 200.ms, duration: 600.ms, curve: Curves.easeOutBack),
                            SizedBox(height: res.pick(mobile: 20.0, tablet: 32.0, desktop: 40.0)),
                            Text(
                              'Zimbabwe Driver License\nVerification System',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: res.pick(mobile: 24.0, tablet: 32.0, desktop: 40.0),
                                fontWeight: FontWeight.bold,
                                color: AppColors.textMain,
                              ),
                            ).animate().fadeIn(delay: 400.ms),
                            const SizedBox(height: 8),
                            Text(
                              'Select your role to continue',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: res.pick(mobile: 14.0, tablet: 16.0, desktop: 18.0),
                                color: AppColors.textSecondary,
                              ),
                            ).animate().fadeIn(delay: 600.ms),
                            SizedBox(height: res.pick(mobile: 40.0, tablet: 60.0, desktop: 80.0)),
                            _buildRoleCards(context, res),
                            const SizedBox(height: 24),
                          ],
                        ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCards(BuildContext context, ResponsiveSize res) {
    Future<void> handleProtectedNav(String role, Widget destination) async {
      // Check if already logged in with correct role and approved
      if (_profile != null && _profile!['role'] == role && _profile!['is_approved'] == true) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => destination));
        return;
      }

      final success = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => AuthScreen(role: role)),
      );
      if (success == true) {
        await _checkSession(); // Refresh profile after login
        if (context.mounted) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => destination));
        }
      }
    }

    final cards = [
      _RoleCard(
        title: 'VID Officer',
        subtitle: 'Driver Registration & Management',
        icon: Icons.app_registration_rounded,
        color: AppColors.sadcPink,
        onTap: () => handleProtectedNav('VID_REGISTRAR', const VidDashboardScreen()),
      ),
      _RoleCard(
        title: 'Police Officer',
        subtitle: 'Roadside License Verification',
        icon: Icons.local_police_rounded,
        color: AppColors.zimGreen,
        onTap: () => handleProtectedNav('POLICE_OFFICER', const ScannerScreen()),
      ),
      _RoleCard(
        title: 'TSCZ Officer',
        subtitle: 'Defensive Driving Certificates',
        icon: Icons.verified_user_rounded,
        color: Colors.orange,
        onTap: () => handleProtectedNav('TSCZ_OFFICER', const TsczDashboardScreen()),
      ),
      _RoleCard(
        title: 'System Admin',
        subtitle: 'Analytics & Logs',
        icon: Icons.admin_panel_settings_rounded,
        color: AppColors.textMain,
        onTap: () => handleProtectedNav('SYSTEM_ADMIN', const AdminDashboard()),
      ),
      _RoleCard(
        title: 'Driver / Guest',
        subtitle: 'Check my license & certificates',
        icon: Icons.person_search_rounded,
        color: Colors.blueAccent,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ScannerScreen()),
        ),
      ),
    ];

    if (res.isDesktop) {
      return Column(
        children: cards.map((card) => Padding(
          padding: const EdgeInsets.only(bottom: 20.0),
          child: card.animate().fadeIn(delay: 800.ms).slideX(begin: 0.1),
        )).toList(),
      );
    }

    return Column(
      children: [
        cards[0].animate().slideX(begin: -0.2, delay: 800.ms),
        const SizedBox(height: 16),
        cards[1].animate().slideX(begin: 0.2, delay: 1000.ms),
        const SizedBox(height: 16),
        cards[2].animate().slideY(begin: 0.2, delay: 1200.ms),
        const SizedBox(height: 16),
        cards[3].animate().slideY(begin: 0.2, delay: 1400.ms),
        const SizedBox(height: 16),
        cards[4].animate().slideY(begin: 0.2, delay: 1600.ms),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final res = ResponsiveSize(context);
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(res.pick(mobile: 20.0, tablet: 24.0, desktop: 28.0)),
        child: Container(
          padding: EdgeInsets.all(res.pick(mobile: 20.0, tablet: 28.0, desktop: 32.0)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(res.pick(mobile: 20.0, tablet: 24.0, desktop: 28.0)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(
              color: color.withValues(alpha: 0.1),
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(res.pick(mobile: 12.0, tablet: 16.0, desktop: 20.0)),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: res.pick(mobile: 24.0, tablet: 32.0, desktop: 40.0)),
              ),
              SizedBox(width: res.pick(mobile: 16.0, tablet: 24.0, desktop: 32.0)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: res.pick(mobile: 16.0, tablet: 18.0, desktop: 22.0),
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMain,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: res.pick(mobile: 12.0, tablet: 14.0, desktop: 16.0),
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: color.withValues(alpha: 0.3), size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
