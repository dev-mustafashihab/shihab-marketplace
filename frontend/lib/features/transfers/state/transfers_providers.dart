import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/transfers_repository.dart';
import '../models/transfer_model.dart';

/// فلاتر الصفحة: الكل / إرسال / استقبال / ناجحة / قيد المعالجة / فاشلة.
enum TransferFilter { all, send, receive, success, pending, failed }

extension TransferFilterAr on TransferFilter {
  String get label => switch (this) {
        TransferFilter.all => 'الكل',
        TransferFilter.send => 'إرسال',
        TransferFilter.receive => 'استقبال',
        TransferFilter.success => 'ناجحة',
        TransferFilter.pending => 'قيد المعالجة',
        TransferFilter.failed => 'فاشلة',
      };
}

final transfersRepositoryProvider = Provider<TransfersRepository>((ref) {
  return TransfersRepository(ref.watch(apiClientProvider));
});

/// القائمة الخام من الـ API — بدون توكن تُرجع فارغة (الضيف يرى دعوة الدخول).
final transfersListProvider = FutureProvider.autoDispose<List<TransferModel>>((ref) {
  if (ref.watch(sessionTokenProvider) == null) return [];
  return ref.watch(transfersRepositoryProvider).fetchTransfers();
});

final transferSearchProvider = StateProvider.autoDispose<String>((ref) => '');

final transferFilterProvider = StateProvider.autoDispose<TransferFilter>((ref) => TransferFilter.all);

/// الفلترة المتقدمة — مستقلة وتُجمع (AND) مع الفلتر الرئيسي.
enum AdvTransferType { all, send, receive }

extension AdvTransferTypeAr on AdvTransferType {
  String get label => switch (this) {
        AdvTransferType.all => 'الكل',
        AdvTransferType.send => 'إرسال',
        AdvTransferType.receive => 'استقبال',
      };
}

enum AdvTransferStatus { all, success, pending, failed }

extension AdvTransferStatusAr on AdvTransferStatus {
  String get label => switch (this) {
        AdvTransferStatus.all => 'الكل',
        AdvTransferStatus.success => 'ناجحة',
        AdvTransferStatus.pending => 'قيد المعالجة',
        AdvTransferStatus.failed => 'فاشلة',
      };
}

final transferDateFromProvider =
    StateProvider.autoDispose<DateTime?>((ref) => null);
final transferDateToProvider =
    StateProvider.autoDispose<DateTime?>((ref) => null);
final transferMinAmountProvider =
    StateProvider.autoDispose<String>((ref) => '');
final transferMaxAmountProvider =
    StateProvider.autoDispose<String>((ref) => '');
final transferAdvTypeProvider =
    StateProvider.autoDispose<AdvTransferType>((ref) => AdvTransferType.all);
final transferAdvStatusProvider = StateProvider.autoDispose<AdvTransferStatus>(
    (ref) => AdvTransferStatus.all);

/// تصفير كل الفلاتر (الرئيسي + المتقدم) — البحث يُصفّر من الشاشة.
void clearTransferFilters(WidgetRef ref) {
  ref.read(transferFilterProvider.notifier).state = TransferFilter.all;
  ref.read(transferDateFromProvider.notifier).state = null;
  ref.read(transferDateToProvider.notifier).state = null;
  ref.read(transferMinAmountProvider.notifier).state = '';
  ref.read(transferMaxAmountProvider.notifier).state = '';
  ref.read(transferAdvTypeProvider.notifier).state = AdvTransferType.all;
  ref.read(transferAdvStatusProvider.notifier).state =
      AdvTransferStatus.all;
}

/// القائمة بعد البحث (اسم / رقم عملية / مبلغ) والفلتر.
final filteredTransfersProvider = Provider.autoDispose<List<TransferModel>>((ref) {
  final list = ref.watch(transfersListProvider).valueOrNull ?? const [];
  final q = ref.watch(transferSearchProvider).trim();
  final f = ref.watch(transferFilterProvider);
  final from = ref.watch(transferDateFromProvider);
  final to = ref.watch(transferDateToProvider);
  final minAmt = double.tryParse(ref.watch(transferMinAmountProvider));
  final maxAmt = double.tryParse(ref.watch(transferMaxAmountProvider));
  final advType = ref.watch(transferAdvTypeProvider);
  final advStatus = ref.watch(transferAdvStatusProvider);
  return list.where((t) {
    final okFilter = switch (f) {
      TransferFilter.all => true,
      TransferFilter.send => t.isSend,
      TransferFilter.receive => !t.isSend,
      TransferFilter.success => t.status == TransferStatus.success,
      TransferFilter.pending => t.status == TransferStatus.pending,
      TransferFilter.failed => t.status == TransferStatus.failed,
    };
    if (!okFilter) return false;
    if (advType == AdvTransferType.send && !t.isSend) return false;
    if (advType == AdvTransferType.receive && t.isSend) return false;
    if (advStatus != AdvTransferStatus.all) {
      final ok = switch (advStatus) {
        AdvTransferStatus.success => t.status == TransferStatus.success,
        AdvTransferStatus.pending => t.status == TransferStatus.pending,
        AdvTransferStatus.failed => t.status == TransferStatus.failed,
        AdvTransferStatus.all => true,
      };
      if (!ok) return false;
    }
    if (from != null && t.dateTime.isBefore(DateTime(from.year, from.month, from.day))) {
      return false;
    }
    if (to != null &&
        t.dateTime.isAfter(DateTime(to.year, to.month, to.day, 23, 59, 59))) {
      return false;
    }
    if (minAmt != null && t.amount < minAmt) return false;
    if (maxAmt != null && t.amount > maxAmt) return false;
    if (q.isEmpty) return true;
    return t.recipientName.contains(q) ||
        t.receiptId.contains(q.toUpperCase()) ||
        t.id.contains(q) ||
        t.formattedAmount.contains(q);
  }).toList();
});
