import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/skeleton_loader.dart';
import '../../core/widgets/unified_header.dart';
import '../auth/login_screen.dart';
import 'models/transfer_model.dart';
import 'state/transfers_providers.dart';
import 'widgets/receipt_sheet.dart';
import 'widgets/transfer_card.dart';
import 'widgets/transfer_details_sheet.dart';

/// صفحة التحويلات — تبويب سفلي. RTL.
/// بحث + فلاتر + بطاقات + تفاصيل + إيصال، بنفس هوية التطبيق.
class TransfersScreen extends ConsumerStatefulWidget {
  const TransfersScreen({super.key});

  @override
  ConsumerState<TransfersScreen> createState() => _TransfersScreenState();
}

class _TransfersScreenState extends ConsumerState<TransfersScreen> {
  late final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final token = ref.watch(sessionTokenProvider);

    if (token == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFDDF1F4),
        body: SafeArea(
          child: Column(
            children: [
              const UnifiedHeader(showDivider: false),
              Expanded(
                child: EmptyState(
                  icon: Icons.swap_horiz_rounded,
                  title: 'التحويلات',
                  message: 'سجّل الدخول لعرض سجل تحويلاتك وإيصالاتك.',
                  actionLabel: 'تسجيل الدخول',
                  onAction: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const LoginScreen()),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final async = ref.watch(transfersListProvider);
    final results = ref.watch(filteredTransfersProvider);
    final filter = ref.watch(transferFilterProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFDDF1F4),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const UnifiedHeader(showDivider: false),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s16, AppSpacing.s12, AppSpacing.s16, 0),
              child: Row(
                children: [
                  Text('آخر التحويلات',
                      style: AppText.headingM(c.textPrimary)),
                  const Spacer(),
                  InkWell(
                    onTap: () => _showFilterSheet(context),
                    borderRadius:
                        BorderRadius.circular(AppRadius.s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s12,
                        vertical: AppSpacing.s8,
                      ),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius:
                            BorderRadius.circular(AppRadius.s),
                        border: Border.all(color: c.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          HugeIcon(
                            icon: HugeIcons
                                .strokeRoundedFilterHorizontal,
                            color: c.primary,
                            size: 16,
                          ),
                          const SizedBox(width: AppSpacing.s4),
                          Text('متقدم',
                              style: AppText.caption(c.primary)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s16, AppSpacing.s8, AppSpacing.s16, 0),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 14, color: c.textMuted),
                  const SizedBox(width: AppSpacing.s4),
                  Text('اضغط مطولاً لعرض الإيصال',
                      style: AppText.caption(c.textMuted)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s16, AppSpacing.s12, AppSpacing.s16, 0),
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _searchCtrl,
                builder: (_, value, __) => TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => ref
                      .read(transferSearchProvider.notifier)
                      .state = v,
                  decoration: InputDecoration(
                    hintText: 'ابحث باسم المستفيد أو رقم العملية',
                    hintStyle: AppText.caption(c.textMuted),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(AppSpacing.s12),
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedSearch01,
                        color: c.primary,
                        size: 18,
                      ),
                    ),
                    suffixIcon: value.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchCtrl.clear();
                              ref
                                  .read(transferSearchProvider
                                      .notifier)
                                  .state = '';
                            },
                            icon: Icon(Icons.close_rounded,
                                size: 18, color: c.textMuted),
                          ),
                  filled: true,
                  fillColor: c.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s16,
                    vertical: AppSpacing.s12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppRadius.m),
                    borderSide: BorderSide(color: c.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppRadius.m),
                    borderSide: BorderSide(color: c.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppRadius.m),
                    borderSide: BorderSide(color: c.primary),
                  ),
                ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s16),
                itemCount: TransferFilter.values.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.s8),
                itemBuilder: (_, i) {
                  final f = TransferFilter.values[i];
                  final sel = f == filter;
                  return InkWell(
                    onTap: () => ref
                        .read(transferFilterProvider.notifier)
                        .state = f,
                    borderRadius:
                        BorderRadius.circular(AppRadius.full),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s16),
                      decoration: BoxDecoration(
                        color: sel ? c.primary : c.surface,
                        borderRadius:
                            BorderRadius.circular(AppRadius.full),
                        border: Border.all(
                          color: sel ? c.primary : c.border,
                        ),
                      ),
                      child: Text(
                        f.label,
                        style: AppText.caption(
                                sel ? Colors.white : c.textSecondary)
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            Expanded(
              child: async.when(
                loading: () => ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.s16, 0, AppSpacing.s16, 100),
                  itemCount: 5,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.s12),
                  itemBuilder: (_, __) => const SkeletonLoader(
                    height: 108,
                    borderRadius:
                        BorderRadius.all(Radius.circular(AppRadius.m)),
                  ),
                ),
                error: (_, __) => SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.only(
                        top: AppSpacing.s32,
                        left: AppSpacing.s24,
                        right: AppSpacing.s24),
                    child: _TransfersError(
                      onRetry: () =>
                          ref.invalidate(transfersListProvider),
                    ),
                  ),
                ),
                data: (_) {
                  if (results.isEmpty) {
                    return const EmptyState(
                      icon: Icons.swap_horiz_rounded,
                      title: 'لا توجد تحويلات',
                      message:
                          'لم يتم العثور على عمليات تحويل مطابقة.',
                    );
                  }
                  return RefreshIndicator(
                    color: c.primary,
                    onRefresh: () async =>
                        ref.refresh(transfersListProvider.future),
                    child: ListView.separated(
                      physics:
                          const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.s16, 0, AppSpacing.s16, 100),
                      itemCount: results.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.s12),
                      itemBuilder: (_, i) {
                        final TransferModel t = results[i];
                        return TransferCard(
                          t: t,
                          onTap: () =>
                              TransferDetailsSheet.show(context, t),
                          onLongPress: () =>
                              _TransferOptions.show(context, t),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ورقة الفلترة المتقدمة: تواريخ + مبلغ + نوع + حالة.
  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AdvancedFilterSheet(
        onClearSearch: () {
          _searchCtrl.clear();
          ref.read(transferSearchProvider.notifier).state = '';
        },
      ),
    );
  }
}

/// خطأ مدمج أعلى القائمة — بدون فراغ ضخم.
class _TransfersError extends StatelessWidget {
  const _TransfersError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error_outline_rounded, size: 44, color: c.error),
        const SizedBox(height: AppSpacing.s12),
        Text('تعذر تحميل التحويلات',
            style: AppText.headingS(c.textPrimary),
            textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.s8),
        Text('حدث خطأ أثناء تحميل بيانات التحويلات',
            style: AppText.bodyM(c.textSecondary),
            textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.s16),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: c.primary,
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.s),
            ),
          ),
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 20),
          label:
              Text('إعادة المحاولة', style: AppText.button(Colors.white)),
        ),
      ],
    );
  }
}

/// خيارات الضغط المطول: عرض الإيصال / مشاركة الإيصال.
class _TransferOptions {
  static Future<void> show(BuildContext context, TransferModel t) {
    final c = context.colors;
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.l),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s16,
          AppSpacing.s12,
          AppSpacing.s16,
          AppSpacing.s24,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s8),
              _opt(
                c,
                icon: HugeIcons.strokeRoundedReceiptText,
                label: 'عرض الإيصال',
                onTap: () {
                  Navigator.of(ctx).pop();
                  ReceiptSheet.show(context, t);
                },
              ),
              _opt(
                c,
                icon: HugeIcons.strokeRoundedShare01,
                label: 'مشاركة الإيصال',
                onTap: () {
                  Navigator.of(ctx).pop();
                  Share.share(receiptShareText(t));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _opt(AppColors c,
      {required List<List<dynamic>> icon,
      required String label,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.m),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: HugeIcon(icon: icon, color: c.primary, size: 20),
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Text(label, style: AppText.bodyM(c.textPrimary)),
            const Spacer(),
            Icon(Icons.chevron_left_rounded,
                size: 20, color: c.textMuted),
          ],
        ),
      ),
    );
  }
}

/// ورقة الفلترة المتقدمة — تواريخ ومبلغ ونوع وحالة + تطبيق/مسح.
class _AdvancedFilterSheet extends ConsumerStatefulWidget {
  const _AdvancedFilterSheet({required this.onClearSearch});
  final VoidCallback onClearSearch;

  @override
  ConsumerState<_AdvancedFilterSheet> createState() =>
      _AdvancedFilterSheetState();
}

class _AdvancedFilterSheetState
    extends ConsumerState<_AdvancedFilterSheet> {
  late final TextEditingController _minCtrl;
  late final TextEditingController _maxCtrl;

  @override
  void initState() {
    super.initState();
    _minCtrl = TextEditingController(
        text: ref.read(transferMinAmountProvider));
    _maxCtrl = TextEditingController(
        text: ref.read(transferMaxAmountProvider));
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  String _fmt(DateTime? d) =>
      d == null ? '' : '${d.year}/${d.month}/${d.day}';

  Future<void> _pick(bool isFrom) async {
    final cur = isFrom
        ? ref.read(transferDateFromProvider)
        : ref.read(transferDateToProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: cur ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    if (isFrom) {
      ref.read(transferDateFromProvider.notifier).state = picked;
    } else {
      ref.read(transferDateToProvider.notifier).state = picked;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final from = ref.watch(transferDateFromProvider);
    final to = ref.watch(transferDateToProvider);
    final advType = ref.watch(transferAdvTypeProvider);
    final advStatus = ref.watch(transferAdvStatusProvider);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.l),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s12,
        AppSpacing.s16,
        AppSpacing.s24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              Text('فلترة متقدمة',
                  style: AppText.headingS(c.textPrimary)),
              const SizedBox(height: AppSpacing.s16),
              Row(
                children: [
                  Expanded(
                      child: _dateField(c, 'من تاريخ', _fmt(from),
                          () => _pick(true))),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                      child: _dateField(
                          c, 'إلى تاريخ', _fmt(to), () => _pick(false))),
                ],
              ),
              const SizedBox(height: AppSpacing.s12),
              Row(
                children: [
                  Expanded(
                    child: _amountField(
                        c, 'الحد الأدنى للمبلغ', _minCtrl),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: _amountField(
                        c, 'الحد الأعلى للمبلغ', _maxCtrl),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s16),
              Text('نوع العملية',
                  style: AppText.caption(c.textMuted)),
              const SizedBox(height: AppSpacing.s8),
              Wrap(
                spacing: AppSpacing.s8,
                children: [
                  for (final v in AdvTransferType.values)
                    _seg(
                      c,
                      v.label,
                      v == advType,
                      () => ref
                          .read(transferAdvTypeProvider.notifier)
                          .state = v,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.s12),
              Text('الحالة', style: AppText.caption(c.textMuted)),
              const SizedBox(height: AppSpacing.s8),
              Wrap(
                spacing: AppSpacing.s8,
                runSpacing: AppSpacing.s8,
                children: [
                  for (final v in AdvTransferStatus.values)
                    _seg(
                      c,
                      v.label,
                      v == advStatus,
                      () => ref
                          .read(transferAdvStatusProvider.notifier)
                          .state = v,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.s20),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: c.primary,
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.s),
                        ),
                      ),
                      onPressed: () {
                        ref
                            .read(transferMinAmountProvider.notifier)
                            .state = _minCtrl.text.trim();
                        ref
                            .read(transferMaxAmountProvider.notifier)
                            .state = _maxCtrl.text.trim();
                        Navigator.of(context).pop();
                      },
                      child: Text('تطبيق الفلتر',
                          style: AppText.button(Colors.white)),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      clearTransferFilters(ref);
                      widget.onClearSearch();
                      Navigator.of(context).pop();
                    },
                    child: Text('مسح الفلاتر',
                        style: AppText.button(c.primary)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateField(
      AppColors c, String label, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.m),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s12,
          vertical: AppSpacing.s12,
        ),
        decoration: BoxDecoration(
          color: c.background,
          borderRadius: BorderRadius.circular(AppRadius.m),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month_outlined,
                size: 18, color: c.primary),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: Text(
                value.isEmpty ? label : value,
                textDirection:
                    value.isEmpty ? null : TextDirection.ltr,
                style: value.isEmpty
                    ? AppText.caption(c.textMuted)
                    : AppText.en(c.textPrimary,
                        size: 14, weight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _amountField(
      AppColors c, String label, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppText.caption(c.textMuted),
        filled: true,
        fillColor: c.background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s12,
          vertical: AppSpacing.s12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
          borderSide: BorderSide(color: c.primary),
        ),
      ),
    );
  }

  Widget _seg(
      AppColors c, String label, bool sel, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s8,
        ),
        decoration: BoxDecoration(
          color: sel ? c.primary : c.background,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: sel ? c.primary : c.border),
        ),
        child: Text(
          label,
          style: AppText.caption(sel ? Colors.white : c.textSecondary)
              .copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
