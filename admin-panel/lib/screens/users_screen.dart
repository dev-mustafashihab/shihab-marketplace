import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/admin_api.dart';

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  List<dynamic> _users = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await ref.read(adminApiProvider).get('/users?limit=100');
      if (mounted) setState(() {
        _users = d is Map ? (d['data'] ?? d['users'] ?? []) : (d is List ? d : []);
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reviewKyc(String userId, String status, {String? note}) async {
    try {
      await ref.read(adminApiProvider).patch('/users/$userId/kyc', body: {'status': status, if (note != null) 'note': note});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(status == 'APPROVED' ? 'تم اعتماد التوثيق' : 'تم رفض التوثيق')));
        _load();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _search.isEmpty ? _users : _users.where((u) {
      final name = '${u['profile']?['fullName'] ?? u['email'] ?? ''}'.toLowerCase();
      return name.contains(_search.toLowerCase());
    }).toList();

    return Column(children: [
      // شريط الأدوات
      Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
        color: Colors.white,
        child: Row(children: [
          const Text('المستخدمين', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(width: 24),
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'بحث بالاسم أو البريد...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded), tooltip: 'تحديث'),
        ]),
      ),
      Divider(height: 1, color: Colors.grey[200]),
      // القائمة
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView.separated(
                padding: const EdgeInsets.all(24),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _UserTile(
                  user: filtered[i],
                  onApprove: () => _reviewKyc(filtered[i]['id'], 'APPROVED'),
                  onReject: () => _showRejectDialog(filtered[i]['id']),
                ),
              ),
      ),
    ]);
  }

  void _showRejectDialog(String userId) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('رفض التوثيق'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'سبب الرفض (اختياري)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('إلغاء')),
          TextButton(
            onPressed: () { Navigator.pop(d); _reviewKyc(userId, 'REJECTED', note: ctrl.text.trim()); },
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFE5392B)),
            child: const Text('رفض'),
          ),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user, required this.onApprove, required this.onReject});
  final Map<String, dynamic> user;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final p = (user['profile'] as Map?)?.cast<String, dynamic>() ?? const {};
    final name = '${p['fullName'] ?? user['email'] ?? 'مستخدم'}';
    final email = '${user['email'] ?? ''}';
    final role = '${user['role'] ?? 'CUSTOMER'}';
    final kyc = '${p['kycStatus'] ?? ''}';
    final phone = '${p['phone'] ?? ''}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        // أفاتار
        CircleAvatar(
          radius: 24,
          backgroundColor: const Color(0xFF0AAEBF).withOpacity(0.1),
          child: Text(name.isNotEmpty ? name[0] : '?', style: const TextStyle(color: Color(0xFF0AAEBF), fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 16),
        // معلومات
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 2),
          Text(email, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          if (phone.isNotEmpty) Text(phone, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ])),
        // شارة الدور
        _RoleBadge(role: role),
        const SizedBox(width: 12),
        // شارة KYC
        if (kyc.isNotEmpty) _KycBadge(status: kyc),
        const SizedBox(width: 12),
        // أزرار KYC
        if (kyc == 'PENDING' || kyc == 'PENDING_DOCS') ...[
          IconButton(
            onPressed: onApprove,
            icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50)),
            tooltip: 'اعتماد',
          ),
          IconButton(
            onPressed: onReject,
            icon: const Icon(Icons.cancel_rounded, color: Color(0xFFE5392B)),
            tooltip: 'رفض',
          ),
        ],
      ]),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});
  final String role;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (role) {
      'ADMIN' => ('مدير', const Color(0xFFE5392B)),
      'VENDOR' => ('بائع', const Color(0xFFFFA726)),
      _ => ('عميل', const Color(0xFF0AAEBF)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _KycBadge extends StatelessWidget {
  const _KycBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'APPROVED' => ('موثق', const Color(0xFF4CAF50)),
      'REJECTED' => ('مرفوض', const Color(0xFFE5392B)),
      _ => ('قيد المراجعة', const Color(0xFFFFA726)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
