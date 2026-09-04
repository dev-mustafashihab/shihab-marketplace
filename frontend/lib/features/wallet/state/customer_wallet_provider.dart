import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

/// محفظة الزبون الأساسية: GET /customer-wallet → {wallet:{balance,currency}, transactions}
/// تُنشأ تلقائياً برصيد 0 عند أول استدعاء. الشحن من الأدمن (وكيل شحن لاحقاً).
final customerWalletProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  if (ref.watch(sessionTokenProvider) == null) return null;
  try {
    final data = await ref.watch(apiClientProvider).get('/customer-wallet');
    return (data as Map).cast<String, dynamic>();
  } catch (_) {
    return null;
  }
});
