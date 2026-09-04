import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/admin_api.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  List<dynamic> _cats = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await ref.read(adminApiProvider).get('/categories');
      if (mounted) setState(() {
        _cats = d is List ? d : (d is Map ? (d['data'] ?? []) : []);
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
          const Text('التصنيفات', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => _showAddDialog(),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('إضافة تصنيف'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0AAEBF), foregroundColor: Colors.white),
          ),
          const SizedBox(width: 8),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ]),
      ),
      Divider(height: 1, color: Colors.grey[200]),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView.separated(
                padding: const EdgeInsets.all(24),
                itemCount: _cats.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final c = _cats[i] as Map<String, dynamic>;
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
                        decoration: BoxDecoration(color: const Color(0xFF0AAEBF).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.category_rounded, color: Color(0xFF0AAEBF)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${c['nameAr'] ?? c['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text('${c['slug'] ?? ''}', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                      ])),
                      IconButton(onPressed: () {}, icon: const Icon(Icons.edit_outlined, size: 20), tooltip: 'تعديل'),
                      IconButton(onPressed: () {}, icon: Icon(Icons.delete_outline_rounded, size: 20, color: Colors.grey[400]), tooltip: 'حذف'),
                    ]),
                  );
                },
              ),
      ),
    ]);
  }

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final slugCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('إضافة تصنيف'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'الاسم بالعربية')),
          const SizedBox(height: 12),
          TextField(controller: slugCtrl, decoration: const InputDecoration(labelText: 'Slug (EN)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(d);
              try {
                await ref.read(adminApiProvider).post('/categories', body: {'nameAr': nameCtrl.text.trim(), 'slug': slugCtrl.text.trim()});
                _load();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }
}
