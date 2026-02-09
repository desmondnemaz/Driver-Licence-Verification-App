import 'package:driver_license_verifier_app/core/services/supabase_service.dart';
import 'package:driver_license_verifier_app/features/driver_management/domain/models/driver_model.dart';
import 'package:driver_license_verifier_app/features/tscz/presentation/screens/certificate_form_screen.dart';
import 'package:driver_license_verifier_app/theme/app_colors.dart';
import 'package:driver_license_verifier_app/utils/responsive_sizes.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TsczDashboardScreen extends StatefulWidget {
  const TsczDashboardScreen({super.key});

  @override
  State<TsczDashboardScreen> createState() => _TsczDashboardScreenState();
}

class _TsczDashboardScreenState extends State<TsczDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<Driver> _drivers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  int _offset = 0;
  final int _limit = 20;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _fetchDrivers();
  }

  Future<void> _fetchDrivers({bool refresh = false}) async {
    if (refresh) {
      _offset = 0;
      _drivers.clear();
      _hasMore = true;
    }

    if (!_hasMore) return;

    setState(() => _isLoading = true);

    // Reusing the existing getDrivers service
    final newDrivers = await SupabaseService.getDrivers(
      limit: _limit,
      offset: _offset,
      query: _searchQuery,
      // We don't filter by license code here, we want all drivers
    );

    if (mounted) {
      setState(() {
        _drivers.addAll(newDrivers);
        _isLoading = false;
        if (newDrivers.length < _limit) {
          _hasMore = false;
        }
        _offset += _limit;
      });
    }
  }

  void _onSearch(String value) {
    setState(() {
      _searchQuery = value;
    });
    _fetchDrivers(refresh: true);
  }

  Widget _buildStatusChip(Driver driver) {
    if (driver.certificates.isEmpty) {
      return const Chip(
        label: Text('None', style: TextStyle(fontSize: 12)),
        backgroundColor: Colors.grey,
        labelPadding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      );
    }
    
    // Check if active certificate exists
    final now = DateTime.now();
    bool hasValid = false;
    
    final certs = List<DefensiveCertificate>.from(driver.certificates);
    try {
      // Find any valid certificate
      for (final cert in certs) {
         DateTime? expiry;
         // Try ISO YYYY-MM-DD
         expiry = DateTime.tryParse(cert.expiryDate);
         // Try dd/MM/yyyy fallback
         if (expiry == null) {
            try { expiry = DateFormat('dd/MM/yyyy').parse(cert.expiryDate); } catch(_) {}
         }
         
         if (expiry != null) {
            final today = DateTime(now.year, now.month, now.day);
            if (expiry.compareTo(today) >= 0) {
              hasValid = true;
              break; 
            }
         }
      }
    } catch (_) {}

    if (hasValid) {
       return const Chip(
        avatar: Icon(Icons.check_circle, size: 16, color: Colors.white),
        label: Text('Valid', style: TextStyle(color: Colors.white, fontSize: 12)),
        backgroundColor: AppColors.zimGreen,
        visualDensity: VisualDensity.compact,
      );
    } else {
      return const Chip(
        avatar: Icon(Icons.warning, size: 16, color: Colors.white),
        label: Text('Expired', style: TextStyle(color: Colors.white, fontSize: 12)),
        backgroundColor: AppColors.sadcPink,
        visualDensity: VisualDensity.compact,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final res = ResponsiveSize(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('TSCZ Dashboard', style: TextStyle(fontSize: res.appBarTitleFont)),
        backgroundColor: AppColors.sadcPink,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetchDrivers(refresh: true),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
             padding: EdgeInsets.all(res.pick(mobile: 16.0, tablet: 24.0, desktop: 32.0)),
             color: Colors.white,
             child: LayoutBuilder(
               builder: (context, constraints) {
                 bool isNarrow = constraints.maxWidth < 600;
                 
                 Widget searchField = TextField(
                    controller: _searchController,
                    onChanged: _onSearch,
                    decoration: InputDecoration(
                      hintText: 'Search Driver by Name or ID...',
                      prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                 );

                 if (isNarrow) {
                   return searchField;
                 } else {
                   return Row(
                     children: [
                       Expanded(child: searchField),
                       // Potentially add more filters here later if needed
                     ],
                   );
                 }
               }
             ),
          ),
          Expanded(
            child: _drivers.isEmpty && !_isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_off_outlined, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        Text('No drivers found', style: TextStyle(color: AppColors.textSecondary, fontSize: res.bodyFont)),
                      ],
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(AppColors.sadcPink.withValues(alpha: 0.1)),
                                  dataRowMinHeight: 60,
                                  dataRowMaxHeight: 80,
                                  columns: const [
                                    DataColumn(label: Text('Surname', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Names', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('ID Number', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Classes', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Cert. Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Cert. Number', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Expiry', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                                  ],
                                  rows: _drivers.map((driver) {
                                    final classes = driver.licenses.map((e) => e.licenseCode).toSet().join(", ");
                                    
                                    // Extract Cert Info
                                    String certNum = '-';
                                    String expiryDisplay = '-';
                                    
                                    if (driver.certificates.isNotEmpty) {
                                      final certs = List<DefensiveCertificate>.from(driver.certificates);
                                      try {
                                        certs.sort((a, b) {
                                          DateTime? dateA = DateTime.tryParse(a.expiryDate); // Try ISO first
                                          if (dateA == null) {
                                            try { dateA = DateFormat('dd/MM/yyyy').parse(a.expiryDate); } catch(_) {}
                                          }
                                          
                                          DateTime? dateB = DateTime.tryParse(b.expiryDate);
                                          if (dateB == null) {
                                            try { dateB = DateFormat('dd/MM/yyyy').parse(b.expiryDate); } catch(_) {}
                                          }
                                          
                                          if (dateA == null && dateB == null) return 0;
                                          if (dateA == null) return 1;
                                          if (dateB == null) return -1;
                                          return dateB.compareTo(dateA); 
                                        });
                                        
                                        final latest = certs.first;
                                        certNum = latest.certificateNumber;
                                        
                                        // Format for display
                                        DateTime? expDate = DateTime.tryParse(latest.expiryDate);
                                        if (expDate == null) {
                                           try { expDate = DateFormat('dd/MM/yyyy').parse(latest.expiryDate); } catch(_) {}
                                        }
                                        
                                        if (expDate != null) {
                                          expiryDisplay = DateFormat('dd/MM/yyyy').format(expDate);
                                        } else {
                                          expiryDisplay = latest.expiryDate;
                                        }
                                      } catch (_) {}
                                    }

                                    return DataRow(
                                      cells: [
                                        DataCell(Text(driver.surname.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w600))),
                                        DataCell(Text(driver.givenNames)),
                                        DataCell(Text(driver.idNumber)),
                                        DataCell(Text(classes.isNotEmpty ? classes : '-', style: const TextStyle(fontWeight: FontWeight.w600))),
                                        DataCell(_buildStatusChip(driver)),
                                        DataCell(Text(certNum, style: const TextStyle(fontFamily: 'Monospace'))),
                                        DataCell(Text(expiryDisplay)),
                                        DataCell(
                                          IconButton(
                                            icon: const Icon(Icons.edit_note_rounded, color: AppColors.textMain),
                                            tooltip: 'Manage Certificate',
                                            onPressed: () async {
                                              final result = await Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => CertificateFormScreen(
                                                    driverId: driver.id,
                                                    driverName: '${driver.surname} ${driver.givenNames}',
                                                    existingCertificate: driver.certificates.isNotEmpty ? driver.certificates.first : null,
                                                  ),
                                                ),
                                              );
                                              if (result == true) {
                                                _fetchDrivers(refresh: true);
                                              }
                                            },
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                            if (_hasMore)
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Center(
                                  child: _isLoading
                                      ? const CircularProgressIndicator()
                                      : OutlinedButton(
                                          onPressed: () => _fetchDrivers(),
                                          child: const Text('Load More'),
                                        ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
