import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/admin_api.dart';

class VendorsScreen extends ConsumerStatefulWidget {
  const VendorsScreen({super.key});

  @override
  ConsumerState<VendorsScreen> createState() => _VendorsScreenState();
}

class _VendorsScreenState extends ConsumerState<VendorsScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  Map<String, List<dynamic>> _queues = {'PENDING': [], 'APPROVED': [], 'REJECTED': []};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
  }

  Future<void> _load() async {
    try {
      final api = ref.read(adminApiProvider);
      final pending = await api.get('/vendors/admin/queue/PENDING?limit=50');
      final approved = await api.get('/vendors/admin/queue/APPROVED?limit=50');
      final rejected = await api.get('/vendors/admin/queue/REJECTED?limit=50');
      if (mounted) setState(() {
        _queues = {
          'PENDING': pending is Map ? (pending['data'] ?? []) : (pending is List ? pending : []),
          'APPROVED': approved is Map ? (approved['data'] ?? []) : (approved is List ? approved : []),
          'REJECTED': rejected is Map ? (rejected['data'] ?? []) : (rejected is List ? rejected : []),
        };
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
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        child: Row(children: [
          const Text('البائعين', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const Spacer(),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ]),
      ),
      Container(
        color: Colors.white,
        child: TabBar(
          controller: _tab,
          labelColor: const Color(0xFF0AAEBF),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF0AAEBF),
          tabs: [
            Tab(text: 'بانتظار الموافقة (${_queues['PENDING']!.length})'),
            Tab(text: 'معتمد (${_queues['APPROVED']!.length})'),
            Tab(text: 'مرفوض (${_queues['REJECTED']!.length})'),
          ],
        ),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(controller: _tab, children: [
                _buildList('PENDING', showActions: true),
                _buildList('APPROVED'),
                _buildList('REJECTED'),
              ]),
      ),
    ]);
  }

  Widget _buildList(String status, {bool showActions = false}) {
    final items = _queues[status] ?? [];
    if (items.isEmpty) return Center(child: Text('لا يوجد بائعين', style: TextStyle(color: Colors.grey[500])));
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final v = items[i] as Map<String, dynamic>;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Row(children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFFFFA726).withOpacity(0.1),
              child: const Icon(Icons.store_rounded, color: Color(0xFFFFA726)),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${v['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('${v['categoryName'] ?? ''}', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              if (v['phone'] != null) Text('${v['phone']}', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ])),
            if (showActions) ...[
              ElevatedButton.icon(
                onPressed: () => _updateStatus(v['id'], 'APPROVED'),
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('اعتماد'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), foregroundColor: Colors.white),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _updateStatus(v['id'], 'REJECTED'),
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('رفض'),
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFE5392B)),
              ),
            ],
          ]),
        );
      },
    );
  }

  Future<void> _updateStatus(String vendorId, String status) async {
    try {
      await ref.read(adminApiProvider).patch('/vendors/$vendorId', body: {'status': status});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(status == 'APPROVED' ? 'تم اعتماد البائع' : 'تم رفض البائع')));
        _load();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }
}
