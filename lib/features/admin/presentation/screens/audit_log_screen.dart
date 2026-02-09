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

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() => _isLoading = true);
    final logs = await SupabaseService.getLatestAuditLogs(limit: 50);
    if (mounted) {
      setState(() {
        _logs = logs;
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
          'System Audit Logs',
          style: TextStyle(fontSize: res.appBarTitleFont),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textMain,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchLogs,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _logs.isEmpty
            ? Center(
                child: Text(
                  'No logs found',
                  style: TextStyle(
                    fontSize: res.bodyFont,
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            : ListView.builder(
                padding: EdgeInsets.all(
                  res.pick(mobile: 16.0, tablet: 24.0, desktop: 32.0),
                ),
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  final log = _logs[index];
                  // Cast to Map<String, dynamic> to avoid errors if dynamic
                  final Map<String, dynamic> typedLog =
                      Map<String, dynamic>.from(log);
                  return _buildLogCard(typedLog, res);
                },
              ),
      ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log, ResponsiveSize res) {
    // Check fields safely
    final action = log['action'] ?? 'UNKNOWN';
    final profiles = log['profiles'] as Map<String, dynamic>?;
    final userName = profiles?['full_name'] ?? 'System / Anonymous';

    // timeago
    String time = '-';
    if (log['created_at'] != null) {
      try {
        time = timeago.format(
          DateTime.tryParse(log['created_at']) ?? DateTime.now(),
        );
      } catch (_) {}
    }

    final details = log['details'] as Map<String, dynamic>?;

    Color statusColor = Colors.blue;
    final act = action.toString().toUpperCase();
    if (act.contains('REGISTER')) statusColor = AppColors.sadcPink;
    if (act.contains('VERIFY')) statusColor = AppColors.zimGreen;
    if (act.contains('FAIL') ||
        act.contains('DELETE') ||
        act.contains('ATTEMPT'))
      statusColor = AppColors.zimRed;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.1),
          child: Icon(Icons.history, color: statusColor, size: 20),
        ),
        title: Text(
          action.toString(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '$userName • $time',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        children: [
          if (details != null && details.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: details.entries.map((e) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text(
                        '${e.key}: ${e.value}',
                        style: const TextStyle(
                          fontFamily: 'Monospace',
                          fontSize: 12,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
