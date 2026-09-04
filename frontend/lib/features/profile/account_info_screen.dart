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
          // زر تعديل / حفظ
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: _editing
                ? TextButton.icon(
                    onPressed: () {
                      setState(() => _editing = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم حفظ التعديلات')),
                      );
                    },
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('حفظ'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: const Color(0xFF0AAEBF),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'تعديل',
                    onPressed: () => setState(() => _editing = true),
                  ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: c.primary,
          unselectedLabelColor: c.textMuted,
          indicatorColor: c.primary,
          indicatorWeight: 3,
          labelStyle: AppText.bodyM(c.textPrimary).copyWith(fontWeight: FontWeight.w600),
          unselectedLabelStyle: AppText.bodyM(c.textMuted),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      child: Column(children: [
        _InfoCard(
          children: [
            _InfoRow(
              icon: Icons.alternate_email_rounded,
              label: 'البريد الالكتروني',
              value: email,
              editable: editing,
            ),
            _InfoRow(
              icon: Icons.phone_outlined,
              label: 'رقم الهاتف',
              value: '${profile['phone'] ?? ''}',
              editable: editing,
            ),
            _InfoRow(
              icon: Icons.edit_note_rounded,
              label: 'البايو',
              value: '${profile['bio'] ?? ''}',
              editable: editing,
              maxLines: 3,
            ),
          ],
        ),
      ]),
    );
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
      _FieldData('اسم الأب', '${profile['fatherName'] ?? ''}', Icons.emoji_people_outlined),
      _FieldData('اسم الأم', '${profile['motherName'] ?? ''}', Icons.emoji_people_outlined),
      _FieldData('الرقم الوطني', _mask('${profile['nationalId'] ?? ''}', 11), Icons.fingerprint),
      _FieldData('تاريخ الميلاد', _formatDate('${profile['birthDate'] ?? ''}'), Icons.cake_outlined),
      _FieldData('المحافظة', '${profile['governorate'] ?? ''}', Icons.location_city_outlined),
      _FieldData('المدينة', '${profile['city'] ?? ''}', Icons.place_outlined),
      _FieldData('العنوان', '${profile['address'] ?? ''}', Icons.home_outlined),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      child: Column(children: [
        _InfoCard(
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
          children: fields.map((f) => _InfoRow(
            icon: f.icon,
            label: f.label,
            value: f.value,
            editable: editing,
          )).toList(),
        ),
        if (editing) ...[
          const SizedBox(height: AppSpacing.s16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFA726).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFFFFA726)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'بيانات الوصي مطلوبة للحسابات تحت سن 18.',
                  style: AppText.caption(const Color(0xFFFFA726)),
                ),
              ),
            ]),
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
  const _InfoCard({required this.children});
  final List<Widget> children;

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
        child: Column(children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(height: 1, color: const Color(0xFFD6EAF0), indent: 52),
          ],
        ]),
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
    this.maxLines = 1,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool editable;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF0AAEBF).withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF0AAEBF)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppText.caption(c.textMuted)),
              const SizedBox(height: 4),
              editable
                  ? _EditableField(value: value, maxLines: maxLines)
                  : Text(
                      value.isNotEmpty ? value : '—',
                      style: AppText.bodyL(c.textPrimary),
                      textDirection: _isLtr(value) ? TextDirection.ltr : null,
                      maxLines: maxLines,
                      overflow: TextOverflow.ellipsis,
                    ),
            ],
          ),
        ),
      ]),
    );
  }

  bool _isLtr(String v) => RegExp(r'^[0-9+@]').hasMatch(v);
}

class _EditableField extends StatelessWidget {
  const _EditableField({required this.value, this.maxLines = 1});
  final String value;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value,
      maxLines: maxLines,
      style: AppText.bodyL(const Color(0xFF0A2E33)),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        filled: true,
        fillColor: const Color(0xFFF2FBFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF0AAEBF), width: 1.5),
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
