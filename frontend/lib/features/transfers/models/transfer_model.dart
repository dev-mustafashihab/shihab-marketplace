/// نموذج عملية التحويل — جاهز للربط مع API حقيقي.
/// يُبنى من سجل محفظة الباكند (GET /wallet) أو من أي مصدر لاحقاً.
enum TransferType { send, receive }

enum TransferStatus { success, pending, failed }

class TransferModel {
  const TransferModel({
    required this.id,
    required this.recipientName,
    required this.amount,
    required this.currency,
    required this.type,
    required this.status,
    required this.dateTime,
    this.note,
    required this.receiptId,
  });

  final String id;
  final String recipientName;
  final double amount;
  final String currency;
  final TransferType type;
  final TransferStatus status;
  final DateTime dateTime;
  final String? note;
  final String receiptId;

  bool get isSend => type == TransferType.send;
  String get sign => isSend ? '-' : '+';

  /// مبلغ منسق: صحيح بدون فواصل، كسري برقمين كحد أقصى.
  String get formattedAmount {
    if (amount == amount.truncateToDouble()) return amount.toInt().toString();
    return amount.toStringAsFixed(2);
  }

  /// سطر المبلغ الكامل باتجاه LTR صريح لمنع تداخل Bidi: "- $ 50"
  String get amountLine => '$sign $currency $formattedAmount';

  /// "2026/09/02 - 17:25:44"
  String get dateTimeLine {
    String two(int n) => n.toString().padLeft(2, '0');
    final d = dateTime.toLocal();
    return '${d.year}/${two(d.month)}/${two(d.day)} - ${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
  }

  String get typeAr => isSend ? 'إرسال' : 'استقبال';

  String get statusAr => switch (status) {
        TransferStatus.success => 'ناجحة',
        TransferStatus.pending => 'قيد المعالجة',
        TransferStatus.failed => 'فاشلة',
      };

  /// من حركة محفظة الباكند (WalletTransaction): sale/commission/refund/payout/adjustment.
  /// سجل المحفظة عمليات مرحّلة → الحالة ناجحة. الطرف المقابل من الملاحظة أو نوع الحركة.
  factory TransferModel.fromWalletTx(Map<String, dynamic> json) {
    final rawType = ((json['type'] ?? '') as String).toUpperCase();
    final rawAmount = json['amount'];
    final amount = rawAmount is num
        ? rawAmount.toDouble().abs()
        : (double.tryParse('$rawAmount') ?? 0).abs();
    final type = switch (rawType) {
      'PAYOUT' || 'COMMISSION' || 'REFUND' => TransferType.send,
      'ADJUSTMENT' => (rawAmount is num && rawAmount < 0) ? TransferType.send : TransferType.receive,
      _ => TransferType.receive,
    };
    final note = (json['note'] as String?)?.trim();
    final refType = (json['refType'] as String?)?.trim();
    final id = '${json['id'] ?? ''}';
    return TransferModel(
      id: id,
      recipientName: (note != null && note.isNotEmpty)
          ? note
          : (refType != null && refType.isNotEmpty)
              ? refType
              : _typeAr(rawType),
      amount: amount,
      currency: '${json['currency'] ?? 'USD'}',
      type: type,
      status: TransferStatus.success,
      dateTime: DateTime.tryParse('${json['createdAt'] ?? ''}') ?? DateTime.now(),
      note: (note != null && note.isNotEmpty) ? note : null,
      receiptId: '#${_shortId(id)}',
    );
  }

  static String _typeAr(String t) => switch (t) {
        'SALE' => 'عملية بيع',
        'COMMISSION' => 'عمولة',
        'REFUND' => 'استرداد',
        'PAYOUT' => 'سحب رصيد',
        'ADJUSTMENT' => 'تسوية',
        _ => 'تحويل',
      };

  static String _shortId(String id) {
    final clean = id.replaceAll('-', '').toUpperCase();
    return clean.length <= 9 ? clean : clean.substring(0, 9);
  }
}
