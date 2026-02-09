enum Gender { Male, Female }

class Driver {
  final String id;
  final String surname;
  final String givenNames;
  final String dob;
  final String idNumber;
  final String? driverImagePath;
  final String? restrictions;
  final Gender? gender;
  final List<DriverLicense> licenses;
  final List<DefensiveCertificate> certificates;

  Driver({
    required this.id,
    required this.surname,
    required this.givenNames,
    required this.dob,
    required this.idNumber,
    this.driverImagePath,
    this.restrictions,
    this.gender,
    this.licenses = const [],
    this.certificates = const [],
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

    Gender? gender;
    if (json['gender'] != null) {
      try {
        gender = Gender.values.firstWhere(
          (e) => e.toString().split('.').last == json['gender'],
        );
      } catch (_) {}
    }

    return Driver(
      id: json['id'] ?? '',
      surname: json['surname'] ?? '',
      givenNames: json['given_names'] ?? '',
      dob: json['dob'] ?? '',
      idNumber: json['id_number'] ?? '',
      driverImagePath: json['driver_image_path'],
      restrictions: json['restrictions'],
      gender: gender,
      licenses: licenseList,
      certificates: certList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'surname': surname,
      'given_names': givenNames,
      'dob': dob,
      'id_number': idNumber,
      'driver_image_path': driverImagePath,
      'restrictions': restrictions,
      'gender': gender?.toString().split('.').last,
    };
  }
}

class DefensiveCertificate {
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
