import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/press_scale.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/home_feed.dart';
import '../../vendors/vendor_details_screen.dart';

/// كرت بائع عمودي موحّد — يُستخدم في الرئيسية والاستكشاف بنفس الشكل:
/// صورة عريضة + شارات (الحالة/السعر/مفضلة) + اسم/تقييم/عنوان/مسافة + زر حجز واتصال.
class VendorProximityCard extends ConsumerStatefulWidget {
  const VendorProximityCard({super.key, required this.v});
  final VendorCard v;

  @override
  ConsumerState<VendorProximityCard> createState() => _VendorProximityCardState();
}

class _VendorProximityCardState extends ConsumerState<VendorProximityCard> {
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
      if (!mounted) return;
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

    return PressScale(
      onTap: _openDetails,
      child: InkWell(
      onTap: _openDetails,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
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
      ),
    );
  }
}
