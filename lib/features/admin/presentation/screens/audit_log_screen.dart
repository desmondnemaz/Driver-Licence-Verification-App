import 'package:driver_license_verifier_app/core/services/supabase_service.dart';
import 'package:driver_license_verifier_app/theme/app_colors.dart';
import 'package:driver_license_verifier_app/utils/responsive_sizes.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _actionFilter;
  String _searchQuery = '';
  static const int _pageSize = 30;

  final _searchController = TextEditingController();

  // Filter chips
  static const _filters = [
    _FilterOption(label: 'All', action: null, icon: Icons.list_alt_rounded),
    _FilterOption(
      label: 'Verifications',
      action: 'VERIFY_LICENSE',
      icon: Icons.verified_outlined,
    ),
    _FilterOption(
      label: 'Registrations',
      action: 'REGISTER_DRIVER',
      icon: Icons.person_add_alt_1_outlined,
    ),
    _FilterOption(
      label: 'Alerts',
      action: 'SCAN_ATTEMPT',
      icon: Icons.warning_amber_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchLogs({bool reset = true}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _logs = [];
        _hasMore = true;
      });
    }

    final results = await SupabaseService.getAuditLogs(
      limit: _pageSize,
      offset: reset ? 0 : _logs.length,
      actionFilter: _actionFilter,
    );

    if (mounted) {
      setState(() {
        if (reset) {
          _logs = results;
        } else {
          _logs.addAll(results);
        }
        _hasMore = results.length == _pageSize;
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    await _fetchLogs(reset: false);
  }

  List<Map<String, dynamic>> get _filteredLogs {
    if (_searchQuery.isEmpty) return _logs;
    final q = _searchQuery.toLowerCase();
    return _logs.where((log) {
      final action = (log['action'] ?? '').toString().toLowerCase();
      final profilesData = log['profiles'];
      Map<String, dynamic>? profiles;
      if (profilesData is List && profilesData.isNotEmpty) {
        profiles = profilesData[0] as Map<String, dynamic>?;
      } else if (profilesData is Map) {
        profiles = profilesData.cast<String, dynamic>();
      }
      final name = (profiles?['full_name'] ?? '').toString().toLowerCase();
      return action.contains(q) || name.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final res = ResponsiveSize(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'System Audit Logs',
          style: TextStyle(fontSize: res.appBarTitleFont),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textMain,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => _fetchLogs(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilters(res),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _fetchLogs(),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredLogs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.history_toggle_off_outlined,
                            size: 52,
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.4,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No logs found',
                            style: TextStyle(
                              fontSize: res.bodyFont,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.all(
                        res.pick(mobile: 16.0, tablet: 24.0, desktop: 32.0),
                      ),
                      itemCount: _filteredLogs.length + 1,
                      itemBuilder: (context, index) {
                        if (index == _filteredLogs.length) {
                          return _buildLoadMore(res);
                        }
                        final log = Map<String, dynamic>.from(
                          _filteredLogs[index],
                        );
                        return _buildLogCard(log, res);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(ResponsiveSize res) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        res.pick(mobile: 16.0, tablet: 24.0, desktop: 32.0),
        12,
        res.pick(mobile: 16.0, tablet: 24.0, desktop: 32.0),
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v.trim()),
            decoration: InputDecoration(
              hintText: 'Search by action or user...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filters.map((f) {
                final isSelected = _actionFilter == f.action;
                return Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 12),
                  child: FilterChip(
                    avatar: Icon(
                      f.icon,
                      size: 16,
                      color: isSelected ? Colors.white : AppColors.textMain,
                    ),
                    label: Text(
                      f.label,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : AppColors.textMain,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() => _actionFilter = f.action);
                      _fetchLogs();
                    },
                    selectedColor: AppColors.sadcPink,
                    backgroundColor: AppColors.background,
                    checkmarkColor: Colors.white,
                    showCheckmark: false,
                    side: BorderSide(
                      color: isSelected
                          ? AppColors.sadcPink
                          : Colors.grey.shade300,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadMore(ResponsiveSize res) {
    if (!_hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            'End of logs',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: res.captionFont,
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: _isLoadingMore
            ? const CircularProgressIndicator()
            : OutlinedButton.icon(
                onPressed: _loadMore,
                icon: const Icon(Icons.expand_more_rounded),
                label: const Text('Load More'),
              ),
      ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log, ResponsiveSize res) {
    final action = log['action'] ?? 'UNKNOWN';
    final profilesData = log['profiles'];
    Map<String, dynamic>? profiles;
    if (profilesData is List && profilesData.isNotEmpty) {
      profiles = profilesData[0] as Map<String, dynamic>?;
    } else if (profilesData is Map) {
      profiles = profilesData.cast<String, dynamic>();
    }
    final userName = profiles?['full_name'] ?? 'System / Anonymous';

    String time = '-';
    if (log['created_at'] != null) {
      try {
        final dt = DateTime.tryParse(log['created_at']!)?.toLocal() ?? DateTime.now();
        time = timeago.format(dt);
      } catch (_) {}
    }

    final details = log['details'] as Map<String, dynamic>?;
    final method = details?['method']?.toString();
    final status = details?['status']?.toString();

    Color statusColor = Colors.blue;
    final act = action.toString().toUpperCase();
    if (act.contains('REGISTER')) statusColor = AppColors.sadcPink;
    if (act.contains('VERIFY') && status == 'SUCCESS') {
      statusColor = AppColors.zimGreen;
    }
    if (status == 'NOT_FOUND' ||
        status == 'ERROR' ||
        act.contains('DELETE') ||
        act.contains('ATTEMPT')) {
      statusColor = AppColors.zimRed;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: Colors.white,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.1),
          child: Icon(
            _iconForMethod(method),
            color: statusColor,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                action.toString(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (status != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 10,
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          '$userName • $time${method != null ? ' • $method' : ''}',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        children: [
          if (details != null && details.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: details.entries
                      .where((e) => e.value != null)
                      .map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${e.key}: ',
                                style: const TextStyle(
                                  fontFamily: 'Monospace',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  '${e.value}',
                                  style: const TextStyle(
                                    fontFamily: 'Monospace',
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _iconForMethod(String? method) {
    switch (method) {
      case 'QR_SCAN':
        return Icons.qr_code_scanner_rounded;
      case 'MANUAL_SEARCH':
        return Icons.search_rounded;
      case 'BIOMETRIC':
        return Icons.fingerprint_rounded;
      default:
        return Icons.history_rounded;
    }
  }
}

class _FilterOption {
  final String label;
  final String? action;
  final IconData icon;
  const _FilterOption({
    required this.label,
    required this.action,
    required this.icon,
  });
}
