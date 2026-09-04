import 'dart:convert';
import 'dart:math';

/// نموذج بيانات تسجيل محفظة جديدة — جاهز للإرسال إلى الـ API.
///
/// يُستخدم مع [WalletRegistrationRepository.submit] الذي يحوّله إلى body
/// متوافق مع `POST /auth/register` (الحقول المسموح بها فقط).
class WalletRegistrationModel {
  const WalletRegistrationModel({
    this.firstName = '',
    this.fatherName = '',
    this.lastName = '',
    this.motherName = '',
    this.motherFatherName = '',
    this.motherMaidenName = '',
    this.nationalId = '',
    this.countryCode = '+963',
    this.phone = '',
    this.email = '',
    this.password = '',
    this.birthDate,
    this.accountId = '',
    this.walletPin = '',
    this.consentAccepted = false,
  });

  final String firstName;
  final String fatherName;
  final String lastName;
  final String motherName;
  final String motherFatherName;
  final String motherMaidenName;
  final String nationalId;
  final String countryCode;
  final String phone;
  final String email;
  final String password;
  final DateTime? birthDate;
  final String accountId;
  final String walletPin;
  final bool consentAccepted;

  /// الاسم الثلاثي مركباً — للتوافق مع حقل الباكند `fullName`.
  String get fullName =>
      '$firstName $fatherName $lastName'.replaceAll(RegExp(r'\s+'), ' ').trim();

  /// رقم الهاتف كاملاً بالمفتاح الدولي — مثال: +963931234567
  String get fullPhone {
    final digits = phone.replaceAll(RegExp(r'[\s-]'), '');
    if (digits.startsWith('0')) return '$countryCode${digits.substring(1)}';
    if (digits.startsWith('+')) return digits;
    return '$countryCode$digits';
  }

  /// رقم الحساب بصيغة مقروءة 0000-0000-0000-0000
  String get formattedAccountId {
    final d = accountId.replaceAll(RegExp(r'[\s-]'), '');
    if (d.length != 16) return accountId;
    return '${d.substring(0, 4)}-${d.substring(4, 8)}-${d.substring(8, 12)}-${d.substring(12)}';
  }

  /// توليد رقم حساب عشوائي من 16 رقماً (لا يبدأ بصفر).
  static String generateAccountId([Random? random]) {
    final r = random ?? Random.secure();
    final buf = StringBuffer('${1 + r.nextInt(9)}');
    for (var i = 0; i < 15; i++) {
      buf.write(r.nextInt(10));
    }
    return buf.toString();
  }

  WalletRegistrationModel copyWith({
    String? firstName,
    String? fatherName,
    String? lastName,
    String? motherName,
    String? motherFatherName,
    String? motherMaidenName,
    String? nationalId,
    String? countryCode,
    String? phone,
    String? email,
    String? password,
    DateTime? Function()? birthDate,
    String? accountId,
    String? walletPin,
    bool? consentAccepted,
  }) {
    return WalletRegistrationModel(
      firstName: firstName ?? this.firstName,
      fatherName: fatherName ?? this.fatherName,
      lastName: lastName ?? this.lastName,
      motherName: motherName ?? this.motherName,
      motherFatherName: motherFatherName ?? this.motherFatherName,
      motherMaidenName: motherMaidenName ?? this.motherMaidenName,
      nationalId: nationalId ?? this.nationalId,
      countryCode: countryCode ?? this.countryCode,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      password: password ?? this.password,
      birthDate: birthDate != null ? birthDate() : this.birthDate,
      accountId: accountId ?? this.accountId,
      walletPin: walletPin ?? this.walletPin,
      consentAccepted: consentAccepted ?? this.consentAccepted,
    );
  }

  /// كامل الحقول — للعرض/التخزين المحلي (لا يُرسل كله للسيرفر).
  Map<String, dynamic> toMap() => {
        'firstName': firstName.trim(),
        'fatherName': fatherName.trim(),
        'lastName': lastName.trim(),
        'motherName': motherName.trim(),
        'motherFatherName': motherFatherName.trim(),
        'motherMaidenName': motherMaidenName.trim(),
        'nationalId': nationalId.trim(),
        'phone': fullPhone,
        'email': email.trim(),
        'birthDate': birthDate?.toIso8601String().split('T').first,
        'walletAccountId': accountId.replaceAll(RegExp(r'[\s-]'), ''),
        'consentAccepted': consentAccepted,
      };

  /// body متوافق مع `POST /auth/register` (whitelist فقط — PIN يُرسل، كلمة المرور مطلوبة).
  Map<String, dynamic> toRegisterBody() => {
        'email': email.trim(),
        'password': password,
        'role': 'CUSTOMER',
        'firstName': firstName.trim(),
        'fatherName': fatherName.trim(),
        'lastName': lastName.trim(),
        'fullName': fullName,
        'motherName': motherName.trim(),
        'motherFatherName': motherFatherName.trim(),
        'motherMaidenName': motherMaidenName.trim(),
        'nationalId': nationalId.trim(),
        'phone': fullPhone,
        'birthDate': birthDate?.toIso8601String().split('T').first,
        'governorate': 'دمشق',
        'city': 'دمشق',
        'walletAccountId': accountId.replaceAll(RegExp(r'[\s-]'), ''),
        'walletPin': walletPin,
        'consentAccepted': consentAccepted,
      };

  String toJson() => jsonEncode(toMap());

  factory WalletRegistrationModel.fromJson(Map<String, dynamic> map) {
    return WalletRegistrationModel(
      firstName: '${map['firstName'] ?? ''}',
      fatherName: '${map['fatherName'] ?? ''}',
      lastName: '${map['lastName'] ?? ''}',
      motherName: '${map['motherName'] ?? ''}',
      motherFatherName: '${map['motherFatherName'] ?? ''}',
      motherMaidenName: '${map['motherMaidenName'] ?? ''}',
      nationalId: '${map['nationalId'] ?? ''}',
      phone: '${map['phone'] ?? ''}',
      email: '${map['email'] ?? ''}',
      accountId: '${map['walletAccountId'] ?? map['accountId'] ?? ''}',
      consentAccepted: map['consentAccepted'] == true,
    );
  }
}
