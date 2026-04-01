import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:driver_license_verifier_app/features/driver_management/domain/models/driver_model.dart';

class SupabaseService {
  static final SupabaseClient client = Supabase.instance.client;

  // Authentication Methods
  static Future<String?> signIn(String email, String password) async {
    try {
      await client.auth.signInWithPassword(email: email, password: password);
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'An unexpected error occurred';
    }
  }

  static Future<String?> signUp({
    required String email,
    required String password,
    required String fullName,
    required String ecNumber,
    required String role,
    String? station,
    String? phoneNumber,
  }) async {
    try {
      final AuthResponse res = await client.auth.signUp(
        email: email,
        password: password,
      );

      final String? userId = res.user?.id;
      if (userId == null) return 'User identification failed';

      await client.from('profiles').insert({
        'id': userId,
        'ec_number': ecNumber,
        'full_name': fullName,
        'role': role,
        'email': email,
        'phone_number': phoneNumber,
        'station': station,
        'is_approved': false,
      });

      // Log User Registration
      logAudit(
        action: 'REGISTER_USER',
        targetEntityId: userId,
        details: {'full_name': fullName, 'role': role, 'ec_number': ecNumber},
      );

      return null; // Success
    } on AuthException catch (e) {
      debugPrint('Sign Up Auth Error: ${e.message}');
      return e.message;
    } catch (e) {
      debugPrint('Sign Up Error: $e');
      return e.toString();
    }
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  static Future<Map<String, dynamic>?> getCurrentProfile() async {
    final user = client.auth.currentUser;
    if (user == null) return null;

    try {
      return await client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
    } catch (e) {
      debugPrint('Profile Fetch Error: $e');
      return null;
    }
  }

  // Admin: User Management Methods
  static Future<List<Map<String, dynamic>>> getAllProfiles() async {
    try {
      return await client
          .from('profiles')
          .select()
          .order(
            'created_at',
            ascending: false,
          ); // Assuming created_at exists, or order by name
    } catch (e) {
      debugPrint('Fetch All Profiles Error: $e');
      return [];
    }
  }

  static Future<bool> updateProfileStatus(String id, bool isApproved) async {
    try {
      await client
          .from('profiles')
          .update({'is_approved': isApproved})
          .eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Update Status Error: $e');
      return false;
    }
  }

  static Future<bool> updateProfileRole(String id, String role) async {
    try {
      await client.from('profiles').update({'role': role}).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Update Role Error: $e');
      return false;
    }
  }

  static Future<bool> deleteProfile(String id) async {
    try {
      // Note: Deleting from 'profiles' might not delete from 'auth.users' unless there is a trigger
      // implementing that, or if we use the Supabase Admin API (server-side).
      // Client-side SDK cannot delete from auth.users easily without a Function/RPC.
      // For now, we delete the profile which effectively removes them from the app logic.
      await client.from('profiles').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Delete Profile Error: $e');
      return false;
    }
  }

  static Future<String?> getImageUrl(String? path) async {
    if (path == null) return null;
    try {
      debugPrint(
        'Fetching signed URL for path: $path from bucket: driver-images',
      );
      final url = await client.storage
          .from('driver-images')
          .createSignedUrl(path, 3600); // 1 hour link
      debugPrint('Successfully generated signed URL: $url');
      return url;
    } catch (e) {
      debugPrint('Error getting image URL for path $path: $e');
      return null;
    }
  }

  static Future<List<DriverBiometric>> getAllBiometrics() async {
    try {
      final data = await client.from('driver_biometrics').select('*');
      return (data as List).map((b) => DriverBiometric.fromJson(b)).toList();
    } catch (e) {
      debugPrint('Error fetching all biometrics: $e');
      return [];
    }
  }

  static Future<String?> checkFingerprintUniqueness(
    String templateData,
    String? excludeDriverId,
  ) async {
    try {
      final query = client
          .from('driver_biometrics')
          .select('driver_id, drivers(surname, given_names)')
          .eq('template_data', templateData);

      if (excludeDriverId != null) {
        query.neq('driver_id', excludeDriverId);
      }

      final result = await query.maybeSingle();
      if (result != null) {
        final driver = result['drivers'];
        if (driver != null) {
          return '${driver['surname']} ${driver['given_names']}';
        }
        return 'Another driver';
      }
      return null;
    } catch (e) {
      debugPrint('Fingerprint Check Error: $e');
      return null;
    }
  }

  static Future<Driver?> getDriverById(String driverId) async {
    try {
      final data = await client
          .from('drivers')
          .select(
            '*, driver_licenses(*), defensive_certificates(*), driver_biometrics(*)',
          )
          .eq('id', driverId)
          .maybeSingle();

      if (data == null) return null;
      return Driver.fromJson(data);
    } catch (e) {
      debugPrint('Error fetching driver by ID: $e');
      return null;
    }
  }

  static Future<Driver?> getDriver(
    String? idNumber,
    String? licenseNumber,
  ) async {
    try {
      // 1. Try by ID Number if provided
      if (idNumber != null && idNumber.isNotEmpty) {
        final dataById = await client
            .from('drivers')
            .select(
              '*, driver_licenses(*), defensive_certificates(*), driver_biometrics(*)',
            )
            .eq('id_number', idNumber)
            .maybeSingle();

        if (dataById != null) {
          return Driver.fromJson(dataById);
        }
      }

      // 2. If provided, try by License Number
      if (licenseNumber != null && licenseNumber.isNotEmpty) {
        final licenseData = await client
            .from('driver_licenses')
            .select(
              '*, drivers(*, driver_licenses(*), defensive_certificates(*), driver_biometrics(*))',
            )
            .eq('license_number', licenseNumber)
            .maybeSingle();

        if (licenseData != null && licenseData['drivers'] != null) {
          return Driver.fromJson(licenseData['drivers']);
        }
      }
    } catch (e) {
      debugPrint('Supabase Error: $e');
    }
    return null;
  }

  static Future<Map<String, int>> getAdminStats() async {
    try {
      final driversRes = await client.from('drivers').count(CountOption.exact);
      final driversCount = driversRes;

      final usersRes = await client.from('profiles').count(CountOption.exact);
      final usersCount = usersRes;

      int verificationsCount = 0;
      try {
        final verificationsRes = await client
            .from('audit_logs')
            .count(CountOption.exact)
            .eq('action', 'VERIFY_LICENSE');
        verificationsCount = verificationsRes;
      } catch (_) {}

      int alertsCount = 0;
      try {
        final alertsRes = await client
            .from('audit_logs')
            .count(CountOption.exact)
            .eq('action', 'SCAN_ATTEMPT');
        alertsCount = alertsRes;
      } catch (_) {}

      return {
        'total_drivers': driversCount,
        'active_users': usersCount,
        'verifications': verificationsCount,
        'alerts': alertsCount,
      };
    } catch (e) {
      debugPrint('Stats Error: $e');
      return {
        'total_drivers': 0,
        'active_users': 0,
        'verifications': 0,
        'alerts': 0
      };
    }
  }

  static Future<void> logAudit({
    required String action,
    Map<String, dynamic>? details,
    String? targetEntityId,
  }) async {
    try {
      final user = client.auth.currentUser;
      await client.from('audit_logs').insert({
        'action': action,
        'performed_by': user?.id,
        'target_entity_id': targetEntityId,
        'details': details,
      });
    } catch (e) {
      debugPrint('Audit Log Error: $e');
    }
  }



  static Future<List<Map<String, dynamic>>> getLatestAuditLogs({
    int limit = 5,
  }) async {
    try {
      return await client
          .from('audit_logs')
          .select('*, profiles(full_name)')
          .order('created_at', ascending: false)
          .limit(limit);
    } catch (e) {
      if (e.toString().contains('PGRST200')) {
        debugPrint('Relationship missing, falling back to simple audit log fetch.');
        try {
          return await client
              .from('audit_logs')
              .select('*')
              .order('created_at', ascending: false)
              .limit(limit);
        } catch (e2) {
          debugPrint('Fallback fetch failed: $e2');
        }
      }
      debugPrint('Get Latest Audit Logs Error: $e');
      return [];
    }
  }

  /// Paginated audit logs with optional action-type filtering.
  /// [actionFilter] can be 'VERIFY_LICENSE', 'REGISTER_DRIVER', etc.
  static Future<List<Map<String, dynamic>>> getAuditLogs({
    int limit = 30,
    int offset = 0,
    String? actionFilter,
  }) async {
    try {
      // Build filter query first (eq must come before order/range)
      final filterQuery = client
          .from('audit_logs')
          .select('*, profiles(full_name)');

      if (actionFilter != null && actionFilter.isNotEmpty) {
        return await filterQuery
            .eq('action', actionFilter)
            .order('created_at', ascending: false)
            .range(offset, offset + limit - 1);
      }

      return await filterQuery
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
    } catch (e) {
      if (e.toString().contains('PGRST200')) {
        debugPrint('Relationship missing, falling back to simple audit log fetch.');
        try {
          var fallback = client.from('audit_logs').select('*');
          if (actionFilter != null && actionFilter.isNotEmpty) {
            return await fallback
                .eq('action', actionFilter)
                .order('created_at', ascending: false)
                .range(offset, offset + limit - 1);
          }
          return await fallback
              .order('created_at', ascending: false)
              .range(offset, offset + limit - 1);
        } catch (e2) {
          debugPrint('Fallback fetch failed: $e2');
        }
      }
      debugPrint('Get Audit Logs Error: $e');
      return [];
    }
  }

  static Future<String?> updateDriverWithLicenses({
    required String driverId,
    required String surname,
    required String givenNames,
    required String dob,
    required String idNumber,
    required String licenseNumber,
    required String issueDate,
    required String expiryDate,
    required List<String> codes,
    XFile? imageFile,
    String? currentImagePath,
    String? gender,
    List<Map<String, String>>? biometrics, // [{finger_type: '...', template_data: '...'}]
  }) async {
    try {
      // 0. Check for duplicates if ID or license changed
      final existing = await getDriver(idNumber, licenseNumber);
      if (existing != null && existing.id != driverId) {
        if (existing.idNumber == idNumber) {
          return 'A driver with this ID number already exists';
        }
        for (var lic in existing.licenses) {
          if (lic.licenseNumber == licenseNumber) {
            return 'A driver with this license number already exists';
          }
        }
      }

      // 0b. Check Fingerprint Uniqueness
      if (biometrics != null && biometrics.isNotEmpty) {
        for (var bio in biometrics) {
          final template = bio['template_data'];
          if (template != null) {
            final ownerName = await checkFingerprintUniqueness(template, driverId);
            if (ownerName != null) {
              return 'This fingerprint is already registered to $ownerName';
            }
          }
        }
      }

      String? imagePath = currentImagePath;

      // 1. Upload new image if provided
      if (imageFile != null) {
        final extension = imageFile.path.split('.').last;
        final fileName =
            '${idNumber}_${DateTime.now().millisecondsSinceEpoch}.$extension';
        final bytes = await imageFile.readAsBytes();
        await client.storage
            .from('driver-images')
            .uploadBinary(
              fileName,
              bytes,
              fileOptions: const FileOptions(upsert: true),
            );
        imagePath = fileName;
      }

      // 2. Update Driver
      await client
          .from('drivers')
          .update({
            'surname': surname,
            'given_names': givenNames,
            'dob': _parseDate(dob),
            'id_number': idNumber,
            'driver_image_path': imagePath,
            'gender': gender,
          })
          .eq('id', driverId);

      // 3. Replace Licenses
      // First delete existing
      await client.from('driver_licenses').delete().eq('driver_id', driverId);

      // Then insert new ones
      final List<Map<String, dynamic>> licenseInserts = codes
          .map(
            (code) => {
              'driver_id': driverId,
              'license_number': licenseNumber,
              'license_code': code,
              'issue_date': _parseDate(issueDate),
              'expiry_date': _parseDate(expiryDate),
            },
          )
          .toList();

      await client.from('driver_licenses').insert(licenseInserts);

      // 4. Update Biometrics
      if (biometrics != null && biometrics.isNotEmpty) {
        // Simple strategy: delete and re-insert or use upsert if we have IDs.
        // Given the unique constraint (driver_id, finger_type), we can upsert or delete-insert.
        await client
            .from('driver_biometrics')
            .delete()
            .eq('driver_id', driverId);

        final bioInserts = biometrics
            .map(
              (b) => {
                'driver_id': driverId,
                'finger_type': b['finger_type'],
                'template_data': b['template_data'],
              },
            )
            .toList();

        await client.from('driver_biometrics').insert(bioInserts);
      }

      return null; // Success
    } catch (e) {
      debugPrint('Supabase Update Error: $e');
      return 'Failed to update driver: ${e.toString()}';
    }
  }

  static Future<String?> saveDriverWithLicenses({
    required String surname,
    required String givenNames,
    required String dob,
    required String idNumber,
    required String licenseNumber,
    required String issueDate,
    required String expiryDate,
    required List<String> codes,
    XFile? imageFile,
    String? gender,
    List<Map<String, String>>? biometrics,
  }) async {
    try {
      // 0. Duplicate Check
      final existing = await getDriver(idNumber, licenseNumber);
      if (existing != null) {
        if (existing.idNumber == idNumber) {
          return 'A driver with this ID number already exists';
        }
        for (var lic in existing.licenses) {
          if (lic.licenseNumber == licenseNumber) {
            return 'A driver with this license number already exists';
          }
        }
        return 'A driver with these details already exists';
      }

      // 0b. Check Fingerprint Uniqueness
      if (biometrics != null && biometrics.isNotEmpty) {
        for (var bio in biometrics) {
          final template = bio['template_data'];
          if (template != null) {
            final ownerName = await checkFingerprintUniqueness(template, null);
            if (ownerName != null) {
              return 'This fingerprint is already registered to $ownerName';
            }
          }
        }
      }

      String? imagePath;

      // 1. Upload Image if exists
      if (imageFile != null) {
        final extension = imageFile.path.split('.').last;
        final fileName =
            '${idNumber}_${DateTime.now().millisecondsSinceEpoch}.$extension';
        final bytes = await imageFile.readAsBytes();
        await client.storage
            .from('driver-images')
            .uploadBinary(
              fileName,
              bytes,
              fileOptions: const FileOptions(upsert: true),
            );
        imagePath = fileName;
      }

      // 2. Insert Driver
      // Note: we need 'registered_by' which requires a profile.
      // For now, if not logged in, this might fail unless we have a dummy or allow null in DB.
      // The user schema says references public.profiles(id), NOT NULL not specified but usually implied.
      final driverResponse = await client
          .from('drivers')
          .insert({
            'surname': surname,
            'given_names': givenNames,
            'dob': _parseDate(dob), // format for PG date: YYYY-MM-DD
            'id_number': idNumber,
            'driver_image_path': imagePath,
            'gender': gender,
            'registered_by': client.auth.currentUser?.id,
          })
          .select()
          .single();

      final String driverId = driverResponse['id'];

      // Log Registration
      logAudit(
        action: 'REGISTER_DRIVER',
        targetEntityId: driverId,
        details: {'driver_name': '$surname $givenNames', 'id_number': idNumber},
      );

      // 3. Insert Licenses
      final List<Map<String, dynamic>> licenseInserts = codes
          .map(
            (code) => {
              'driver_id': driverId,
              'license_number': licenseNumber,
              'license_code': code,
              'issue_date': _parseDate(issueDate),
              'expiry_date': _parseDate(expiryDate),
            },
          )
          .toList();

      await client.from('driver_licenses').insert(licenseInserts);

      // 4. Insert Biometrics
      if (biometrics != null && biometrics.isNotEmpty) {
        final bioInserts = biometrics
            .map(
              (b) => {
                'driver_id': driverId,
                'finger_type': b['finger_type'],
                'template_data': b['template_data'],
              },
            )
            .toList();

        await client.from('driver_biometrics').insert(bioInserts);
      }

      return null; // Success
    } catch (e) {
      debugPrint('Supabase Save Error: $e');
      return 'Failed to save driver: ${e.toString()}';
    }
  }

  // Helper to convert DD/MM/YYYY to YYYY-MM-DD
  static String _parseDate(String date) {
    try {
      final parts = date.split('/');
      if (parts.length == 3) {
        return '${parts[2]}-${parts[1]}-${parts[0]}';
      }
    } catch (_) {}
    return date;
  }

  static Future<List<Driver>> getDrivers({
    int limit = 20,
    int offset = 0,
    String? query,
    String? licenseCode,
  }) async {
    try {
      // If filtering by license code, use inner join to filter drivers who have that license
      final licenseSelect =
          licenseCode != null && licenseCode.isNotEmpty && licenseCode != 'All'
          ? 'driver_licenses!inner(*)'
          : 'driver_licenses(*)';

      var builder = client
          .from('drivers')
          .select(
            '*, $licenseSelect, defensive_certificates(*), driver_biometrics(*)',
          );

      if (query != null && query.isNotEmpty) {
        builder = builder.or(
          'surname.ilike.%$query%,given_names.ilike.%$query%,id_number.ilike.%$query%',
        );
      }

      if (licenseCode != null &&
          licenseCode.isNotEmpty &&
          licenseCode != 'All') {
        builder = builder.eq('driver_licenses.license_code', licenseCode);
      }

      final List<dynamic> response = await builder
          .order('surname', ascending: true)
          .range(offset, offset + limit - 1);

      return response.map((json) => Driver.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Supabase Fetch Drivers Error: $e');
      return [];
    }
  }

  static Future<bool> deleteDriver(String driverId) async {
    try {
      // Delete images first if possible (requires bucket permissions, we'll skip explicit storage delete for now or handle errors silently)
      // Cascading deletes in DB should handle licenses/certs if configured,
      // otherwise we might need to delete them manually. Assuming cascade on FK.

      await client.from('drivers').delete().eq('id', driverId);
      return true;
    } catch (e) {
      debugPrint('Supabase Delete Error: $e');
      return false;
    }
  }

  // --- TSCZ / Defensive Driving Certificate Methods ---

  static Future<bool> addDefensiveCertificate({
    required String driverId,
    required String certificateNumber,
    required String issueDate,
    required String expiryDate,
    String issuedBy = 'TSCZ',
  }) async {
    try {
      await client.from('defensive_certificates').insert({
        'driver_id': driverId,
        'certificate_number': certificateNumber,
        'issue_date': _parseDate(issueDate),
        'expiry_date': _parseDate(expiryDate),
        'issued_by': issuedBy,
      });
      return true;
    } catch (e) {
      debugPrint('Add Certificate Error: $e');
      return false;
    }
  }

  static Future<bool> updateDefensiveCertificate({
    required String
    certificateNumber, // Assuming cert number is unique or we need ID. Using old cert number to find it? Or better, pass the ID locally if we had it.
    // Actually, distinct certs usually have IDs.
    // Let's assume we maintain uniqueness on cert number or use a compound key.
    // Ideally we should have the 'id' of the certificate row.
    // For now, let's delete and re-insert or update by certificate_number if unique.
    // Based on the model, we don't hold the row ID in the model.
    // We will update using certificate_number as key, or if we are editing, we usually pass the original Object.
    // Let's assume we delete the old one and add new one for "Update" if we don't have IDs.
    // OR, improving the Model to have ID is better.
    // Looking at the model `DefensiveCertificate`, it doesn't have an ID.
    // I will implement "Delete OLD" and "Insert NEW" for update to be safe, or just atomic update if PK is cert number.
    // Let's try simple update by certificate number for now.
    required String newCertificateNumber,
    required String issueDate,
    required String expiryDate,
    required String originalCertificateNumber,
  }) async {
    try {
      await client
          .from('defensive_certificates')
          .update({
            'certificate_number': newCertificateNumber,
            'issue_date': _parseDate(issueDate),
            'expiry_date': _parseDate(expiryDate),
          })
          .eq('certificate_number', originalCertificateNumber);
      return true;
    } catch (e) {
      debugPrint('Update Certificate Error: $e');
      return false;
    }
  }

  static Future<bool> deleteDefensiveCertificate(
    String certificateNumber,
  ) async {
    try {
      await client
          .from('defensive_certificates')
          .delete()
          .eq('certificate_number', certificateNumber);
      return true;
    } catch (e) {
      debugPrint('Delete Certificate Error: $e');
      return false;
    }
  }
}
