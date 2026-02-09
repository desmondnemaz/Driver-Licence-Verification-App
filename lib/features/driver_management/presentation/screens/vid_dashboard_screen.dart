import 'package:driver_license_verifier_app/core/services/supabase_service.dart';
import 'package:driver_license_verifier_app/features/driver_management/domain/models/driver_model.dart';
import 'package:driver_license_verifier_app/features/driver_management/presentation/screens/registration_screen.dart';
import 'package:driver_license_verifier_app/theme/app_colors.dart';
import 'package:driver_license_verifier_app/utils/responsive_sizes.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class VidDashboardScreen extends StatefulWidget {
  const VidDashboardScreen({super.key});

  @override
  State<VidDashboardScreen> createState() => _VidDashboardScreenState();
}

class _VidDashboardScreenState extends State<VidDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<Driver> _drivers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedLicense = 'All';
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

    final newDrivers = await SupabaseService.getDrivers(
      limit: _limit,
      offset: _offset,
      query: _searchQuery,
      licenseCode: _selectedLicense,
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

  Future<void> _deleteDriver(Driver driver) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete ${driver.givenNames} ${driver.surname}? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await SupabaseService.deleteDriver(driver.id);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Driver deleted successfully'), backgroundColor: AppColors.zimGreen));
          _fetchDrivers(refresh: true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete driver'), backgroundColor: Colors.red));
        }
      }
    }
  }

  Widget _buildDefensiveStatusChip(Driver driver) {
    if (driver.certificates.isEmpty) {
      return const Chip(
        label: Text('None', style: TextStyle(fontSize: 12)),
        backgroundColor: Colors.grey,
        labelPadding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      );
    }
    
    final now = DateTime.now();
    bool hasValid = false;
    
    final certs = List<DefensiveCertificate>.from(driver.certificates);
    try {
      // Find any valid certificate
      for (final cert in certs) {
         DateTime? expiry;
         expiry = DateTime.tryParse(cert.expiryDate);
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
        title: Text('Driver Management', style: TextStyle(fontSize: res.appBarTitleFont)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetchDrivers(refresh: true),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const RegistrationScreen()),
          );
          if (result == true) {
            _fetchDrivers(refresh: true);
          }
        },
        label: const Text('Register Driver'),
        icon: const Icon(Icons.add),
        backgroundColor: AppColors.sadcPink,
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(res.pick(mobile: 16.0, tablet: 24.0, desktop: 32.0)),
            color: Colors.white,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // If width is small (e.g. mobile), stack them. Otherwise row.
                bool isNarrow = constraints.maxWidth < 600;
                
                Widget searchField = TextField(
                  controller: _searchController,
                  onChanged: _onSearch,
                  decoration: InputDecoration(
                    hintText: 'Search by Name or ID...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                );

                Widget filterDropdown = Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedLicense,
                      isExpanded: true,
                      items: ['All', 'A', 'B', 'BE', 'C', 'CE', 'D', 'DE', 'G']
                          .map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value == 'All' ? 'All Classes' : 'Class $value', overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedLicense = newValue;
                          });
                          _fetchDrivers(refresh: true);
                        }
                      },
                    ),
                  ),
                );

                if (isNarrow) {
                  return Column(
                    children: [
                      searchField,
                      const SizedBox(height: 12),
                      filterDropdown,
                    ],
                  );
                } else {
                  return Row(
                    children: [
                      Expanded(flex: 2, child: searchField),
                      const SizedBox(width: 16),
                      Expanded(flex: 1, child: filterDropdown),
                    ],
                  );
                }
              },
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
                                    DataColumn(label: Text('License No.', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Classes', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Defensive Cert', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                                  ],
                                  rows: _drivers.map((driver) {
                                    final classes = driver.licenses.map((e) => e.licenseCode).toSet().join(", ");
                                    return DataRow(
                                      cells: [
                                        DataCell(Text(driver.surname.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w600))),
                                        DataCell(Text(driver.givenNames)),
                                        DataCell(Text(driver.idNumber)),
                                        DataCell(Text(
                                          driver.licenses.isNotEmpty ? driver.licenses.first.licenseNumber : '-',
                                          style: const TextStyle(fontFamily: 'Monospace'),
                                        )),
                                        DataCell(Text(
                                          classes.isNotEmpty ? classes : '-',
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        )),
                                        DataCell(_buildDefensiveStatusChip(driver)),
                                        DataCell(Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit_outlined, color: AppColors.textMain),
                                              tooltip: 'Edit',
                                              onPressed: () async {
                                                final result = await Navigator.push(
                                                  context,
                                                  MaterialPageRoute(builder: (context) => RegistrationScreen(existingDriver: driver)),
                                                );
                                                if (result == true) {
                                                  _fetchDrivers(refresh: true);
                                                }
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                                              tooltip: 'Delete',
                                              onPressed: () => _deleteDriver(driver),
                                            ),
                                          ],
                                        )),
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
