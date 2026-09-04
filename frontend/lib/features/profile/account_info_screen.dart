import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  final _accountKey = GlobalKey<_AccountTabState>();
  final _personalKey = GlobalKey<_PersonalTabState>();
  final _guardianKey = GlobalKey<_GuardianTabState>();

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

  bool get _isDirty {
    return (_accountKey.currentState?.isDirty ?? false) ||
        (_personalKey.currentState?.isDirty ?? false) ||
        (_guardianKey.currentState?.isDirty ?? false);
  }

  void _discardAll() {
    _accountKey.currentState?.reset();
    _personalKey.currentState?.reset();
    _guardianKey.currentState?.reset();
    setState(() => _editing = false);
  }

  Future<void> _tryCancel() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_isDirty) {
      setState(() => _editing = false);
      return;
    }
    final discard = await _showDiscardDialog();
    if (discard == true) _discardAll();
  }

  Future<bool> _onWillPop() async {
    if (!_editing || !_isDirty) return true;
    FocusManager.instance.primaryFocus?.unfocus();
    final discard = await _showDiscardDialog();
    if (discard == true) {
      _discardAll();
      return true;
    }
    return false;
  }

  Future<bool?> _showDiscardDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
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
      ),
    );
  }

  void _save() {
    setState(() => _editing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ التعديلات')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final meAsync = ref.watch(_meProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: WillPopScope(
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: TextButton.icon(
                    onPressed: _isDirty ? _save : null,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('حفظ'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: _isDirty ? const Color(0xFF0AAEBF) : const Color(0xFFB0BEC5),
                      disabledBackgroundColor: const Color(0xFFB0BEC5),
                      disabledForegroundColor: Colors.white70,
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
                physics: const ClampingScrollPhysics(),
                children: [
                  _AccountTab(key: _accountKey, profile: profile, email: '${me['email'] ?? ''}', editing: _editing),
                  _PersonalTab(key: _personalKey, profile: profile, editing: _editing),
                  _GuardianTab(key: _guardianKey, profile: profile, editing: _editing),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
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

class _AccountTabState extends State<_AccountTab> {
  late String _origEmail, _origPhone, _origBio;
  late TextEditingController _emailCtrl, _phoneCtrl, _bioCtrl;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _origEmail = widget.email;
    _origPhone = '${widget.profile['phone'] ?? ''}';
    _origBio = '${widget.profile['bio'] ?? ''}';
    _emailCtrl = TextEditingController(text: _origEmail);
    _phoneCtrl = TextEditingController(text: _origPhone);
    _bioCtrl = TextEditingController(text: _origBio);
    _emailCtrl.addListener(_checkDirty);
    _phoneCtrl.addListener(_checkDirty);
    _bioCtrl.addListener(_checkDirty);
  }

  @override
  void dispose() {
    _emailCtrl.removeListener(_checkDirty);
    _phoneCtrl.removeListener(_checkDirty);
    _bioCtrl.removeListener(_checkDirty);
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  void _checkDirty() {
    final nowDirty = _emailCtrl.text != _origEmail ||
        _phoneCtrl.text != _origPhone ||
        _bioCtrl.text != _origBio;
    if (nowDirty != _dirty) setState(() => _dirty = nowDirty);
  }

  bool get isDirty => _dirty;

  void reset() {
    setState(() {
      _emailCtrl.text = _origEmail;
      _phoneCtrl.text = _origPhone;
      _bioCtrl.text = _origBio;
      _dirty = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      child: _InfoCard(children: [
        _InfoRow(
          icon: Icons.alternate_email_rounded,
          label: 'البريد الالكتروني',
          controller: _emailCtrl,
          editable: widget.editing,
          fieldDirection: TextDirection.ltr,
          keyboardType: TextInputType.emailAddress,
        ),
        _InfoRow(
          icon: Icons.phone_outlined,
          label: 'رقم الهاتف',
          controller: _phoneCtrl,
          editable: widget.editing,
          fieldDirection: TextDirection.ltr,
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

class _PersonalTabState extends State<_PersonalTab> {
  static const _keys = [
    'fullName', 'fatherName', 'motherName', 'nationalId',
    'birthDate', 'governorate', 'city', 'address',
  ];
  static const _labels = [
    'الاسم الكامل', 'اسم الاب', 'اسم الام', 'الرقم الوطني',
    'تاريخ الميلاد', 'المحافظة', 'المدينة', 'العنوان',
  ];
  static const _icons = [
    Icons.person_outline_rounded, Icons.emoji_people_outlined,
    Icons.emoji_people_outlined, Icons.fingerprint,
    Icons.cake_outlined, Icons.location_city_outlined,
    Icons.place_outlined, Icons.home_outlined,
  ];
  static const _types = [
    TextInputType.text, TextInputType.text, TextInputType.text,
    TextInputType.number, TextInputType.datetime,
    TextInputType.text, TextInputType.text, TextInputType.text,
  ];
  static const _ltrField = [false, false, false, true, true, false, false, false];

  late Map<String, String> _orig;
  late Map<String, TextEditingController> _ctrls;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _orig = {};
    _ctrls = {};
    for (final k in _keys) {
      String raw = '${widget.profile[k] ?? ''}';
      if (k == 'birthDate') raw = _formatDate(raw);
      _orig[k] = raw;
      _ctrls[k] = TextEditingController(text: raw);
      _ctrls[k]!.addListener(_checkDirty);
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.removeListener(_checkDirty);
      c.dispose();
    }
    super.dispose();
  }

  void _checkDirty() {
    final nowDirty = _ctrls.entries.any((e) => e.value.text != _orig[e.key]);
    if (nowDirty != _dirty) setState(() => _dirty = nowDirty);
  }

  bool get isDirty => _dirty;

  void reset() {
    setState(() {
      for (final e in _ctrls.entries) e.value.text = _orig[e.key]!;
      _dirty = false;
    });
  }

  static String _formatDate(String raw) {
    if (raw.isEmpty) return '';
    try {
      final d = DateTime.parse(raw);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return raw;
    }
  }

  String _mask(String v) {
    if (v.length != 11) return v;
    return '${v.substring(0, 2)}*******${v.substring(9)}';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      child: _InfoCard(children: [
        for (var i = 0; i < _keys.length; i++) ...[
          _InfoRow(
            icon: _icons[i],
            label: _labels[i],
            controller: _ctrls[_keys[i]]!,
            editable: widget.editing,
            keyboardType: _types[i],
            fieldDirection: _ltrField[i] ? TextDirection.ltr : TextDirection.rtl,
            masked: _keys[i] == 'nationalId' && !widget.editing ? _mask : null,
          ),
          if (i < _keys.length - 1)
            Divider(height: 1, color: const Color(0xFFD6EAF0), indent: 52),
        ],
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

class _GuardianTabState extends State<_GuardianTab> {
  static const _keys = ['guardianName', 'guardianRelation', 'guardianPhone', 'guardianAddress'];
  static const _labels = ['اسم الوصي', 'صلة القرابة', 'هاتف الوصي', 'عنوان الوصي'];
  static const _icons = [
    Icons.person_outline_rounded, Icons.family_restroom_outlined,
    Icons.phone_outlined, Icons.home_outlined,
  ];
  static const _types = [
    TextInputType.text, TextInputType.text,
    TextInputType.phone, TextInputType.text,
  ];
  static const _ltrField = [false, false, true, false];

  late Map<String, String> _orig;
  late Map<String, TextEditingController> _ctrls;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _orig = {for (final k in _keys) k: '${widget.profile[k] ?? ''}'};
    _ctrls = {for (final k in _keys) k: TextEditingController(text: _orig[k])};
    for (final c in _ctrls.values) c.addListener(_checkDirty);
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.removeListener(_checkDirty);
      c.dispose();
    }
    super.dispose();
  }

  void _checkDirty() {
    final nowDirty = _ctrls.entries.any((e) => e.value.text != _orig[e.key]);
    if (nowDirty != _dirty) setState(() => _dirty = nowDirty);
  }

  bool get isDirty => _dirty;

  void reset() {
    setState(() {
      for (final e in _ctrls.entries) e.value.text = _orig[e.key]!;
      _dirty = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      child: Column(children: [
        _InfoCard(children: [
          for (var i = 0; i < _keys.length; i++) ...[
            _InfoRow(
              icon: _icons[i],
              label: _labels[i],
              controller: _ctrls[_keys[i]]!,
              editable: widget.editing,
              keyboardType: _types[i],
              fieldDirection: _ltrField[i] ? TextDirection.ltr : TextDirection.rtl,
            ),
            if (i < _keys.length - 1)
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
            child: const Row(children: [
              Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFFFFA726)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'بيانات الوصي مطلوبة للحسابات تحت سن 18.',
                  style: TextStyle(fontSize: 12, color: Color(0xFFFFA726)),
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
    this.fieldDirection = TextDirection.rtl,
    this.maxLines = 1,
    this.masked,
  });

  final IconData icon;
  final String label;
  final TextEditingController controller;
  final bool editable;
  final TextInputType keyboardType;
  final TextDirection fieldDirection;
  final int maxLines;
  final String Function(String)? masked;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final displayValue = masked != null ? masked!(controller.text) : controller.text;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // أيقونة
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppText.caption(c.textMuted)),
              const SizedBox(height: 4),
              editable
                  ? Directionality(
                      textDirection: fieldDirection,
                      child: TextFormField(
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
