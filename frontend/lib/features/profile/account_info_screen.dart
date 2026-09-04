import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/session/session_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// معلومات الحساب — ثلاث تبويبات: الحساب، الشخصية، الوصي.
/// وضع التعديل مع: إلغاء، تتبع dirty، تعطيل الحفظ، نافذة تجاهل.
class AccountInfoScreen extends ConsumerStatefulWidget {
  const AccountInfoScreen({super.key});

  @override
  ConsumerState<AccountInfoScreen> createState() => _AccountInfoScreenState();
}

class _AccountInfoScreenState extends ConsumerState<AccountInfoScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _editing = false;

  // مفاتيح النماذج لكل تبويب
  final _accountKey = GlobalKey<_EditableFormState>();
  final _personalKey = GlobalKey<_EditableFormState>();
  final _guardianKey = GlobalKey<_EditableFormState>();

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

  /// هل هناك تعديلات غير محفوظة؟
  bool get _isDirty {
    return (_accountKey.currentState?.isDirty ?? false) ||
        (_personalKey.currentState?.isDirty ?? false) ||
        (_guardianKey.currentState?.isDirty ?? false);
  }

  /// التراجع عن كل التعديلات
  void _discardAll() {
    _accountKey.currentState?.reset();
    _personalKey.currentState?.reset();
    _guardianKey.currentState?.reset();
    setState(() => _editing = false);
  }

  /// محاولة الإلغاء مع نافذة تأكيد
  Future<void> _tryCancel() async {
    if (!_isDirty) {
      setState(() => _editing = false);
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تجاهل التغييرات؟'),
        content: const Text('لديك تعديلات غير محفوظة. هل تريد تجاهلها؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('متابعة التحرير'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFE5392B)),
            child: const Text('تجاهل التعديلات'),
          ),
        ],
      ),
    );
    if (discard == true) _discardAll();
  }

  /// محاولة الرجوع بالنظام
  Future<bool> _onWillPop() async {
    if (!_editing || !_isDirty) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تجاهل التغييرات؟'),
        content: const Text('لديك تعديلات غير محفوظة. هل تريد تجاهلها؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('متابعة التحرير'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFE5392B)),
            child: const Text('تجاهل التعديلات'),
          ),
        ],
      ),
    );
    if (discard == true) {
      _discardAll();
      return true;
    }
    return false;
  }

  /// الحفظ
  void _save() {
    // TODO: إرسال البيانات للـ API
    setState(() => _editing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ التعديلات')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final meAsync = ref.watch(_meProvider);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          title: const Text('معلومات الحساب'),
          leading: _editing
              ? IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'إلغاء',
                  onPressed: _tryCancel,
                )
              : null,
          actions: [
            if (_editing)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: TextButton.icon(
                  onPressed: _isDirty ? _save : null,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('حفظ'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: _isDirty ? const Color(0xFF0AAEBF) : const Color(0xFF8AA9AD),
                    disabledBackgroundColor: const Color(0xFF8AA9AD),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  ),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'تعديل',
                onPressed: () => setState(() => _editing = true),
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
                _AccountTab(key: _accountKey, profile: profile, email: '${me['email'] ?? ''}', editing: _editing),
                _PersonalTab(key: _personalKey, profile: profile, editing: _editing),
                _GuardianTab(key: _guardianKey, profile: profile, editing: _editing),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────── نموذج قابل للتعديل مع تتبع dirty ───────────────────────

abstract class _EditableFormState<T extends StatefulWidget> extends State<T> {
  bool get isDirty;
  void reset();
}

// ─────────────────────── تبويب الحساب ───────────────────────

class _AccountTab extends StatefulWidget {
  const _AccountTab({super.key, required this.profile, required this.email, required this.editing});
  final Map<String, dynamic> profile;
  final String email;
  final bool editing;

  @override
  State<_AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends _EditableFormState<_AccountTab> {
  late String _origEmail, _origPhone, _origBio;
  late TextEditingController _emailCtrl, _phoneCtrl, _bioCtrl;

  @override
  void initState() {
    super.initState();
    _origEmail = widget.email;
    _origPhone = '${widget.profile['phone'] ?? ''}';
    _origBio = '${widget.profile['bio'] ?? ''}';
    _emailCtrl = TextEditingController(text: _origEmail);
    _phoneCtrl = TextEditingController(text: _origPhone);
    _bioCtrl = TextEditingController(text: _origBio);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  @override
  bool get isDirty =>
      _emailCtrl.text != _origEmail ||
      _phoneCtrl.text != _origPhone ||
      _bioCtrl.text != _origBio;

  @override
  void reset() {
    setState(() {
      _emailCtrl.text = _origEmail;
      _phoneCtrl.text = _origPhone;
      _bioCtrl.text = _origBio;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      child: Column(children: [
        _InfoCard(children: [
          _InfoRow(
            icon: Icons.alternate_email_rounded,
            label: 'البريد الالكتروني',
            controller: _emailCtrl,
            editable: widget.editing,
            textDirection: TextDirection.ltr,
            keyboardType: TextInputType.emailAddress,
          ),
          _InfoRow(
            icon: Icons.phone_outlined,
            label: 'رقم الهاتف',
            controller: _phoneCtrl,
            editable: widget.editing,
            textDirection: TextDirection.ltr,
            keyboardType: TextInputType.phone,
          ),
          _InfoRow(
            icon: Icons.edit_note_rounded,
            label: 'البايو',
            controller: _bioCtrl,
            editable: widget.editing,
            maxLines: 3,
          ),
        ]),
      ]),
    );
  }
}

// ─────────────────────── تبويب الشخصية ───────────────────────

class _PersonalTab extends StatefulWidget {
  const _PersonalTab({super.key, required this.profile, required this.editing});
  final Map<String, dynamic> profile;
  final bool editing;

  @override
  State<_PersonalTab> createState() => _PersonalTabState();
}

class _PersonalTabState extends _EditableFormState<_PersonalTab> {
  late Map<String, String> _orig;
  late Map<String, TextEditingController> _ctrls;

  static const _fields = [
    ('fullName', 'الاسم الكامل', Icons.person_outline_rounded, TextInputType.text, TextDirection.rtl),
    ('fatherName', 'اسم الاب', Icons.emoji_people_outlined, TextInputType.text, TextDirection.rtl),
    ('motherName', 'اسم الام', Icons.emoji_people_outlined, TextInputType.text, TextDirection.rtl),
    ('nationalId', 'الرقم الوطني', Icons.fingerprint, TextInputType.number, TextDirection.ltr),
    ('birthDate', 'تاريخ الميلاد', Icons.cake_outlined, TextInputType.text, TextDirection.ltr),
    ('governorate', 'المحافظة', Icons.location_city_outlined, TextInputType.text, TextDirection.rtl),
    ('city', 'المدينة', Icons.place_outlined, TextInputType.text, TextDirection.rtl),
    ('address', 'العنوان', Icons.home_outlined, TextInputType.text, TextDirection.rtl),
  ];

  @override
  void initState() {
    super.initState();
    _orig = {for (final f in _fields) f.$1: '${widget.profile[f.$1] ?? ''}'};
    _ctrls = {for (final f in _fields) f.$1: TextEditingController(text: _orig[f.$1])};
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) c.dispose();
    super.dispose();
  }

  @override
  bool get isDirty => _ctrls.entries.any((e) => e.value.text != _orig[e.key]);

  @override
  void reset() {
    setState(() {
      for (final e in _ctrls.entries) e.value.text = _orig[e.key]!;
    });
  }

  String _mask(String v) {
    if (v.length != 11) return v;
    return '${v.substring(0, 2)}*******${v.substring(9)}';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      child: Column(children: [
        _InfoCard(children: [
          for (var i = 0; i < _fields.length; i++) ...[
            _InfoRow(
              icon: _fields[i].$3,
              label: _fields[i].$2,
              controller: _ctrls[_fields[i].$1]!,
              editable: widget.editing,
              keyboardType: _fields[i].$4,
              textDirection: _fields[i].$5,
              masked: _fields[i].$1 == 'nationalId' && !widget.editing ? _mask : null,
            ),
            if (i < _fields.length - 1)
              Divider(height: 1, color: const Color(0xFFD6EAF0), indent: 52),
          ],
        ]),
      ]),
    );
  }
}

// ─────────────────────── تبويب الوصي ───────────────────────

class _GuardianTab extends StatefulWidget {
  const _GuardianTab({super.key, required this.profile, required this.editing});
  final Map<String, dynamic> profile;
  final bool editing;

  @override
  State<_GuardianTab> createState() => _GuardianTabState();
}

class _GuardianTabState extends _EditableFormState<_GuardianTab> {
  late Map<String, String> _orig;
  late Map<String, TextEditingController> _ctrls;

  static const _fields = [
    ('guardianName', 'اسم الوصي', Icons.person_outline_rounded, TextInputType.text, TextDirection.rtl),
    ('guardianRelation', 'صلة القرابة', Icons.family_restroom_outlined, TextInputType.text, TextDirection.rtl),
    ('guardianPhone', 'هاتف الوصي', Icons.phone_outlined, TextInputType.phone, TextDirection.ltr),
    ('guardianAddress', 'عنوان الوصي', Icons.home_outlined, TextInputType.text, TextDirection.rtl),
  ];

  @override
  void initState() {
    super.initState();
    _orig = {for (final f in _fields) f.$1: '${widget.profile[f.$1] ?? ''}'};
    _ctrls = {for (final f in _fields) f.$1: TextEditingController(text: _orig[f.$1])};
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) c.dispose();
    super.dispose();
  }

  @override
  bool get isDirty => _ctrls.entries.any((e) => e.value.text != _orig[e.key]);

  @override
  void reset() {
    setState(() {
      for (final e in _ctrls.entries) e.value.text = _orig[e.key]!;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      child: Column(children: [
        _InfoCard(children: [
          for (var i = 0; i < _fields.length; i++) ...[
            _InfoRow(
              icon: _fields[i].$3,
              label: _fields[i].$2,
              controller: _ctrls[_fields[i].$1]!,
              editable: widget.editing,
              keyboardType: _fields[i].$4,
              textDirection: _fields[i].$5,
            ),
            if (i < _fields.length - 1)
              Divider(height: 1, color: const Color(0xFFD6EAF0), indent: 52),
          ],
        ]),
        if (widget.editing) ...[
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
        child: Column(children: children),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.controller,
    required this.editable,
    this.keyboardType = TextInputType.text,
    this.textDirection = TextDirection.rtl,
    this.maxLines = 1,
    this.masked,
  });

  final IconData icon;
  final String label;
  final TextEditingController controller;
  final bool editable;
  final TextInputType keyboardType;
  final TextDirection textDirection;
  final int maxLines;
  final String Function(String)? masked;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final displayValue = masked != null ? masked!(controller.text) : controller.text;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // أيقونة في مربع صغير
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
        // الحقل
        Expanded(
          child: Directionality(
            textDirection: textDirection,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppText.caption(c.textMuted)),
                const SizedBox(height: 4),
                editable
                    ? TextFormField(
                        controller: controller,
                        maxLines: maxLines,
                        keyboardType: keyboardType,
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
                      )
                    : Text(
                        displayValue.isNotEmpty ? displayValue : '—',
                        style: AppText.bodyL(c.textPrimary),
                        maxLines: maxLines,
                        overflow: TextOverflow.ellipsis,
                      ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────── Provider ───────────────────────

final _meProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final d = await ref.watch(apiClientProvider).get('/users/me/profile');
  if (d is Map) return Map<String, dynamic>.from(d);
  return const {};
});
