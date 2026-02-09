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
    final activity = await SupabaseService.getLatestAuditLogs();

    // Cast explicitly
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Admin Console',
          style: TextStyle(fontSize: res.appBarTitleFont),
        ),
        actions: [
          IconButton(
            onPressed: _fetchDashboardData,
            icon: Icon(Icons.refresh_rounded, size: res.icon * 0.8),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.all(
              res.pick(mobile: 24.0, tablet: 32.0, desktop: 48.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWelcome(res),
                const SizedBox(height: 32),
                if (_isLoading)
                  const Center(child: LinearProgressIndicator())
                else
                  _buildStatsGrid(res),
                const SizedBox(height: 32),
                _buildSectionHeader('Management', res),
                _buildQuickActions(context, res),
                const SizedBox(height: 32),
                _buildSectionHeader('Recent System Activity', res),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_recentActivity.isEmpty)
                  _buildEmptyState(res)
                else
                  _buildRecentActivity(res),
                const SizedBox(height: 32),
                _buildSectionHeader('System Health', res),
                _buildHealthCard(res),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ResponsiveSize res) {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.history_toggle_off_outlined,
            size: 48,
            color: AppColors.textSecondary.withValues(alpha: 0.5),
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

  Widget _buildWelcome(ResponsiveSize res) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'System Overview',
          style: GoogleFonts.outfit(
            fontSize: res.pick(mobile: 28.0, tablet: 32.0, desktop: 36.0),
            fontWeight: FontWeight.bold,
            color: AppColors.textMain,
          ),
        ),
        Text(
          'Monitoring national license activity',
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
      crossAxisCount: res.isDesktop ? 4 : (res.isTablet ? 2 : 2),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: res.pick(mobile: 1.2, tablet: 1.4, desktop: 1.2),
      children: [
        _statCard(
          'Total Drivers',
          '${_stats['total_drivers']}',
          Icons.people_outline,
          AppColors.zimGreen,
          res,
        ),
        _statCard(
          'Verifications',
          '${_stats['verifications']}',
          Icons.verified_outlined,
          AppColors.sadcPink,
          res,
        ),
        // Placeholder for now as we don't have flagged logic yet
        _statCard(
          'System Users',
          '${_stats['active_users']}',
          Icons.admin_panel_settings_outlined,
          AppColors.zimYellow,
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
    ResponsiveSize res,
  ) {
    return Container(
      padding: EdgeInsets.all(
        res.pick(mobile: 16.0, tablet: 20.0, desktop: 24.0),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: res.pick(mobile: 20.0, tablet: 24.0, desktop: 28.0),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: res.pick(mobile: 20.0, tablet: 22.0, desktop: 26.0),
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: res.pick(mobile: 12.0, tablet: 13.0, desktop: 14.0),
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().scale(delay: 200.ms, duration: 400.ms);
  }

  Widget _buildSectionHeader(String title, ResponsiveSize res) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: res.pick(mobile: 18.0, tablet: 20.0, desktop: 24.0),
              fontWeight: FontWeight.bold,
            ),
          ),
          if (title == 'Recent System Activity')
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AuditLogScreen(),
                  ),
                );
              },
              child: Text(
                'View All',
                style: TextStyle(fontSize: res.buttonFont),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(ResponsiveSize res) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _recentActivity.length,
      itemBuilder: (context, index) {
        final item = _recentActivity[index];
        final action = item['action'] ?? 'Unknown Action';
        final profiles = item['profiles'] as Map<String, dynamic>?;
        final user = profiles?['full_name'] ?? 'System';
        final time = item['created_at'] != null
            ? timeago.format(
                DateTime.tryParse(item['created_at']) ?? DateTime.now(),
              )
            : '';

        // Determine status/color loosely based on action text
        final isAlert =
            action.toString().contains('FAIL') ||
            action.toString().contains('DELETE');
        final isVerify = action.toString().contains('VERIFY');

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: EdgeInsets.all(
            res.pick(mobile: 16.0, tablet: 20.0, desktop: 24.0),
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              _activityIndicator(
                isAlert ? 'alert' : (isVerify ? 'valid' : 'reg'),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: res.bodyFont,
                      ),
                    ),
                    Text(
                      'By: $user',
                      style: TextStyle(
                        fontSize: res.captionFont,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                time,
                style: TextStyle(
                  fontSize: res.captionFont,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: (index * 100).ms).slideX(begin: 0.1);
      },
    );
  }

  Widget _activityIndicator(String status) {
    Color color = Colors.grey;
    if (status == 'valid') color = AppColors.zimGreen;
    if (status == 'alert') color = AppColors.zimRed;
    if (status == 'reg') color = AppColors.sadcPink;

    return Container(
      width: 8,
      height: 40,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, ResponsiveSize res) {
    return Row(
      children: [
        Expanded(
          child: _actionButton(
            context,
            'Manage Users',
            Icons.manage_accounts_outlined,
            AppColors.zimGreen,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const UserManagementScreen(),
              ),
            ),
            res,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _actionButton(
            context,
            'Register Driver',
            Icons.person_add_alt_1_outlined,
            AppColors.textMain,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RegistrationScreen(),
                ),
              );
            },
            res,
          ),
        ),
      ],
    );
  }

  Widget _actionButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
    ResponsiveSize res,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: res.bodyFont,
                fontWeight: FontWeight.bold,
                color: AppColors.textMain,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthCard(ResponsiveSize res) {
    return Container(
      padding: EdgeInsets.all(
        res.pick(mobile: 20.0, tablet: 24.0, desktop: 32.0),
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.textMain, AppColors.secondary],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_done_rounded,
            color: AppColors.zimGreen,
            size: res.icon * 1.5,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Central Database Online',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: res.bodyFont,
                  ),
                ),
                Text(
                  'Connected to Supabase',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: res.captionFont,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.zimGreen.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'UP',
              style: TextStyle(
                color: AppColors.zimGreen,
                fontWeight: FontWeight.bold,
                fontSize: res.captionFont,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
