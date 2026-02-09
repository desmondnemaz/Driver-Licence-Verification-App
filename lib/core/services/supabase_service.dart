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

  static Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    required String ecNumber,
    required String role,
    required String gender,
    String? station,
    String? phoneNumber,
  }) async {
    try {
      final AuthResponse res = await client.auth.signUp(
        email: email,
        password: password,
      );

      final String? userId = res.user?.id;
      if (userId == null) return false;

      await client.from('profiles').insert({
        'id': userId,
        'ec_number': ecNumber,
        'full_name': fullName,
        'role': role,
        'gender': gender,
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

      return true;
    } catch (e) {
      debugPrint('Sign Up Error: $e');
      return false;
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
      return await client.storage
          .from('driver-images')
          .createSignedUrl(path, 3600); // 1 hour link
    } catch (e) {
      debugPrint('Error getting image URL: $e');
      return null;
    }
  }

  static Future<Driver?> getDriver(
    String idNumber,
    String? licenseNumber,
  ) async {
    try {
      // 1. Try by ID Number join with licenses and certificates
      final dataById = await client
          .from('drivers')
          .select('*, driver_licenses(*), defensive_certificates(*)')
          .eq('id_number', idNumber)
          .maybeSingle();

      if (dataById != null) {
        return Driver.fromJson(dataById);
      }

      // 2. If provided, try by License Number
      if (licenseNumber != null && licenseNumber.isNotEmpty) {
        final licenseData = await client
            .from('driver_licenses')
            .select(
              '*, drivers(*, driver_licenses(*), defensive_certificates(*))',
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
      final driversCount =
          driversRes; // In some versions count() returns int directly

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

      return {
        'total_drivers': driversCount,
        'active_users': usersCount,
        'verifications': verificationsCount,
      };
    } catch (e) {
      debugPrint('Stats Error: $e');
      return {'total_drivers': 0, 'active_users': 0, 'verifications': 0};
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

  static Future<Map<String, int>> getDriverAgeStats() async {
    try {
      final response = await client.from('drivers').select('dob');
      final List<dynamic> data = response as List<dynamic>;

      int group18to25 = 0;
      int group26to35 = 0;
      int group36to50 = 0;
      int group51plus = 0;

      final now = DateTime.now();

      for (var item in data) {
        final dobString = item['dob'] as String?;
        if (dobString == null) continue;

        final dob = DateTime.tryParse(dobString);
        if (dob == null) continue;

        final age = now.year - dob.year;
        if (age >= 18 && age <= 25)
          group18to25++;
        else if (age >= 26 && age <= 35)
          group26to35++;
        else if (age >= 36 && age <= 50)
          group36to50++;
        else if (age >= 51)
          group51plus++;
      }

      return {
        '18-25': group18to25,
        '26-35': group26to35,
        '36-50': group36to50,
        '51+': group51plus,
      };
    } catch (e) {
      debugPrint('Age Stats Error: $e');
      return {};
    }
  }

  static Future<Map<String, int>> getLicenseClassStats() async {
    try {
      final response = await client
          .from('driver_licenses')
          .select('license_code');
      // response is List of Maps: [{'license_code': '2'}, {'license_code': '4'}]
      final List<dynamic> data = response as List<dynamic>;

      final Map<String, int> stats = {};

      for (var item in data) {
        final code = item['license_code'] as String?;
        if (code != null) {
          stats[code] = (stats[code] ?? 0) + 1;
        }
      }

      return stats;
    } catch (e) {
      debugPrint('License Stats Error: $e');
      return {};
    }
  }

  static Future<List<Map<String, dynamic>>> getRegistrationTrends() async {
    try {
      // Get last 7 days of registrations
      final sevenDaysAgo = DateTime.now()
          .subtract(const Duration(days: 7))
          .toIso8601String();

      final response = await client
          .from('drivers')
          .select('created_at')
          .gte('created_at', sevenDaysAgo)
          .order('created_at', ascending: true);

      final List<dynamic> data = response as List<dynamic>;

      // Group by day
      final Map<String, int> dailyCounts = {};

      // Initialize last 7 days with 0
      for (int i = 6; i >= 0; i--) {
        final date = DateTime.now().subtract(Duration(days: i));
        final key = "${date.day}/${date.month}";
        dailyCounts[key] = 0;
      }

      for (var item in data) {
        final createdString = item['created_at'] as String?;
        if (createdString != null) {
          final date = DateTime.tryParse(createdString)?.toLocal();
          if (date != null) {
            final key = "${date.day}/${date.month}";
            if (dailyCounts.containsKey(key)) {
              dailyCounts[key] = (dailyCounts[key] ?? 0) + 1;
            }
          }
        }
      }

      return dailyCounts.entries
          .map((e) => {'date': e.key, 'count': e.value})
          .toList();
    } catch (e) {
      debugPrint('Registration Trends Error: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getLatestAuditLogs({
    int limit = 5,
  }) async {
    try {
      // Check if audit_logs exists by trying a simple select
      return await client
          .from('audit_logs')
          .select('*, profiles(full_name)')
          .order('created_at', ascending: false)
          .limit(limit);
    } catch (e) {
      // If table doesn't exist or other error, return empty
      return [];
    }
  }

  static Future<bool> updateDriverWithLicenses({
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
    String? restrictions,
  }) async {
    try {
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
            'restrictions': restrictions,
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

      return true;
    } catch (e) {
      debugPrint('Supabase Update Error: $e');
      return false;
    }
  }

  static Future<bool> saveDriverWithLicenses({
    required String surname,
    required String givenNames,
    required String dob,
    required String idNumber,
    required String licenseNumber,
    required String issueDate,
    required String expiryDate,
    required List<String> codes,
    XFile? imageFile,
    String? restrictions,
  }) async {
    try {
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
            'restrictions': restrictions,
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

      return true;
    } catch (e) {
      debugPrint('Supabase Save Error: $e');
      return false;
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
          .select('*, $licenseSelect, defensive_certificates(*)');

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
