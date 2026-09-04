import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/session/session_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// معلومات الحساب — ثلاث تبويبات: الحساب، الشخصية، الوصي.
class AccountInfoScreen extends ConsumerStatefulWidget {
  const AccountInfoScreen({super.key});

  @override
  ConsumerState<AccountInfoScreen> createState() => _AccountInfoScreenState();
}

class _AccountInfoScreenState extends ConsumerState<AccountInfoScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final meAsync = ref.watch(_meProvider);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: const Text('معلومات الحساب'),
        actions: [
          // زر تعديل أعلى يسار
          IconButton(
            icon: Icon(_editing ? Icons.check_rounded : Icons.edit_outlined),
            tooltip: _editing ? 'حفظ' : 'تعديل',
            onPressed: () {
              setState(() => _editing = !_editing);
              if (!_editing) {
                // حفظ التعديلات
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم حفظ التعديلات')),
                );
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: c.primary,
          unselectedLabelColor: c.textMuted,
          indicatorColor: c.primary,
          tabs: const [
            Tab(text: 'الحساب'),
            Tab(text: 'الشخصية'),
            Tab(text: 'الوصي'),
          ],
        ),
      ),
      body: meAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: c.primary)),
        error: (_, __) => Center(child: Text('خطأ في التحميل', style: AppText.bodyM(c.error))),
        data: (me) {
          final profile = (me['profile'] as Map?)?.cast<String, dynamic>() ?? const {};
          return TabBarView(
            controller: _tabController,
            children: [
              _AccountTab(profile: profile, email: '${me['email'] ?? ''}', editing: _editing),
              _PersonalTab(profile: profile, editing: _editing),
              _GuardianTab(profile: profile, editing: _editing),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────── تبويب الحساب ───────────────────────

class _AccountTab extends StatelessWidget {
  const _AccountTab({required this.profile, required this.email, required this.editing});
  final Map<String, dynamic> profile;
  final String email;
  final bool editing;

  @override
  Widget build(BuildContext context) {
    final fields = [
      _FieldData('رقم الحساب', _formatAccount('${profile['walletAccountId'] ?? ''}'), Icons.account_balance_wallet_outlined),
      _FieldData('البريد الالكتروني', email, Icons.email_outlined),
      _FieldData('رقم الهاتف', '${profile['phone'] ?? ''}', Icons.phone_outlined),
      _FieldData('نوع الحساب', _accountType(profile), Icons.badge_outlined),
      _FieldData('حالة التوثيق', _kycStatus(profile), Icons.verified_outlined),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      child: Column(children: [
        _InfoCard(
          title: 'معلومات الحساب',
          children: fields.map((f) => _InfoRow(
            icon: f.icon,
            label: f.label,
            value: f.value,
            editable: false, // الحساب لا يُعدّل
          )).toList(),
        ),
      ]),
    );
  }

  static String _formatAccount(String raw) {
    final d = raw.replaceAll(RegExp(r'[\s\-]'), '');
    if (d.length != 16) return raw;
    return '${d.substring(0, 4)} ${d.substring(4, 8)} ${d.substring(8, 12)} ${d.substring(12)}';
  }

  String _accountType(Map<String, dynamic> p) {
    if (p['role'] == 'VENDOR') return 'حساب تجاري';
    if (p['isPremium'] == true) return 'حساب مميز';
    return 'حساب عادي';
  }

  String _kycStatus(Map<String, dynamic> p) {
    final s = '${p['kycStatus'] ?? ''}';
    if (s == 'APPROVED') return 'موثق';
    if (s == 'REJECTED') return 'مرفوض';
    return 'قيد المراجعة';
  }
}

// ─────────────────────── تبويب الشخصية ───────────────────────

class _PersonalTab extends StatelessWidget {
  const _PersonalTab({required this.profile, required this.editing});
  final Map<String, dynamic> profile;
  final bool editing;

  @override
  Widget build(BuildContext context) {
    final fields = [
      _FieldData('الاسم الكامل', '${profile['fullName'] ?? ''}', Icons.person_outline_rounded),
      _FieldData('اسم الأب', '${profile['fatherName'] ?? ''}', Icons.family_restroom_outlined),
      _FieldData('اسم الأم', '${profile['motherName'] ?? ''}', Icons.family_restroom_outlined),
      _FieldData('الرقم الوطني', _mask('${profile['nationalId'] ?? ''}', 11), Icons.badge_outlined),
      _FieldData('تاريخ الميلاد', _formatDate('${profile['birthDate'] ?? ''}'), Icons.cake_outlined),
      _FieldData('المحافظة', '${profile['governorate'] ?? ''}', Icons.location_city_outlined),
      _FieldData('المدينة', '${profile['city'] ?? ''}', Icons.location_on_outlined),
      _FieldData('العنوان', '${profile['address'] ?? ''}', Icons.home_outlined),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      child: Column(children: [
        _InfoCard(
          title: 'البيانات الشخصية',
          editable: editing,
          children: fields.map((f) => _InfoRow(
            icon: f.icon,
            label: f.label,
            value: f.value,
            editable: editing,
          )).toList(),
        ),
      ]),
    );
  }

  String _mask(String v, int len) {
    if (v.length != len) return v;
    return '${v.substring(0, 2)}*******${v.substring(len - 2)}';
  }

  String _formatDate(String raw) {
    if (raw.isEmpty) return '';
    try {
      final d = DateTime.parse(raw);
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }
}

// ─────────────────────── تبويب الوصي ───────────────────────

class _GuardianTab extends StatelessWidget {
  const _GuardianTab({required this.profile, required this.editing});
  final Map<String, dynamic> profile;
  final bool editing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fields = [
      _FieldData('اسم الوصي', '${profile['guardianName'] ?? ''}', Icons.person_outline_rounded),
      _FieldData('صلة القرابة', '${profile['guardianRelation'] ?? ''}', Icons.family_restroom_outlined),
      _FieldData('هاتف الوصي', '${profile['guardianPhone'] ?? ''}', Icons.phone_outlined),
      _FieldData('عنوان الوصي', '${profile['guardianAddress'] ?? ''}', Icons.home_outlined),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      child: Column(children: [
        _InfoCard(
          title: 'بيانات الوصي',
          editable: editing,
          children: fields.map((f) => _InfoRow(
            icon: f.icon,
            label: f.label,
            value: f.value,
            editable: editing,
          )).toList(),
        ),
        if (editing) ...[
          const SizedBox(height: AppSpacing.s16),
          Text(
            'ملاحظة: بيانات الوصي مطلوبة للحسابات تحت سن 18.',
            style: AppText.caption(c.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ]),
    );
  }
}

// ─────────────────────── مكونات مشتركة ───────────────────────

class _FieldData {
  const _FieldData(this.label, this.value, this.icon);
  final String label;
  final String value;
  final IconData icon;
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.children, this.editable = false});
  final String title;
  final List<Widget> children;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(children: children),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.editable,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Icon(icon, size: 20, color: const Color(0xFF0AAEBF)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppText.caption(c.textMuted)),
              const SizedBox(height: 2),
              editable
                  ? _EditableField(value: value)
                  : Text(
                      value.isNotEmpty ? value : '—',
                      style: AppText.bodyL(c.textPrimary),
                      textDirection: _isLtr(value) ? TextDirection.ltr : null,
                    ),
            ],
          ),
        ),
        if (!editable && value.isNotEmpty)
          Icon(Icons.chevron_left_rounded, size: 20, color: c.textMuted),
      ]),
    );
  }

  bool _isLtr(String v) => RegExp(r'^[0-9+@]').hasMatch(v);
}

class _EditableField extends StatelessWidget {
  const _EditableField({required this.value});
  final String value;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value,
      style: AppText.bodyL(const Color(0xFF0A2E33)),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 4),
        border: UnderlineInputBorder(
          borderSide: BorderSide(color: const Color(0xFF0AAEBF).withOpacity(0.3)),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF0AAEBF), width: 2),
        ),
      ),
    );
  }
}

// ─────────────────────── Provider ───────────────────────

final _meProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final d = await ref.watch(apiClientProvider).get('/users/me/profile');
  if (d is Map) return Map<String, dynamic>.from(d);
  return const {};
});
