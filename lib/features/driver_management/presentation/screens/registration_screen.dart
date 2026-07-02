import 'package:flutter/foundation.dart'; // Add this for kIsWeb
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:driver_license_verifier_app/theme/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:driver_license_verifier_app/utils/responsive_sizes.dart';

import 'package:driver_license_verifier_app/core/services/supabase_service.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

import 'package:driver_license_verifier_app/features/driver_management/domain/models/driver_model.dart';
import 'package:driver_license_verifier_app/core/services/fingerprint_service.dart';
import 'dart:typed_data';

class RegistrationScreen extends StatefulWidget {
  final Driver? existingDriver;
  const RegistrationScreen({super.key, this.existingDriver});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _surnameController = TextEditingController();
  final _nameController = TextEditingController();
  final _idController = TextEditingController();
  final _licenseController = TextEditingController();
  String? _gender;

  DateTime? _dob;
  DateTime? _issueDate;
  DateTime? _expiryDate;
  XFile? _imageFile;
  String? _existingImageUrl;
  bool _isLoadingImage = false;

  // Biometrics
  final Map<String, String?> _capturedTemplates = {
    'right_thumb': null,
    'left_thumb': null,
  };
  final Map<String, Uint8List?> _capturedImages = {
    'right_thumb': null,
    'left_thumb': null,
  };
  String? _currentlyCapturingFinger; // 'right_thumb' or 'left_thumb'
  final FingerprintService _fingerprintService = FingerprintService();

  // Availability Check
  bool _isIdChecked = false;
  bool _isIdAvailable = false;
  bool _isCheckingAvailability = false;
  String? _availabilityMessage;

  final List<String> _selectedCategories = [];
  final List<String> _availableCategories = [
    'A',
    'B',
    'BE',
    'C',
    'CE',
    'D',
    'DE',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingDriver != null) {
      final d = widget.existingDriver!;
      _surnameController.text = d.surname;
      _nameController.text = d.givenNames;
      _idController.text = d.idNumber;
      _gender = d.gender;

      // Parse dates (assumes DD/MM/YYYY)
      _dob = _tryParseDate(d.dob);

      if (d.licenses.isNotEmpty) {
        final l = d.licenses.first;
        _licenseController.text = l.licenseNumber;
        _issueDate = _tryParseDate(l.issueDate);
        _expiryDate = _tryParseDate(l.expiryDate);

        // Collect all codes from all license entries
        for (var lic in d.licenses) {
          if (!_selectedCategories.contains(lic.licenseCode)) {
            _selectedCategories.add(lic.licenseCode);
          }
        }
      }
      if (d.biometrics.isNotEmpty) {
        for (var bio in d.biometrics) {
          _capturedTemplates[bio.fingerType] = bio.templateData;
        }
      }
      _fetchExistingImage();
      // For existing drivers, we assume the ID is already checked unless they change it
      _isIdChecked = true;
      _isIdAvailable = true;
    }

    _idController.addListener(_onIdChanged);
  }

  void _onIdChanged() {
    if (_isIdChecked) {
      setState(() {
        _isIdChecked = false;
        _isIdAvailable = false;
        _availabilityMessage = null;
      });
    }
  }

  @override
  void dispose() {
    _idController.removeListener(_onIdChanged);
    super.dispose();
  }

  Future<void> _fetchExistingImage() async {
    if (widget.existingDriver?.driverImagePath != null) {
      setState(() => _isLoadingImage = true);
      final url = await SupabaseService.getImageUrl(
        widget.existingDriver!.driverImagePath,
      );
      if (mounted) {
        setState(() {
          _existingImageUrl = url;
          _isLoadingImage = false;
        });
      }
    }
  }

  DateTime? _tryParseDate(String dateStr) {
    // 1. Try ISO format (YYYY-MM-DD) which is often returned by database
    final isoDate = DateTime.tryParse(dateStr);
    if (isoDate != null) return isoDate;

    // 2. Try Zimbabwean format (DD/MM/YYYY)
    try {
      return DateFormat('dd/MM/yyyy').parse(dateStr);
    } catch (_) {
      return null;
    }
  }

  Future<void> _selectDate(BuildContext context, String type) async {
    final now = DateTime.now();
    DateTime firstDate = DateTime(1940);
    DateTime lastDate = DateTime(2050);
    DateTime initialDate = now;

    if (type == 'dob') {
      lastDate = DateTime(now.year - 16, now.month, now.day);
      if (_dob != null && _dob!.isBefore(lastDate)) {
        initialDate = _dob!;
      } else {
        initialDate = lastDate;
      }
    } else if (type == 'issue') {
      if (_issueDate != null) initialDate = _issueDate!;
    } else if (type == 'expiry') {
      if (_expiryDate != null) initialDate = _expiryDate!;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.sadcPink,
              onPrimary: Colors.white,
              onSurface: AppColors.textMain,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (type == 'dob') _dob = picked;
        if (type == 'issue') _issueDate = picked;
        if (type == 'expiry') _expiryDate = picked;
      });
    }
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Photo Gallery'),
              onTap: () {
                _getImage(ImageSource.gallery);
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Camera'),
              onTap: () {
                _getImage(ImageSource.camera);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _getImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 70);
    if (pickedFile != null) {
      setState(() {
        _imageFile = pickedFile;
      });
    }
  }

  Future<void> _checkAvailability() async {
    final id = _idController.text.replaceAll(RegExp(r'[-\s]'), '').toUpperCase();
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an ID number first')),
      );
      return;
    }

    setState(() {
      _isCheckingAvailability = true;
      _availabilityMessage = null;
    });

    try {
      // Check if it's the SAME ID as existing driver (if editing)
      if (widget.existingDriver != null &&
          id == widget.existingDriver!.idNumber.replaceAll(RegExp(r'[-\s]'), '').toUpperCase()) {
        setState(() {
          _isIdChecked = true;
          _isIdAvailable = true;
          _isCheckingAvailability = false;
          _availabilityMessage = 'Using current driver ID';
        });
        return;
      }

      final existing = await SupabaseService.getDriver(id, null);
      setState(() {
        _isIdChecked = true;
        _isCheckingAvailability = false;
        if (existing == null) {
          _isIdAvailable = true;
          _availabilityMessage = 'ID is available for registration';
        } else {
          _isIdAvailable = false;
          _availabilityMessage = 'A driver with this ID already exists';
        }
      });
    } catch (e) {
      setState(() {
        _isCheckingAvailability = false;
        _availabilityMessage = 'Error checking availability';
      });
    }
  }

  Future<void> _saveToSupabase() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isIdChecked || !_isIdAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_availabilityMessage ?? 'Please verify ID availability first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_dob == null || _issueDate == null || _expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select all required dates')),
      );
      return;
    }

    // Age validation (16+)
    final now = DateTime.now();
    int age = now.year - _dob!.year;
    if (now.month < _dob!.month ||
        (now.month == _dob!.month && now.day < _dob!.day)) {
      age--;
    }
    if (age < 16) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Driver must be at least 16 years old'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one license category'),
        ),
      );
      return;
    }

    if (_expiryDate!.isBefore(_issueDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('License expiry date cannot be before the issue date'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_imageFile == null && _existingImageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Driver photo is required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show loading context
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // Saving to Supabase
    String? errorMessage;
    if (widget.existingDriver != null) {
      errorMessage = await SupabaseService.updateDriverWithLicenses(
        driverId: widget.existingDriver!.id,
        surname: _surnameController.text.toUpperCase(),
        givenNames: _nameController.text.toUpperCase(),
        dob: DateFormat('dd/MM/yyyy').format(_dob!),
        idNumber: _idController.text
            .replaceAll(RegExp(r'[-\s]'), '')
            .toUpperCase(),
        licenseNumber: _licenseController.text.toUpperCase(),
        issueDate: DateFormat('dd/MM/yyyy').format(_issueDate!),
        expiryDate: DateFormat('dd/MM/yyyy').format(_expiryDate!),
        codes: _selectedCategories,
        imageFile: _imageFile,
        currentImagePath: widget.existingDriver!.driverImagePath,
        gender: _gender,
        biometrics: _capturedTemplates.entries
            .where((e) => e.value != null)
            .map((e) => {'finger_type': e.key, 'template_data': e.value!})
            .toList(),
      );
    } else {
      errorMessage = await SupabaseService.saveDriverWithLicenses(
        surname: _surnameController.text.toUpperCase(),
        givenNames: _nameController.text.toUpperCase(),
        dob: DateFormat('dd/MM/yyyy').format(_dob!),
        idNumber: _idController.text
            .replaceAll(RegExp(r'[-\s]'), '')
            .toUpperCase(),
        licenseNumber: _licenseController.text.toUpperCase(),
        issueDate: DateFormat('dd/MM/yyyy').format(_issueDate!),
        expiryDate: DateFormat('dd/MM/yyyy').format(_expiryDate!),
        codes: _selectedCategories,
        imageFile: _imageFile,
        gender: _gender,
        biometrics: _capturedTemplates.entries
            .where((e) => e.value != null)
            .map((e) => {'finger_type': e.key, 'template_data': e.value!})
            .toList(),
      );
    }

    if (!mounted) return;
    Navigator.pop(context); // Pop loading

    if (errorMessage == null) {
      final String successMessage;
      if (widget.existingDriver != null) {
        if (widget.existingDriver!.wasPlaintextInDb) {
          successMessage = 'Driver details updated (first name and surname encrypted for security)';
        } else {
          successMessage = 'Driver details updated';
        }
      } else {
        successMessage = 'Driver registered (first name and surname encrypted for security)';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: AppColors.zimGreen,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final res = ResponsiveSize(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.existingDriver != null ? 'Edit Driver' : 'Driver Registration',
          style: TextStyle(fontSize: res.appBarTitleFont),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(res),
            Padding(
              padding: EdgeInsets.all(
                res.pick(mobile: 24.0, tablet: 40.0, desktop: 60.0),
              ),
              child: Form(
                key: _formKey,
                child: Center(
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: res.pick(
                        mobile: double.infinity,
                        tablet: 600,
                        desktop: 800,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSectionTitle('Personal Information', res),
                        _buildGenderDropdown(res),
                        const SizedBox(height: 16),
                        _buildTextField(
                          _surnameController,
                          '1. Surname',
                          Icons.person_outline,
                          res,
                        ),
                        SizedBox(
                          height: res.pick(
                            mobile: 16.0,
                            tablet: 24.0,
                            desktop: 32.0,
                          ),
                        ),
                        _buildTextField(
                          _nameController,
                          '2. Name(s)',
                          Icons.badge_outlined,
                          res,
                        ),
                        SizedBox(
                          height: res.pick(
                            mobile: 16.0,
                            tablet: 24.0,
                            desktop: 32.0,
                          ),
                        ),
                        _buildDatePicker(
                          '3. Date of Birth',
                          _dob,
                          () => _selectDate(context, 'dob'),
                          res,
                        ),
                        SizedBox(
                          height: res.pick(
                            mobile: 16.0,
                            tablet: 24.0,
                            desktop: 32.0,
                          ),
                        ),

                        SizedBox(
                          height: res.pick(
                            mobile: 16.0,
                            tablet: 24.0,
                            desktop: 32.0,
                          ),
                        ),
                        _buildIdField(res),
                        if (_availabilityMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8, left: 16),
                            child: Text(
                              _availabilityMessage!,
                              style: TextStyle(
                                fontSize: 12,
                                color: _isIdAvailable
                                    ? AppColors.zimGreen
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),
                        _buildFingerprintSection(res),

                        SizedBox(
                          height: res.pick(
                            mobile: 32.0,
                            tablet: 48.0,
                            desktop: 64.0,
                          ),
                        ),
                        _buildSectionTitle('License Details', res),
                        _buildTextField(
                          _licenseController,
                          '5. License Number',
                          Icons.numbers_rounded,
                          res,
                        ),
                        SizedBox(
                          height: res.pick(
                            mobile: 16.0,
                            tablet: 24.0,
                            desktop: 32.0,
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDatePicker(
                                'First Issue',
                                _issueDate,
                                () => _selectDate(context, 'issue'),
                                res,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildDatePicker(
                                'Expiry Date',
                                _expiryDate,
                                () => _selectDate(context, 'expiry'),
                                res,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildCategorySelector(res),

                        SizedBox(
                          height: res.pick(
                            mobile: 48.0,
                            tablet: 60.0,
                            desktop: 80.0,
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _saveToSupabase,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            backgroundColor: AppColors.zimGreen,
                          ),
                          child: Text(
                            widget.existingDriver != null
                                ? 'Save Changes'
                                : 'Confirm Registration',
                            style: TextStyle(
                              fontSize: res.pick(
                                mobile: 18.0,
                                tablet: 20.0,
                                desktop: 24.0,
                              ),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ResponsiveSize res) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: res.pick(mobile: 32, tablet: 48, desktop: 64),
        horizontal: 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.sadcPink,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: CircleAvatar(
                radius: res.pick(mobile: 50.0, tablet: 60.0, desktop: 80.0),
                backgroundColor: Colors.grey[200],
                backgroundImage: _imageFile != null
                    ? (kIsWeb
                          ? NetworkImage(_imageFile!.path) as ImageProvider
                          : FileImage(File(_imageFile!.path)))
                    : (_existingImageUrl != null
                          ? NetworkImage(_existingImageUrl!)
                          : null),
                child: (_imageFile == null && _existingImageUrl == null)
                    ? (_isLoadingImage
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Icon(
                              Icons.add_a_photo_rounded,
                              size: res.pick(
                                mobile: 40.0,
                                tablet: 50.0,
                                desktop: 60.0,
                              ),
                              color: AppColors.sadcPink,
                            ))
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _imageFile == null ? 'Upload Driver Photo' : 'Photo Attached',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, ResponsiveSize res) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: res.pick(mobile: 20.0, tablet: 22.0, desktop: 28.0),
          fontWeight: FontWeight.bold,
          color: AppColors.textMain,
        ),
      ),
    );
  }

  Widget _buildIdField(ResponsiveSize res) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildTextField(
            _idController,
            '5. ID Number (No hyphens)',
            Icons.credit_card_outlined,
            res,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 56, // Match textfield height roughly
          child: ElevatedButton(
            onPressed: _isCheckingAvailability ? null : _checkAvailability,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isIdChecked
                  ? (_isIdAvailable ? AppColors.zimGreen : Colors.red)
                  : AppColors.sadcPink,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(res.borderRadius * 1.5),
              ),
            ),
            child: _isCheckingAvailability
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    _isIdChecked
                        ? (_isIdAvailable ? Icons.check_circle : Icons.error)
                        : Icons.search,
                    color: Colors.white,
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon,
    ResponsiveSize res, {
    bool isOptional = false,
  }) {
    return TextFormField(
      controller: controller,
      style: TextStyle(fontSize: res.bodyFont),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: res.labelFont),
        prefixIcon: Icon(icon, color: AppColors.sadcPink, size: res.icon * 0.7),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(res.borderRadius * 1.5),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(res.borderRadius * 1.5),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      validator: (value) {
        if (isOptional) return null;
        return value!.isEmpty ? 'Field required' : null;
      },
    );
  }

  Widget _buildDatePicker(
    String label,
    DateTime? date,
    VoidCallback onTap,
    ResponsiveSize res,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(res.borderRadius * 1.5),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: res.icon * 0.6,
              color: AppColors.sadcPink,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: res.captionFont,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  date != null
                      ? DateFormat('dd/MM/yyyy').format(date)
                      : 'Select Date',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: res.bodyFont,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelector(ResponsiveSize res) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '9. Vehicle Categories',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: res.titleFont,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableCategories.map((cat) {
            final isSelected = _selectedCategories.contains(cat);
            return FilterChip(
              label: Text(cat),
              selected: isSelected,
              onSelected: (bool selected) {
                setState(() {
                  if (selected) {
                    _selectedCategories.add(cat);
                  } else {
                    _selectedCategories.remove(cat);
                  }
                });
              },
              selectedColor: AppColors.sadcPink.withValues(alpha: 0.2),
              checkmarkColor: AppColors.sadcPink,
              labelStyle: TextStyle(
                fontSize: res.labelFont,
                color: isSelected ? AppColors.sadcPink : AppColors.textMain,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildGenderDropdown(ResponsiveSize res) {
    return DropdownButtonFormField<String>(
      value: _gender,
      decoration: InputDecoration(
        labelText: 'Gender',
        prefixIcon: Icon(Icons.people_outline, color: AppColors.sadcPink),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(res.borderRadius * 1.5),
        ),
      ),
      items: ['Male', 'Female'].map((String value) {
        return DropdownMenuItem<String>(value: value, child: Text(value));
      }).toList(),
      onChanged: (val) => setState(() => _gender = val),
      validator: (val) => val == null ? 'Gender is required' : null,
    );
  }

  Widget _buildFingerprintSection(ResponsiveSize res) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Biometric Information', res),
        _buildFingerprintRow(res, 'Right Thumb', 'right_thumb'),
        const SizedBox(height: 12),
        _buildFingerprintRow(res, 'Left Thumb', 'left_thumb'),
      ],
    );
  }

  Widget _buildFingerprintRow(
    ResponsiveSize res,
    String label,
    String fingerType,
  ) {
    final bool isCaptured = _capturedTemplates[fingerType] != null;
    final bool isBusy = _currentlyCapturingFinger == fingerType;
    final Uint8List? image = _capturedImages[fingerType];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(res.borderRadius * 1.5),
        border: Border.all(
          color: isBusy ? AppColors.sadcPink : Colors.grey[200]!,
          width: isBusy ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 70,
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isCaptured ? AppColors.zimGreen : AppColors.sadcPink,
                    width: 1,
                  ),
                ),
                child: image != null
                    ? Image.memory(image, fit: BoxFit.contain)
                    : Icon(
                        Icons.fingerprint,
                        size: 35,
                        color: isCaptured ? AppColors.zimGreen : Colors.white10,
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: res.bodyFont,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isCaptured ? 'Captured' : 'Not enrolled',
                      style: TextStyle(
                        fontSize: res.captionFont,
                        color: isCaptured
                            ? AppColors.zimGreen
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              isBusy
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      onPressed: () => _captureFingerprint(fingerType),
                      icon: Icon(
                        isCaptured
                            ? Icons.refresh_rounded
                            : Icons.add_circle_outline_rounded,
                        color: AppColors.sadcPink,
                      ),
                    ),
            ],
          ),
          if (isBusy)
            const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Text(
                "Place finger on scanner...",
                style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _captureFingerprint(String fingerType) async {
    setState(() => _currentlyCapturingFinger = fingerType);
    try {
      bool ok = await _fingerprintService.initializeScanner();
      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to initialize scanner.')),
        );
        return;
      }

      final result = await _fingerprintService.enrollFinger();
      if (result != null) {
        final template = result['template'];
        
        // Check Uniqueness
        final ownerName = await SupabaseService.checkFingerprintUniqueness(template, widget.existingDriver?.id);
        
        if (ownerName != null) {
          if (mounted) {
            setState(() => _currentlyCapturingFinger = null);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Duplicate Fingerprint: This biometric is already registered to $ownerName.'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
          return;
        }

        setState(() {
          _capturedTemplates[fingerType] = template;
          _capturedImages[fingerType] = result['image'];
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${fingerType.replaceAll('_', ' ')} captured!'),
            backgroundColor: AppColors.zimGreen,
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Capture failed.')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _currentlyCapturingFinger = null);
    }
  }
}
