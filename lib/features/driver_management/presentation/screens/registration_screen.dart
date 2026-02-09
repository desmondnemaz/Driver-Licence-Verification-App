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
  final _restrictionsController = TextEditingController();
  
  DateTime? _dob;
  DateTime? _issueDate;
  DateTime? _expiryDate;
  XFile? _imageFile; // Change to XFile
  
  final List<String> _selectedCategories = [];
  final List<String> _availableCategories = ['A', 'B', 'BE', 'C', 'CE', 'D', 'DE', 'G'];

  @override
  void initState() {
    super.initState();
    if (widget.existingDriver != null) {
      final d = widget.existingDriver!;
      _surnameController.text = d.surname;
      _nameController.text = d.givenNames;
      _idController.text = d.idNumber;
      _restrictionsController.text = d.restrictions ?? '';
      
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
    }
  }

  DateTime? _tryParseDate(String dateStr) {
    try {
      return DateFormat('dd/MM/yyyy').parse(dateStr);
    } catch (_) {
      return null;
    }
  }

  Future<void> _selectDate(BuildContext context, String type) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1940),
      lastDate: DateTime(2050),
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

  Future<void> _saveToSupabase() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_dob == null || _issueDate == null || _expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select all required dates')),
      );
      return;
    }

    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one license category')),
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
    bool success;
    if (widget.existingDriver != null) {
      success = await SupabaseService.updateDriverWithLicenses(
        driverId: widget.existingDriver!.id,
        surname: _surnameController.text.toUpperCase(),
        givenNames: _nameController.text.toUpperCase(),
        dob: DateFormat('dd/MM/yyyy').format(_dob!),
        idNumber: _idController.text.replaceAll(RegExp(r'[-\s]'), '').toUpperCase(),
        licenseNumber: _licenseController.text.toUpperCase(),
        issueDate: DateFormat('dd/MM/yyyy').format(_issueDate!),
        expiryDate: DateFormat('dd/MM/yyyy').format(_expiryDate!),
        codes: _selectedCategories,
        imageFile: _imageFile,
        currentImagePath: widget.existingDriver!.driverImagePath,
        restrictions: _restrictionsController.text.toUpperCase(),
      );
    } else {
      success = await SupabaseService.saveDriverWithLicenses(
        surname: _surnameController.text.toUpperCase(),
        givenNames: _nameController.text.toUpperCase(),
        dob: DateFormat('dd/MM/yyyy').format(_dob!),
        idNumber: _idController.text.replaceAll(RegExp(r'[-\s]'), '').toUpperCase(),
        licenseNumber: _licenseController.text.toUpperCase(),
        issueDate: DateFormat('dd/MM/yyyy').format(_issueDate!),
        expiryDate: DateFormat('dd/MM/yyyy').format(_expiryDate!),
        codes: _selectedCategories,
        imageFile: _imageFile,
        restrictions: _restrictionsController.text.toUpperCase(),
      );
    }

    if (!mounted) return;
    Navigator.pop(context); // Pop loading

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.existingDriver != null ? 'Driver details updated' : 'Driver registered with secure image upload'),
          backgroundColor: AppColors.zimGreen,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save to Supabase. Check network and RLS policies.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final res = ResponsiveSize(context);
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.existingDriver != null ? 'Edit Driver' : 'Driver Registration', style: TextStyle(fontSize: res.appBarTitleFont)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(res),
            Padding(
              padding: EdgeInsets.all(res.pick(mobile: 24.0, tablet: 40.0, desktop: 60.0)),
              child: Form(
                key: _formKey,
                child: Center(
                  child: Container(
                    constraints: BoxConstraints(maxWidth: res.pick(mobile: double.infinity, tablet: 600, desktop: 800)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSectionTitle('Personal Information', res),
                        _buildTextField(_surnameController, '1. Surname', Icons.person_outline, res),
                        SizedBox(height: res.pick(mobile: 16.0, tablet: 24.0, desktop: 32.0)),
                        _buildTextField(_nameController, '2. Name(s)', Icons.badge_outlined, res),
                        SizedBox(height: res.pick(mobile: 16.0, tablet: 24.0, desktop: 32.0)),
                        _buildDatePicker('3. Date of Birth', _dob, () => _selectDate(context, 'dob'), res),
                        SizedBox(height: res.pick(mobile: 16.0, tablet: 24.0, desktop: 32.0)),
                        _buildTextField(_idController, '4d. ID Number (No hyphens)', Icons.credit_card_outlined, res),
                        
                        SizedBox(height: res.pick(mobile: 32.0, tablet: 48.0, desktop: 64.0)),
                        _buildSectionTitle('License Details', res),
                        _buildTextField(_licenseController, '5. License Number', Icons.numbers_rounded, res),
                        SizedBox(height: res.pick(mobile: 16.0, tablet: 24.0, desktop: 32.0)),
                        Row(
                          children: [
                            Expanded(child: _buildDatePicker('First Issue', _issueDate, () => _selectDate(context, 'issue'), res)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildDatePicker('Expiry Date', _expiryDate, () => _selectDate(context, 'expiry'), res)),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildTextField(_restrictionsController, 'Vehicle Restrictions (Optional)', Icons.info_outline, res),
                        const SizedBox(height: 24),
                        _buildCategorySelector(res),
                        
                        SizedBox(height: res.pick(mobile: 48.0, tablet: 60.0, desktop: 80.0)),
                        ElevatedButton(
                          onPressed: _saveToSupabase,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            backgroundColor: AppColors.zimGreen,
                          ),
                          child: Text(
                            widget.existingDriver != null ? 'Save Changes' : 'Confirm Registration',
                            style: TextStyle(fontSize: res.pick(mobile: 18.0, tablet: 20.0, desktop: 24.0), fontWeight: FontWeight.bold),
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
      padding: EdgeInsets.symmetric(vertical: res.pick(mobile: 32, tablet: 48, desktop: 64), horizontal: 24),
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
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: CircleAvatar(
                radius: res.pick(mobile: 50.0, tablet: 60.0, desktop: 80.0),
                backgroundColor: Colors.grey[200],
                backgroundImage: _imageFile != null
                    ? (kIsWeb
                        ? NetworkImage(_imageFile!.path) as ImageProvider
                        : FileImage(File(_imageFile!.path)))
                    : null,
                child: _imageFile == null 
                  ? Icon(Icons.add_a_photo_rounded, size: res.pick(mobile: 40.0, tablet: 50.0, desktop: 60.0), color: AppColors.sadcPink)
                  : null,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _imageFile == null ? 'Upload Driver Photo' : 'Photo Attached',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, ResponsiveSize res) {
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
      validator: (value) => value!.isEmpty ? 'Field required' : null,
    );
  }

  Widget _buildDatePicker(String label, DateTime? date, VoidCallback onTap, ResponsiveSize res) {
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
            Icon(Icons.calendar_today_rounded, size: res.icon * 0.6, color: AppColors.sadcPink),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: res.captionFont, color: AppColors.textSecondary)),
                Text(
                  date != null ? DateFormat('dd/MM/yyyy').format(date) : 'Select Date',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: res.bodyFont),
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
        Text('9. Vehicle Categories', style: TextStyle(fontWeight: FontWeight.bold, fontSize: res.titleFont)),
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
}
