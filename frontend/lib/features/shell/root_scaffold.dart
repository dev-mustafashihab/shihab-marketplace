import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_client.dart';
import '../../core/session/session_service.dart';
import '../home/models/home_feed.dart';
import '../home/state/home_feed_provider.dart';
import '../wallet/state/customer_wallet_provider.dart';
import '../location/location_picker.dart';
import '../services/services_screen.dart';
import '../notifications/notifications_screen.dart';
import '../home/home_search_sheet.dart';
import '../vendors/vendor_details_screen.dart';
import '../home/widgets/vendor_proximity_card.dart';
import '../../core/widgets/unified_header.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_shell.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/skeleton_loader.dart';
import '../../features/bookings/my_bookings_screen.dart';
import '../../features/explore/explore_screen.dart';
import '../../features/transfers/transfers_screen.dart';
import '../../features/profile/profile_screen.dart';

/// شريحة تصنيف رفيعة — أيقونة صغيرة واسم، تُفلتر الرئيسية مكانها.
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.name, required this.slug, this.iconKey, this.selected = false, required this.onTap});
  final String name;
  final String? slug;
  final String? iconKey;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final spec = _catSpec(slug: slug, iconKey: iconKey);
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 80, maxWidth: 220, minHeight: 40, maxHeight: 40),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Ink(
            decoration: BoxDecoration(
              color: selected ? c.primary.withOpacity(0.12) : c.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: selected ? c.primary : c.border, width: selected ? 1.5 : 1),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                textDirection: TextDirection.rtl,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: spec.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(spec.icon, size: 16, color: spec.color),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Text(
                    name,
                    style: AppText.caption(c.textPrimary),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// شريحة «الكل» — تُظهر كل التصنيفات بلا فلترة.
class _CategoryAll extends StatelessWidget {
  const _CategoryAll({required this.onTap, this.selected = true});
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: 'الكل',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 80, maxWidth: 220, minHeight: 40, maxHeight: 40),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Ink(
            decoration: BoxDecoration(
              color: selected ? c.primary : c.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: selected ? c.primary : c.border),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                textDirection: TextDirection.rtl,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: (selected ? Colors.white : c.primary).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(Icons.explore_rounded,
                        size: 16, color: selected ? Colors.white : c.primary),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Text(
                    'الكل',
                    style: AppText.caption(selected ? Colors.white : c.textPrimary),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// مواصفات التصنيف: أيقونة + لون مميز.
class _CatSpec {
  const _CatSpec(this.icon, this.color);
  final IconData icon;
  final Color color;
}

_CatSpec _catSpec({String? slug, String? iconKey}) {
  // iconKey القادم من الباكند أولاً، ثم slug، ثم الافتراضي
  switch (iconKey) {
    case 'venue':
      return _CatSpec(Icons.account_balance_rounded, const Color(0xFF8E7CC3));
    case 'salon':
      return _CatSpec(Icons.content_cut_rounded, const Color(0xFFE58BA5));
    case 'restaurant':
      return _CatSpec(Icons.restaurant_rounded, const Color(0xFFE09F5A));
    case 'gift':
      return _CatSpec(Icons.card_giftcard_rounded, const Color(0xFF64B5A4));
    case 'pool':
      return _CatSpec(Icons.pool_rounded, const Color(0xFF5A9BD5));
    case 'camera':
      return _CatSpec(Icons.photo_camera_rounded, const Color(0xFFB08968));
  }
  // الألوان ثابتة (بلا context) — درجات متناسقة مع الهوية
  switch (slug) {
    case 'venues':
      return _CatSpec(Icons.account_balance_rounded, const Color(0xFF8E7CC3));
    case 'salons':
      return _CatSpec(Icons.content_cut_rounded, const Color(0xFFE58BA5));
    case 'restaurants':
      return _CatSpec(Icons.restaurant_rounded, const Color(0xFFE09F5A));
    case 'gifts':
      return _CatSpec(Icons.card_giftcard_rounded, const Color(0xFF64B5A4));
    case 'pools':
      return _CatSpec(Icons.pool_rounded, const Color(0xFF5A9BD5));
    case 'photography':
      return _CatSpec(Icons.photo_camera_rounded, const Color(0xFFB08968));
    default:
      return _CatSpec(Icons.storefront_rounded, const Color(0xFF6B8E7B));
  }
}

/// جرس الإشعارات مع عداد غير المقروء (حي عبر provider).
class _BellButton extends ConsumerWidget {
  const _BellButton({required this.c});
  final AppColors c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final token = ref.watch(sessionTokenProvider);
    final unreadAsync = ref.watch(_unreadProvider(token));
    final unread = unreadAsync.valueOrNull ?? 0;
    return Semantics(
      button: true,
      label: 'الإشعارات',
      child: Stack(clipBehavior: Clip.none, children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(Icons.notifications_none_rounded, size: 26, color: c.textPrimary),
            ),
          ),
        ),
      if (unread > 0)
        Positioned(
          top: 6, left: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(color: c.error, borderRadius: BorderRadius.circular(10)),
            constraints: const BoxConstraints(minWidth: 16),
            child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center),
          ),
        ),
      ]),
    );
  }
}

final _unreadProvider = FutureProvider.autoDispose.family<int, String?>((ref, token) async {
  final token = ref.watch(sessionTokenProvider);
  if (token == null) return 0;
  try {
    final d = await ref.watch(apiClientProvider).get('/notifications/unread-count');
    return d is int ? d : (d is num ? d.toInt() : 0);
  } catch (_) {
    return 0;
  }
});

/// الجذر: Bottom Shell + عربي RTL من اللحظة الأولى.
class RootScaffold extends ConsumerStatefulWidget {
  const RootScaffold({super.key});

  @override
  ConsumerState<RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends ConsumerState<RootScaffold> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomeScreen(),
      const TransfersScreen(),
      const ServicesScreen(),
      const ProfileScreen(),
    ];
    return AppShell(child: pages[_tab], currentIndex: _tab, onTap: (i) => setState(() => _tab = i));
  }
}

/// بطاقة بائع — تصميم أفقي مدمج: صورة 92px + معلومات + شارة مسافة بارزة.
/// المسافة تظهر فقط عند توفر موقع المستخدم — وإلا شارة «مميز».
/// كرت بائع عمودي: صورة عريضة فوقها الشارات (الحالة/السعر/المفضلة)،
/// وتحتها الاسم والتقييم والعنوان وزرّا الحجز والاتصال.
class _VendorProximityCard extends ConsumerStatefulWidget {
  const _VendorProximityCard({required this.v});
  final VendorCard v;

  @override
  ConsumerState<_VendorProximityCard> createState() => _VendorProximityCardState();
}

class _VendorProximityCardState extends ConsumerState<_VendorProximityCard> {
  bool _fav = false;
  bool _favBusy = false;

  VendorCard get v => widget.v;

  void _openDetails() => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => VendorDetailsScreen(idOrSlug: v.slug.isEmpty ? v.id : v.slug),
      ));

  Future<void> _toggleFav() async {
    if (_favBusy) return;
    final api = ref.read(apiClientProvider);
    if (api.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('سجّل الدخول لحفظ المفضلة')),
      );
      return;
    }
    setState(() {
      _favBusy = true;
      _fav = !_fav;
    });
    try {
      await api.post('/favorites/${v.id}/toggle');
    } catch (_) {
      if (mounted) setState(() => _fav = !_fav);
    } finally {
      if (mounted) setState(() => _favBusy = false);
    }
  }

  Future<void> _call() async {
    final phone = v.phone;
    if (phone == null || phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dist = v.distanceLabel;
    final topRated = v.averageRating >= 4.5 && v.reviewsCount >= 3;

    return InkWell(
      onTap: _openDetails,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // الصورة العريضة + الشارات
          Stack(children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: v.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: 'https://panel.fahd-car.cloud${v.imageUrl}',
                      height: 150, width: double.infinity, fit: BoxFit.cover,
                      placeholder: (_, __) => Container(height: 150, color: c.primary.withOpacity(0.06)),
                      errorWidget: (_, __, ___) => Container(
                        height: 150, color: c.primary.withOpacity(0.06),
                        child: Icon(Icons.storefront_outlined, size: 40, color: c.primary.withOpacity(0.4)),
                      ),
                    )
                  : Container(
                      height: 150, color: c.primary.withOpacity(0.06),
                      child: Icon(Icons.storefront_outlined, size: 40, color: c.primary.withOpacity(0.5)),
                    ),
            ),
            // شارة الحالة فوق اليمين (بداية السطر بالعربي)
            Positioned(
              top: 8, right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: v.isOpen ? c.success : Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 7, height: 7,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text(v.isOpen ? 'مفتوح الآن' : 'مغلق',
                      style: AppText.caption(Colors.white)),
                ]),
              ),
            ),
            // قلب المفضلة فوق اليسار
            Positioned(
              top: 8, left: 8,
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 2,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _toggleFav,
                  child: Padding(
                    padding: const EdgeInsets.all(7),
                    child: _favBusy
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(_fav ? Icons.favorite : Icons.favorite_border,
                            size: 18, color: _fav ? Colors.red : c.textSecondary),
                  ),
                ),
              ),
            ),
            // شارة السعر أسفل الصورة
            if (v.minPrice != null)
              Positioned(
                bottom: 8, right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.primary, borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(v.priceLabel, style: AppText.caption(Colors.white)),
                ),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.s12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(v.name,
                    style: AppText.headingS(c.textPrimary),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (v.averageRating > 0) ...[
                  Icon(Icons.star_rounded, size: 16, color: c.accent),
                  const SizedBox(width: 2),
                  Text(v.ratingText, style: AppText.caption(c.textSecondary)),
                ],
              ]),
              const SizedBox(height: AppSpacing.s4),
              Row(children: [
                if (v.categoryName.isNotEmpty) ...[
                  Text(v.categoryName, style: AppText.caption(c.textMuted)),
                  const SizedBox(width: AppSpacing.s8),
                ],
                Icon(Icons.place_outlined, size: 12, color: c.textMuted),
                const SizedBox(width: 2),
                Expanded(child: Text(v.address,
                    style: AppText.caption(c.textMuted),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (dist != null) ...[
                  const SizedBox(width: AppSpacing.s4),
                  Icon(Icons.near_me_rounded, size: 12, color: c.primary),
                  const SizedBox(width: 2),
                  Text(dist, style: AppText.caption(c.primary)),
                ],
              ]),
              if (topRated) ...[
                const SizedBox(height: AppSpacing.s8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: c.accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.workspace_premium_rounded, size: 12, color: c.accent),
                    const SizedBox(width: 3),
                    Text('الأعلى تقييماً', style: AppText.caption(c.accent)),
                  ]),
                ),
              ],
              const SizedBox(height: AppSpacing.s8),
              Row(children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _openDetails,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(40),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('احجز الآن'),
                  ),
                ),
                if (v.phone != null && v.phone!.isNotEmpty) ...[
                  const SizedBox(width: AppSpacing.s8),
                  OutlinedButton(
                    onPressed: _call,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(40, 40),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Icon(Icons.phone_outlined, size: 18),
                  ),
                ],
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// شريحة فلترة سريعة — أيقونة ملونة + تسمية، حد ملطف بلونها.
class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        height: 48,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(17),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: color.withOpacity(0.35)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 5),
                Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: color)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// شريط البحث والفلاتر الذي يبقى مثبتاً أسفل الهيدر العلوي.
class _HomeFilterBar extends StatelessWidget {
  const _HomeFilterBar({
    required this.c,
    required this.onSearch,
    required this.onFilter,
    required this.onOpenNow,
    required this.onNearby,
    required this.onLowestPrice,
  });

  final AppColors c;
  final VoidCallback onSearch;
  final VoidCallback onFilter;
  final VoidCallback onOpenNow;
  final VoidCallback onNearby;
  final VoidCallback onLowestPrice;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: c.background,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
        decoration: BoxDecoration(
          color: c.background,
          border: Border(bottom: BorderSide(color: c.border)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.border),
            ),
            child: Row(children: [
              Expanded(
                child: InkWell(
                  onTap: onSearch,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
                    child: Row(children: [
                      Icon(Icons.search_rounded, size: 22, color: c.primary),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        child: Text(
                          'قاعة أعراس؟ صالون؟ هدية؟',
                          style: AppText.bodyM(c.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
              IconButton(
                key: const Key('home-search-filter-inline'),
                onPressed: onFilter,
                icon: Icon(Icons.tune_rounded, size: 20, color: c.primary),
                tooltip: 'فلترة النتائج',
              ),
            ]),
          ),
          const SizedBox(height: AppSpacing.s4),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
              children: [
                _QuickChip(
                  icon: Icons.schedule_rounded,
                  label: 'مفتوح الآن',
                  color: c.success,
                  onTap: onOpenNow,
                ),
                const SizedBox(width: AppSpacing.s8),
                _QuickChip(
                  icon: Icons.near_me_rounded,
                  label: 'الأقرب إليك',
                  color: c.primary,
                  onTap: onNearby,
                ),
                const SizedBox(width: AppSpacing.s8),
                _QuickChip(
                  icon: Icons.local_offer_rounded,
                  label: 'الأقل سعراً',
                  color: c.accent,
                  onTap: onLowestPrice,
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _HomeFilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _HomeFilterHeaderDelegate({required this.child, required this.height});

  final Widget child;
  final double height;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;

  @override
  bool shouldRebuild(covariant _HomeFilterHeaderDelegate oldDelegate) => true;
}

/// شريط الرصيد — EUR/USD/SYP حلقي 12px — Cairo/Inter
class _HomeBalanceBar extends ConsumerStatefulWidget {
  const _HomeBalanceBar();
  @override
  ConsumerState<_HomeBalanceBar> createState() => _HomeBalanceBarState();
}

class _HomeBalanceBarState extends ConsumerState<_HomeBalanceBar> {
  static const _currencies = ['EUR', 'USD', 'SYP'];
  late FixedExtentScrollController _ctrl;
  int _lastIdx = 1;

  @override
  void initState() {
    super.initState();
    final cur = ref.read(homeBalanceCurrencyProvider);
    _lastIdx = _currencies.indexOf(cur);
    if (_lastIdx < 0) _lastIdx = 1;
    _ctrl = FixedExtentScrollController(initialItem: _lastIdx + 1000 * _currencies.length);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _step(int dir) {
    final next = _ctrl.selectedItem + dir;
    _ctrl.animateToItem(next, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    var cur = ref.watch(homeBalanceCurrencyProvider);
    if (!_currencies.contains(cur)) cur = 'USD';
    final hidden = ref.watch(homeBalanceHiddenProvider);
    // رصيد المحفظة الحقيقي (عملة واحدة أساسية) — باقي العملات 0 مؤقتاً
    final wMap = ref.watch(customerWalletProvider).valueOrNull?['wallet'] as Map?;
    final wCur = '${wMap?['currency'] ?? 'USD'}';
    final wBal = (wMap?['balance'] as num?)?.toInt() ?? 0;
    final display = hidden ? '••••' : (cur == wCur ? '$wBal' : '0');
    final curIdx = _currencies.indexOf(cur);
    if (curIdx != _lastIdx && _ctrl.hasClients) _lastIdx = curIdx;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      height: 64,
      color: Colors.transparent,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          InkWell(
            onTap: () => ref.read(homeBalanceHiddenProvider.notifier).state = !hidden,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 38, height: 38,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFD2E9ED), borderRadius: BorderRadius.circular(10)),
              child: HugeIcon(icon: hidden ? HugeIcons.strokeRoundedViewOff : HugeIcons.strokeRoundedView, color: const Color(0xFF8AA9AD), size: 18),
            ),
          ),
          GestureDetector(
            onVerticalDragEnd: (d) {
              final v = d.primaryVelocity ?? 0;
              if (v == 0) return;
              _step(v < 0 ? 1 : -1);
            },
            child: SizedBox(
              width: 56, height: 64,
              child: ListWheelScrollView.useDelegate(
                  controller: _ctrl,
                  itemExtent: 22,
                  diameterRatio: 1.6,
                  perspective: 0.003,
                  useMagnifier: false,
                  overAndUnderCenterOpacity: 1.0,
                  physics: const NeverScrollableScrollPhysics(),
                  onSelectedItemChanged: (i) {
                    final idx = i % _currencies.length;
                    if (idx != _lastIdx) {
                      _lastIdx = idx;
                      ref.read(homeBalanceCurrencyProvider.notifier).state = _currencies[idx];
                    }
                  },
                  childDelegate: ListWheelChildLoopingListDelegate(
                    children: [
                      for (final code in _currencies)
                        Center(
                          child: Builder(builder: (_) {
                            final sel = code == cur;
                            return AnimatedOpacity(
                              duration: const Duration(milliseconds: 220),
                              opacity: 1.0,
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOut,
                                style: GoogleFonts.inter(fontSize: sel ? 17 : 11, fontWeight: sel ? FontWeight.w700 : FontWeight.w400, color: sel ? c.textPrimary : c.textMuted.withOpacity(0.6), letterSpacing: 0.6),
                                child: Text(code),
                              ),
                            );
                          }),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          const Spacer(),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            reverseDuration: Duration.zero,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero).animate(anim),
                child: child,
              ),
            ),
            child: Text(display, key: ValueKey(display), style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w600, color: c.textPrimary)),
          ),
        ]),
      ),
    );
  }
}

class _FintechServiceCard extends StatelessWidget {
  const _FintechServiceCard({required this.icon, required this.label});
  final List<List<dynamic>> icon; final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF3AA7B4), borderRadius: BorderRadius.circular(12)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        HugeIcon(icon: icon, color: Colors.white, size: 26, strokeWidth: 2.0),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.cairo(fontSize: 9.5, fontWeight: FontWeight.w500, color: Colors.white)),
      ]),
    );
  }
}

class _TransferCard extends StatelessWidget {
  const _TransferCard({required this.name, required this.amount});
  final String name; final String amount;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(color: const Color(0xFFCFE9ED), borderRadius: BorderRadius.circular(12)),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          HugeIcon(icon: HugeIcons.strokeRoundedArrowUpRight01, color: const Color(0xFFD14B4B), size: 13),
          const SizedBox(width: 4),
          Text(amount, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFFD14B4B))),
        ]),
        const Spacer(),
        Text(name, style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF0A2E33))),
        ]),
      ),
    );
  }
}

/// Home — كما في التصميم المعتمد (موقع/بحث/تصنيفات/عروض/قريب منك).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {

  void _openNearby(BuildContext context) {
    if (ref.read(userLocationProvider) == null) {
      showLocationPicker(context, ref);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const ExploreScreen(nearby: true),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final topIdentity = const UnifiedHeader(showDivider: false);
    // الرئيسية الآن محفظة فقط — باقي المحتوى انتقل لقسم خدمات
    return Scaffold(
      backgroundColor: const Color(0xFFDDF1F4),
      body: SafeArea(
        child: Stack(children: [
          // علامة مائية — شعار شفاف بالوسط مثل الصورة
          Positioned.fill(
            child: Center(
              child: Opacity(
                opacity: 0.04,
                child: Image.asset('assets/images/dabirni.png', width: 310, height: 310, fit: BoxFit.contain),
              ),
            ),
          ),
        Column(
          children: [
            topIdentity,
            const _HomeBalanceBar(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // يسار الصورة: أزرار كبيرة عمودية 57%
                  Expanded(
                    flex: 57,
                    child: Column(children: [
                      Container(
                        height: 66,
                        decoration: BoxDecoration(color: const Color(0xFF8EBE98), borderRadius: BorderRadius.circular(14)),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {},
                            borderRadius: BorderRadius.circular(14),
                            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Text('استقبال', style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                              const SizedBox(width: 6),
                              const HugeIcon(icon: HugeIcons.strokeRoundedArrowTurnDown, color: Colors.white, size: 22, strokeWidth: 2.2),
                            ]),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Container(
                        height: 66,
                        decoration: BoxDecoration(color: const Color(0xFFB86169), borderRadius: BorderRadius.circular(14)),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {},
                            borderRadius: BorderRadius.circular(14),
                            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Text('إرسال', style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                              const SizedBox(width: 6),
                              const HugeIcon(icon: HugeIcons.strokeRoundedArrowTurnUp, color: Colors.white, size: 22, strokeWidth: 2.2),
                            ]),
                          ),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 20),
                  // يمين الصورة: شبكة 2x2 داخل حاوية خارجية 43%
                  Expanded(
                    flex: 43,
                    child: SizedBox(
                      height: 147,
                      child: Column(children: [
                        Expanded(
                          child: Row(children: const [
                            Expanded(child: _FintechServiceCard(icon: HugeIcons.strokeRoundedBookmark01, label: 'خدماتي')),
                            SizedBox(width: 15),
                            Expanded(child: _FintechServiceCard(icon: HugeIcons.strokeRoundedLayers01, label: 'مدفوعاتي')),
                          ]),
                        ),
                        const SizedBox(height: 15),
                        Expanded(
                          child: Row(children: const [
                            Expanded(child: _FintechServiceCard(icon: HugeIcons.strokeRoundedBank, label: 'بنوك')),
                            SizedBox(width: 15),
                            Expanded(child: _FintechServiceCard(icon: HugeIcons.strokeRoundedCardExchange01, label: 'حوالات')),
                          ]),
                        ),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
              child: Row(children: [
                Text('آخر المدفوعات', style: GoogleFonts.cairo(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF0A2E33))),
                const Spacer(),
              ]),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                itemCount: 3,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => const _TransferCard(
                  name: 'وزارة التعليم العالي',
                  amount: 'SYP 25,000',
                ),
              ),
            ),
          ],
        ),
        ]),
      ),
    );
  }

}
