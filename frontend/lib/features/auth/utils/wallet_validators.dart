/// مفاتيح الدول — بيانات فقط (لا Hardcode داخل الـ Widgets).
const walletCountryCodes = <Map<String, String>>[
  {'code': '+963', 'label': 'سوريا +963'},
  {'code': '+90', 'label': 'تركيا +90'},
  {'code': '+971', 'label': 'الإمارات +971'},
  {'code': '+966', 'label': 'السعودية +966'},
  {'code': '+962', 'label': 'الأردن +962'},
  {'code': '+961', 'label': 'لبنان +961'},
  {'code': '+20', 'label': 'مصر +20'},
];

/// تحققات شاشة تسجيل المحفظة — كل دالة ترجع رسالة عربية أو null عند الصحة.
/// تُستخدم من الـ Provider والـ UI معاً (مصدر واحد للحقيقة).
class WalletValidators {
  WalletValidators._();

  static final RegExp arabicName = RegExp(r'^[\u0600-\u06FF\u0750-\u077F A-Za-z]{2,100}$');
  static final RegExp nationalId = RegExp(r'^\d{11}$');
  static final RegExp digitsOnly = RegExp(r'^\d+$');
  static final RegExp email =
      RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');
  static final RegExp accountId = RegExp(r'^\d{16}$');
  static final RegExp walletPin = RegExp(r'^\d{4}$|^\d{6}$');
  // سوري: 09XXXXXXXX أو +9639XXXXXXXX أو 009639XXXXXXXX
  static final RegExp syrianMobile = RegExp(r'^(?:\+963|00963|0)?9\d{8}$');

  static String? name(String v, String label) {
    final t = v.trim();
    if (t.length < 2) return '$label مطلوب (حرفان على الأقل)';
    if (!arabicName.hasMatch(t)) return '$label يحتوي رموزاً غير صالحة';
    return null;
  }

  static String? nationalIdValidator(String v) {
    final t = v.trim();
    if (!digitsOnly.hasMatch(t)) return 'الرقم الوطني أرقام فقط';
    if (!nationalId.hasMatch(t)) return 'الرقم الوطني يجب أن يكون 11 رقماً';
    return null;
  }

  static String? phoneValidator(String v) {
    final t = v.replaceAll(RegExp(r'[\s-]'), '');
    if (t.isEmpty) return 'رقم الهاتف مطلوب';
    if (!RegExp(r'^\+?[0-9]{7,15}$').hasMatch(t)) {
      return 'صيغة رقم الهاتف غير صحيحة';
    }
    return null;
  }

  static String? emailValidator(String v) {
    if (!email.hasMatch(v.trim())) return 'صيغة البريد الإلكتروني غير صحيحة';
    return null;
  }

  static String? passwordValidator(String v) {
    if (v.length < 8) return 'كلمة المرور 8 أحرف على الأقل';
    return null;
  }

  static String? accountIdValidator(String v) {
    final t = v.replaceAll(RegExp(r'[\s-]'), '');
    if (!digitsOnly.hasMatch(t)) return 'رقم الحساب أرقام فقط';
    if (!accountId.hasMatch(t)) return 'رقم الحساب يجب أن يكون 16 رقماً';
    return null;
  }

  static String? pinValidator(String v) {
    if (!walletPin.hasMatch(v.trim())) {
      return 'رمز الحماية يجب أن يكون 4 أو 6 أرقام';
    }
    return null;
  }

  static String? birthDateValidator(DateTime? d) {
    if (d == null) return 'تاريخ الميلاد مطلوب';
    final age = DateTime.now().difference(d).inDays / 365.25;
    if (age < 18) return 'التسجيل متاح لمن بلغ 18 سنة فأكثر';
    return null;
  }
}
