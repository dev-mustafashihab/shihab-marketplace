import '../../../core/network/api_client.dart';
import '../models/transfer_model.dart';

/// مصدر بيانات التحويلات — لا توجد API calls داخل الـ Widgets.
/// الحالي: GET /wallet (محفظة + سجل الحركات). جاهز للتبديل لأي Endpoint لاحقاً.
class TransfersRepository {
  TransfersRepository(this._api);
  final ApiClient _api;

  Future<List<TransferModel>> fetchTransfers({int limit = 50}) async {
    final data = await _api.get('/wallet', query: {'limit': '$limit'});
    final raw = (data is Map<String, dynamic> && data['transactions'] is List)
        ? data['transactions'] as List
        : const [];
    return raw
        .whereType<Map>()
        .map((e) => TransferModel.fromWalletTx(e.cast<String, dynamic>()))
        .toList();
  }
}
