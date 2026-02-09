import 'package:driver_license_verifier_app/core/services/supabase_service.dart';
import 'package:driver_license_verifier_app/theme/app_colors.dart';
import 'package:driver_license_verifier_app/utils/responsive_sizes.dart';
import 'package:flutter/material.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<Map<String, dynamic>> _profiles = [];
  List<Map<String, dynamic>> _filteredProfiles = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _roleFilter;

  @override
  void initState() {
    super.initState();
    _fetchProfiles();
  }

  Future<void> _fetchProfiles() async {
    setState(() => _isLoading = true);
    final profiles = await SupabaseService.getAllProfiles();

    // Explicitly cast to List<Map<String, dynamic>> to avoid type errors
    // Supabase returns List<dynamic>, effectively List<Map<String, dynamic>>
    final typedProfiles = List<Map<String, dynamic>>.from(profiles);

    if (mounted) {
      setState(() {
        _profiles = typedProfiles;
        _filterProfiles();
        _isLoading = false;
      });
    }
  }

  void _filterProfiles() {
    setState(() {
      _filteredProfiles = _profiles.where((profile) {
        final fullName = profile['full_name']?.toString().toLowerCase() ?? '';
        final ecNumber = profile['ec_number']?.toString().toLowerCase() ?? '';
        final email = profile['email']?.toString().toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();

        final matchesSearch =
            fullName.contains(query) ||
            ecNumber.contains(query) ||
            email.contains(query);
        final matchesRole =
            _roleFilter == null || profile['role'] == _roleFilter;

        return matchesSearch && matchesRole;
      }).toList();
    });
  }

  Future<void> _toggleApproval(String id, bool currentStatus) async {
    final success = await SupabaseService.updateProfileStatus(
      id,
      !currentStatus,
    );
    if (success) {
      await _fetchProfiles(); // Refresh
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User ${!currentStatus ? 'Approved' : 'Disabled'}'),
          ),
        );
      }
    }
  }

  Future<void> _updateRole(String id, String? newRole) async {
    if (newRole == null) return;
    final success = await SupabaseService.updateProfileRole(id, newRole);
    if (success) {
      await _fetchProfiles();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Role updated to $newRole')));
      }
    }
  }

  Future<void> _deleteUser(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: const Text(
          'Are you sure you want to delete this user? This removes their profile from the system.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await SupabaseService.deleteProfile(id);
      if (success) {
        await _fetchProfiles();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('User profile deleted')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final res = ResponsiveSize(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'User Management',
          style: TextStyle(fontSize: res.appBarTitleFont),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textMain,
        elevation: 1,
      ),
      body: Column(
        children: [
          _buildFilters(res),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredProfiles.isEmpty
                ? Center(
                    child: Text(
                      'No users found',
                      style: TextStyle(fontSize: res.bodyFont),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(
                      res.pick(mobile: 16.0, tablet: 24.0, desktop: 32.0),
                    ),
                    itemCount: _filteredProfiles.length,
                    itemBuilder: (context, index) {
                      return _buildUserCard(_filteredProfiles[index], res);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(ResponsiveSize res) {
    return Container(
      padding: EdgeInsets.all(
        res.pick(mobile: 16.0, tablet: 24.0, desktop: 32.0),
      ),
      color: Colors.white,
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Search by Name, Email, or EC Number...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onChanged: (value) {
              _searchQuery = value;
              _filterProfiles(); // Filter locally
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Role Filter:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: res.bodyFont,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.3),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _roleFilter,
                      isExpanded: true,
                      hint: const Text('All Roles'),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('All Roles')),
                        DropdownMenuItem(value: 'ADMIN', child: Text('Admin')),
                        DropdownMenuItem(
                          value: 'POLICE_OFFICER',
                          child: Text('Police Officer'),
                        ),
                        DropdownMenuItem(
                          value: 'VID_REGISTRAR',
                          child: Text('VID Registrar'),
                        ),
                        DropdownMenuItem(
                          value: 'TSCZ_OFFICER',
                          child: Text('TSCZ Officer'),
                        ),
                        DropdownMenuItem(
                          value: 'MOH_OFFICER',
                          child: Text('MOH Officer'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _roleFilter = value;
                          _filterProfiles();
                        });
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> profile, ResponsiveSize res) {
    // Determine status
    final bool isApproved = profile['is_approved'] == true;
    final String role = profile['role'] ?? 'UNKNOWN';
    final String fullName = profile['full_name'] ?? 'Unknown';
    final String? email = profile['email'];
    final String? ecNumber = profile['ec_number'];
    final String id = profile['id'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.zimGreen.withValues(alpha: 0.1),
                  child: Text(
                    fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.zimGreen,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: res.bodyFont,
                        ),
                      ),
                      if (email != null)
                        Text(
                          email,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: res.captionFont,
                          ),
                        ),
                      if (ecNumber != null)
                        Text(
                          'EC: $ecNumber',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: res.captionFont,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isApproved
                            ? AppColors.zimGreen.withValues(alpha: 0.1)
                            : AppColors.zimRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isApproved ? 'Active' : 'Pending',
                        style: TextStyle(
                          color: isApproved
                              ? AppColors.zimGreen
                              : AppColors.zimRed,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      role,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Role Editor
                DropdownButton<String>(
                  value:
                      [
                        'ADMIN',
                        'POLICE_OFFICER',
                        'VID_REGISTRAR',
                        'TSCZ_OFFICER',
                        'MOH_OFFICER',
                      ].contains(role)
                      ? role
                      : null,
                  hint: const Text('Assign Role'),
                  style: TextStyle(
                    fontSize: res.captionFont,
                    color: AppColors.textMain,
                  ),
                  underline: Container(),
                  items: const [
                    DropdownMenuItem(value: 'ADMIN', child: Text('Admin')),
                    DropdownMenuItem(
                      value: 'POLICE_OFFICER',
                      child: Text('Police'),
                    ),
                    DropdownMenuItem(
                      value: 'VID_REGISTRAR',
                      child: Text('VID'),
                    ),
                    DropdownMenuItem(
                      value: 'TSCZ_OFFICER',
                      child: Text('TSCZ'),
                    ),
                    DropdownMenuItem(value: 'MOH_OFFICER', child: Text('MOH')),
                  ],
                  onChanged: (newRole) => _updateRole(id, newRole),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _toggleApproval(id, isApproved),
                  style: TextButton.styleFrom(
                    foregroundColor: isApproved
                        ? Colors.orange
                        : AppColors.zimGreen,
                  ),
                  child: Text(isApproved ? 'Disable' : 'Approve'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _deleteUser(id),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.zimRed,
                  ),
                  tooltip: 'Delete User',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
