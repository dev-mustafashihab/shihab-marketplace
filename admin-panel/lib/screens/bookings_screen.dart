import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/admin_api.dart';

class BookingsScreen extends ConsumerStatefulWidget {
  const BookingsScreen({super.key});

  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends ConsumerState<BookingsScreen> {
  List<dynamic> _bookings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await ref.read(adminApiProvider).get('/bookings?limit=50');
      if (mounted) setState(() {
        _bookings = d is Map ? (d['data'] ?? d['bookings'] ?? []) : (d is List ? d : []);
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
        color: Colors.white,
        child: Row(children: [
          const Text('الحجوزات', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const Spacer(),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ]),
      ),
      Divider(height: 1, color: Colors.grey[200]),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _bookings.isEmpty
                ? Center(child: Text('لا توجد حجوزات', style: TextStyle(color: Colors.grey[500])))
                : ListView.separated(
                    padding: const EdgeInsets.all(24),
                    itemCount: _bookings.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final b = _bookings[i] as Map<String, dynamic>;
                      final status = '${b['status'] ?? ''}';
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
                        ),
                        child: Row(children: [
                          Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(color: _statusColor(status).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                            child: Icon(Icons.calendar_month_rounded, color: _statusColor(status)),
                          ),
                          const SizedBox(width: 16),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${b['serviceName'] ?? b['vendorName'] ?? 'حجز'}', style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text('${b['customerName'] ?? ''}', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                            if (b['date'] != null) Text('${b['date']}', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                          ])),
                          _StatusChip(status: status),
                          if (status == 'PENDING') ...[
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () => _updateStatus(b['id'], 'CONFIRMED'),
                              icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50)),
                              tooltip: 'تأكيد',
                            ),
                            IconButton(
                              onPressed: () => _updateStatus(b['id'], 'REJECTED'),
                              icon: const Icon(Icons.cancel_rounded, color: Color(0xFFE5392B)),
                              tooltip: 'رفض',
                            ),
                          ],
                        ]),
                      );
                    },
                  ),
      ),
    ]);
  }

  Future<void> _updateStatus(String id, String status) async {
    try {
      await ref.read(adminApiProvider).patch('/bookings/$id/${status.toLowerCase()}', body: {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم تحديث الحالة')));
        _load();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  Color _statusColor(String s) => switch (s) {
    'CONFIRMED' => const Color(0xFF4CAF50),
    'REJECTED' || 'CANCELLED' => const Color(0xFFE5392B),
    'COMPLETED' => const Color(0xFF2196F3),
    _ => const Color(0xFFFFA726),
  };
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'CONFIRMED' => ('مؤكد', const Color(0xFF4CAF50)),
      'REJECTED' => ('مرفوض', const Color(0xFFE5392B)),
      'CANCELLED' => ('ملغي', const Color(0xFFE5392B)),
      'COMPLETED' => ('مكتمل', const Color(0xFF2196F3)),
      _ => ('بانتظار', const Color(0xFFFFA726)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
