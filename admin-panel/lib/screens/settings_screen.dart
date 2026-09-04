import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/admin_api.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('الإعدادات', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 24),
        // معلومات النظام
        _SettingsSection(title: 'معلومات النظام', children: [
          _SettingsRow(label: 'إصدار التطبيق', value: '1.0.0+11'),
          _SettingsRow(label: 'حالة الخادم', value: 'متصل', valueColor: const Color(0xFF4CAF50)),
          _SettingsRow(label: 'قاعدة البيانات', value: 'PostgreSQL'),
        ]),
        const SizedBox(height: 16),
        // إعدادات الدفع
        _SettingsSection(title: 'إعدادات الدفع', children: [
          _SettingsRow(label: 'العملة الافتراضية', value: 'SYP'),
          _SettingsRow(label: 'عمولة المنصة', value: '5%'),
          _SettingsRow(label: 'الحد الأدنى للسحب', value: '50,000 ل.س'),
        ]),
        const SizedBox(height: 16),
        // إعدادات الأمان
        _SettingsSection(title: 'الأمان', children: [
          _SettingsRow(label: 'المصادقة الثنائية', value: 'غير مفعلة'),
          _SettingsRow(label: 'مدة انتهاء الجلسة', value: '24 ساعة'),
          _SettingsRow(label: 'الحد الأقصى لمحاولات الدخول', value: '5 محاولات'),
        ]),
        const SizedBox(height: 24),
        // زر تسجيل الخروج
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => ref.read(adminApiProvider).logout(),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('تسجيل الخروج'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFE5392B),
              side: const BorderSide(color: Color(0xFFE5392B)),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ]),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
        for (var i = 0; i < children.length; i++) ...[
          children[i],
          if (i < children.length - 1) Divider(height: 1, color: Colors.grey[100], indent: 16),
        ],
        const SizedBox(height: 4),
      ]),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600]))),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: valueColor ?? const Color(0xFF1A1A2E))),
      ]),
    );
  }
}
