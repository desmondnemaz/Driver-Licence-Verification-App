import 'package:driver_license_verifier_app/core/services/supabase_service.dart';
import 'package:driver_license_verifier_app/features/admin/presentation/screens/user_management_screen.dart';
import 'package:driver_license_verifier_app/features/driver_management/presentation/screens/registration_screen.dart';
import 'package:driver_license_verifier_app/theme/app_colors.dart';
import 'package:driver_license_verifier_app/utils/responsive_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:driver_license_verifier_app/features/admin/presentation/screens/audit_log_screen.dart';
import 'package:timeago/timeago.dart' as timeago;

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  bool _isLoading = true;
  Map<String, int> _stats = {
    'total_drivers': 0,
    'active_users': 0,
    'verifications': 0,
    'alerts': 0,
  };
  List<Map<String, dynamic>> _recentActivity = [];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);
    final stats = await SupabaseService.getAdminStats();
    final activity = await SupabaseService.getLatestAuditLogs(limit: 10);

    final List<Map<String, dynamic>> typedActivity =
        List<Map<String, dynamic>>.from(activity);

    if (mounted) {
      setState(() {
        _stats = stats;
        _recentActivity = typedActivity;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final res = ResponsiveSize(context);

    // Sidebar width for desktop
    final double sidebarWidth = res.isDesktop ? 380 : 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Admin Console',
          style: GoogleFonts.outfit(
            fontSize: res.appBarTitleFont,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textMain,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh Data',
            onPressed: _fetchDashboardData,
            icon: Icon(Icons.refresh_rounded, size: res.icon * 0.6),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchDashboardData,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main Content Area
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.all(
                    res.pick(mobile: 16.0, tablet: 24.0, desktop: 32.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(res),
                      const SizedBox(height: 24),
                      if (_isLoading)
                        _buildShimmerStats(res)
                      else
                        _buildStatsGrid(res),
                      const SizedBox(height: 32),
                      _buildSectionHeader('Management & Tools', res),
                      _buildQuickActions(context, res),
                      const SizedBox(height: 32),
                      // Only show Activity below if not on Desktop (where it's in sidebar)
                      if (!res.isDesktop) ...[
                        _buildSectionHeader('Recent System Activity', res),
                        if (_isLoading)
                          const Center(child: CircularProgressIndicator())
                        else if (_recentActivity.isEmpty)
                          _buildEmptyState(res)
                        else
                          _buildRecentActivityList(res),
                      ],
                      const SizedBox(height: 32),
                      _buildSectionHeader('System Health', res),
                      _buildHealthCard(res),
                    ],
                  ),
                ),
              ),
            ),
            // Right Sidebar for Desktop
            if (res.isDesktop)
              Container(
                width: sidebarWidth,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    left: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
                  ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recent Activity',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AuditLogScreen(),
                              ),
                            ),
                            child: const Text('View All'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _recentActivity.isEmpty
                              ? _buildEmptyState(res)
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  itemCount: _recentActivity.length,
                                  itemBuilder: (context, index) {
                                    return _buildActivityTile(
                                      _recentActivity[index],
                                      res,
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerStats(ResponsiveSize res) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(child: LinearProgressIndicator()),
    );
  }

  Widget _buildEmptyState(ResponsiveSize res) {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history_toggle_off_outlined,
            size: 48,
            color: AppColors.textSecondary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No recent activity found',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: res.bodyFont,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ResponsiveSize res) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'System Overview',
          style: GoogleFonts.outfit(
            fontSize: res.pick(mobile: 24.0, tablet: 28.0, desktop: 32.0),
            fontWeight: FontWeight.bold,
            color: AppColors.textMain,
          ),
        ),
        Text(
          'Monitoring national license activity and security',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: res.bodyFont,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(ResponsiveSize res) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: res.pick(mobile: 2, tablet: 2, desktop: 4),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: res.pick(mobile: 1.4, tablet: 1.6, desktop: 1.3),
      children: [
        _statCard(
          'Total Drivers',
          '${_stats['total_drivers']}',
          Icons.people_alt_rounded,
          AppColors.zimGreen,
          'Active Records',
          res,
        ),
        _statCard(
          'Verifications',
          '${_stats['verifications']}',
          Icons.verified_user_rounded,
          AppColors.sadcPink,
          'Total Scans',
          res,
        ),
        _statCard(
          'System Users',
          '${_stats['active_users']}',
          Icons.admin_panel_settings_rounded,
          AppColors.zimYellow,
          'Active Staff',
          res,
        ),
        _statCard(
          'Security Alerts',
          '${_stats['alerts']}',
          Icons.warning_amber_rounded,
          AppColors.zimRed,
          'Scan Attempts',
          res,
        ),
      ],
    );
  }

  Widget _statCard(
    String label,
    String value,
    IconData icon,
    Color color,
    String sublabel,
    ResponsiveSize res,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            bottom: -10,
            child: Icon(
              icon,
              size: 80,
              color: color.withValues(alpha: 0.05),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: GoogleFonts.outfit(
                        fontSize: res.pick(mobile: 20.0, tablet: 22.0, desktop: 24.0),
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMain,
                      ),
                    ),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().scale(delay: 100.ms, duration: 400.ms, curve: Curves.easeOutBack);
  }

  Widget _buildSectionHeader(String title, ResponsiveSize res) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: res.pick(mobile: 18.0, tablet: 20.0, desktop: 22.0),
              fontWeight: FontWeight.bold,
            ),
          ),
          if (title == 'Recent System Activity' && !res.isDesktop)
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AuditLogScreen(),
                ),
              ),
              child: const Text('View All'),
            ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityList(ResponsiveSize res) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _recentActivity.length,
      itemBuilder: (context, index) {
        return _buildActivityTile(_recentActivity[index], res);
      },
    );
  }

  Widget _buildActivityTile(Map<String, dynamic> item, ResponsiveSize res) {
    final action = item['action'] ?? 'Unknown';
    final profilesData = item['profiles'];
    Map<String, dynamic>? profiles;
    if (profilesData is List && profilesData.isNotEmpty) {
      profiles = profilesData[0] as Map<String, dynamic>?;
    } else if (profilesData is Map) {
      profiles = profilesData.cast<String, dynamic>();
    }
    final user = profiles?['full_name'] ?? 'System';
    final time = item['created_at'] != null
        ? timeago.format(
            DateTime.tryParse(item['created_at']!)?.toLocal() ?? DateTime.now(),
          )
        : '';

    final details = item['details'] as Map<String, dynamic>?;
    final method = details?['method']?.toString();
    final status = details?['status']?.toString();

    IconData icon = Icons.info_outline_rounded;
    Color color = Colors.blue;

    if (action.contains('VERIFY')) {
      icon = _iconForMethod(method);
      color = status == 'SUCCESS' ? AppColors.zimGreen : AppColors.zimRed;
    } else if (action.contains('REGISTER')) {
      icon = Icons.person_add_rounded;
      color = AppColors.sadcPink;
    } else if (action.contains('ATTEMPT')) {
      icon = Icons.warning_rounded;
      color = AppColors.zimRed;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'By: $user • $time',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideX(begin: 0.05);
  }

  IconData _iconForMethod(String? method) {
    switch (method) {
      case 'QR_SCAN': return Icons.qr_code_rounded;
      case 'MANUAL_SEARCH': return Icons.search_rounded;
      case 'BIOMETRIC': return Icons.fingerprint_rounded;
      default: return Icons.verified_rounded;
    }
  }

  Widget _buildQuickActions(BuildContext context, ResponsiveSize res) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: res.pick(mobile: 2, tablet: 3, desktop: 3),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: res.pick(mobile: 1.3, tablet: 1.5, desktop: 2.0),
      children: [
        _actionCard(
          'Manage Users',
          'Roles & Permissions',
          Icons.manage_accounts_outlined,
          AppColors.zimGreen,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const UserManagementScreen()),
          ),
        ),
        _actionCard(
          'Register Driver',
          'Add New License',
          Icons.person_add_alt_1_outlined,
          AppColors.textMain,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const RegistrationScreen()),
          ),
        ),
      ],
    );
  }

  Widget _actionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthCard(ResponsiveSize res) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.textMain,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.textMain.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.dns_rounded,
            color: AppColors.zimGreen,
            size: 40,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Central Database Bridge',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Encrypted connection to Supabase active',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.zimGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Text(
              'HEALTHY',
              style: TextStyle(
                color: AppColors.zimGreen,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
