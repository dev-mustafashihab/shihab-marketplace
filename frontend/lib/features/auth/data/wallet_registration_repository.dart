import '../../../core/network/api_client.dart';
import '../data/wallet_registration_model.dart';

/// مستودع تسجيل المحفظة — طبقة Repository.
///
/// القاعدة: لا API calls داخل الـ Widgets — الشاشة تتكلم مع الـ Provider،
/// والـ Provider يتكلم مع هنا فقط.
class WalletRegistrationRepository {
  WalletRegistrationRepository(this._api);

  final ApiClient _api;

  /// إنشاء حساب محفظة جديد — يرمي [ApiException] عند الفشل.
  /// يرجع التوكنات + رقم الحساب النهائي (قد يولّده السيرفر).
  Future<Map<String, dynamic>> submit(WalletRegistrationModel model) async {
    final data = await _api.post('/auth/register', body: model.toRegisterBody());
    if (data is Map<String, dynamic>) return data;
    return {'data': data};
  }
}
