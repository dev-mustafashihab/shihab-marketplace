import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/admin_api.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Map<String, dynamic>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = ref.read(adminApiProvider);
      final users = await api.get('/users?limit=1');
      final vendors = await api.get('/vendors/admin/queue/PENDING?limit=1');
      final bookings = await api.get('/bookings?limit=1');
      if (mounted) setState(() {
        _stats = {
          'users': users is Map ? (users['total'] ?? users['data']?.length ?? 0) : 0,
          'pendingVendors': vendors is Map ? (vendors['total'] ?? 0) : 0,
          'bookings': bookings is Map ? (bookings['total'] ?? 0) : 0,
        };
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('مرحباً، المدير', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
        const SizedBox(height: 4),
        Text('نظرة عامة على المنصة', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
        const SizedBox(height: 24),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else
          Row(children: [
            _StatCard(
              icon: Icons.people_rounded,
              label: 'المستخدمين',
              value: '${_stats?['users'] ?? 0}',
              color: const Color(0xFF0AAEBF),
            ),
            const SizedBox(width: 16),
            _StatCard(
              icon: Icons.store_rounded,
              label: 'بائعين بانتظار الموافقة',
              value: '${_stats?['pendingVendors'] ?? 0}',
              color: const Color(0xFFFFA726),
            ),
            const SizedBox(width: 16),
            _StatCard(
              icon: Icons.calendar_month_rounded,
              label: 'الحجوزات',
              value: '${_stats?['bookings'] ?? 0}',
              color: const Color(0xFF4CAF50),
            ),
          ]),
        const SizedBox(height: 24),
        // إجراءات سريعة
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('إجراءات سريعة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Wrap(spacing: 12, runSpacing: 12, children: [
              _QuickAction(icon: Icons.verified_outlined, label: 'مراجعة التوثيقات', onTap: () {}),
              _QuickAction(icon: Icons.person_add_outlined, label: 'إضافة مستخدم', onTap: () {}),
              _QuickAction(icon: Icons.category_outlined, label: 'إدارة التصنيفات', onTap: () {}),
              _QuickAction(icon: Icons.receipt_long_outlined, label: 'تقارير المبيعات', onTap: () {}),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.label, required this.value, required this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: color)),
              Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            ],
          )),
        ]),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[200]!),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: const Color(0xFF0AAEBF)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}
