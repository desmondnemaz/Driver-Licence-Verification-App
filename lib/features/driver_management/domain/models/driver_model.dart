import 'package:driver_license_verifier_app/core/services/encryption_service.dart';

class Driver {
  final String id;
  final String surname;
  final String givenNames;
  final String dob;
  final String idNumber;
  final String? driverImagePath;
  final String? gender;
  final List<DriverLicense> licenses;
  final List<DefensiveCertificate> certificates;
  final List<DriverBiometric> biometrics;
  final bool wasPlaintextInDb;

  Driver({
    required this.id,
    required this.surname,
    required this.givenNames,
    required this.dob,
    required this.idNumber,
    this.driverImagePath,
    this.gender,
    this.licenses = const [],
    this.certificates = const [],
    this.biometrics = const [],
    this.wasPlaintextInDb = false,
  });

  factory Driver.fromJson(Map<String, dynamic> json) {
    var licenseData = json['driver_licenses'] as List? ?? [];
    List<DriverLicense> licenseList = licenseData
        .map((l) => DriverLicense.fromJson(l as Map<String, dynamic>))
        .toList();

    var certData = json['defensive_certificates'] as List? ?? [];
    List<DefensiveCertificate> certList = certData
        .map((c) => DefensiveCertificate.fromJson(c as Map<String, dynamic>))
        .toList();

    var biometricData = json['driver_biometrics'] as List? ?? [];
    List<DriverBiometric> biometricList = biometricData
        .map((b) => DriverBiometric.fromJson(b as Map<String, dynamic>))
        .toList();

    final rawSurname = json['surname'] ?? '';
    final rawGivenNames = json['given_names'] ?? '';

    final bool surnameIsEncrypted = EncryptionService.isEncrypted(rawSurname);
    final bool givenNamesIsEncrypted = EncryptionService.isEncrypted(rawGivenNames);

    final bool wasPlaintext = (rawSurname.isNotEmpty && !surnameIsEncrypted) ||
                              (rawGivenNames.isNotEmpty && !givenNamesIsEncrypted);

    final decryptedSurname = EncryptionService.decrypt(rawSurname);
    final decryptedGivenNames = EncryptionService.decrypt(rawGivenNames);

    return Driver(
      id: json['id'] ?? '',
      surname: decryptedSurname,
      givenNames: decryptedGivenNames,
      dob: json['dob'] ?? '',
      idNumber: json['id_number'] ?? '',
      driverImagePath: json['driver_image_path'],
      gender: json['gender'],
      licenses: licenseList,
      certificates: certList,
      biometrics: biometricList,
      wasPlaintextInDb: wasPlaintext,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'surname': surname,
      'given_names': givenNames,
      'dob': dob,
      'id_number': idNumber,
      'driver_image_path': driverImagePath,
      'gender': gender,
    };
  }
}

class DriverBiometric {
  final int? id;
  final String driverId;
  final String fingerType; // 'right_thumb' or 'left_thumb'
  final String templateData;

  DriverBiometric({
    this.id,
    required this.driverId,
    required this.fingerType,
    required this.templateData,
  });

  factory DriverBiometric.fromJson(Map<String, dynamic> json) {
    return DriverBiometric(
      id: json['id'],
      driverId: json['driver_id'] ?? '',
      fingerType: json['finger_type'] ?? '',
      templateData: json['template_data'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'driver_id': driverId,
      'finger_type': fingerType,
      'template_data': templateData,
    };
  }
}

class DefensiveCertificate {
  // ... existing code ...
  final String certificateNumber;
  final String issueDate;
  final String expiryDate;
  final String issuedBy;

  DefensiveCertificate({
    required this.certificateNumber,
    required this.issueDate,
    required this.expiryDate,
    this.issuedBy = 'TSCZ',
  });

  factory DefensiveCertificate.fromJson(Map<String, dynamic> json) {
    return DefensiveCertificate(
      certificateNumber: json['certificate_number'] ?? '',
      issueDate: json['issue_date'] ?? '',
      expiryDate: json['expiry_date'] ?? '',
      issuedBy: json['issued_by'] ?? 'TSCZ',
    );
  }
}

class DriverLicense {
  final String licenseNumber;
  final String licenseCode;
  final String issueDate;
  final String expiryDate;
  final String issuedBy;

  DriverLicense({
    required this.licenseNumber,
    required this.licenseCode,
    required this.issueDate,
    required this.expiryDate,
    this.issuedBy = 'CVR',
  });

  factory DriverLicense.fromJson(Map<String, dynamic> json) {
    return DriverLicense(
      licenseNumber: json['license_number'] ?? '',
      licenseCode: json['license_code'] ?? '',
      issueDate: json['issue_date'] ?? '',
      expiryDate: json['expiry_date'] ?? '',
      issuedBy: json['issued_by'] ?? 'CVR',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'license_number': licenseNumber,
      'license_code': licenseCode,
      'issue_date': issueDate,
      'expiry_date': expiryDate,
      'issued_by': issuedBy,
    };
  }
}
