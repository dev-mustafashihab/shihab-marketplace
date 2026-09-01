# DESIGN SYSTEM — نظام التصميم (Design Tokens)

## 1) الهوية
**الشخصية:** Premium هادئ، عربي أولاً، ثقة. لا تدرجات لونية، لا Glassmorphism، ظلال منخفضة فقط (elevation 1-2).
**Families:** Primary = Deep Teal (ثقة/هدوء)، Accent = Warm Gold (فخامة المناسبات بجرعة مقتصدة)، Neutral = دافئ رمادي.

## 2) الألوان (Color Tokens)

### Light Theme (الافتراضي)
| Token | Hex | الاستخدام |
|---|---|---|
| `colorPrimary` | `#0F6B5C` Deep Teal | أزرار رئيسية، روابط، الحالة النشطة |
| `colorPrimaryPressed` | `#0B564A` | pressed للـ primary |
| `colorAccent` | `#C9A227` Warm Gold | مميزات، عروض، شارة التوثيق (مقتصد) |
| `colorBackground` | `#F7F6F2` Warm Off-white | خلفية الشاشات |
| `colorSurface` | `#FFFFFF` | كروت، Sheets، App bar |
| `colorTextPrimary` | `#1C1B18` | نص أساسي |
| `colorTextSecondary` | `#5F5B54` | نص ثانوي |
| `colorTextMuted` | `#98938A` | hints، captions |
| `colorSuccess` | `#2E7D32` | تأكيد، متاح |
| `colorWarning` | `#B26A00` | تنبيه، «آخر فترة» |
| `colorError` | `#C0392B` | أخطاء، غير متاح |
| `colorBorder` | `#E4E1DA` | حدود، فواصل |
| `colorScaffoldDark` | `#101413` | (Dark mode لاحقاً) |

### Dark Theme (معماري جاهز — تفعيل لاحقاً)
| Token | Hex |
|---|---|
| `colorPrimary` | `#3D9B8A` |
| `colorAccent` | `#D9B84A` |
| `colorBackground` | `#101413` |
| `colorSurface` | `#1A201E` |
| `colorTextPrimary` | `#F0EFEA` |
| `colorTextSecondary` | `#B5B0A6` |
| `colorBorder` | `#2A312E` |

**قاعدة:** Widgets لا تكتب Hex أبداً — فقط tokens عبر `context.colors.x` (ThemeExtension).

## 3) Typography — Arabic-first

**Fonts:** `IBM Plex Sans Arabic` (عناوين ونصوص — وضوح عالٍ، أرقام لاتينية نظيفة) + `Inter` للإنجليزية الرقمية (أسعار/أكواد). Fallback: Noto Naskh Arabic.

| Token | Size/Height | Weight | الاستخدام |
|---|---|---|---|
| `displayL` | 32/40 | Bold | أرقام كبيرة (إجمالي، سعر) |
| `headingL` | 24/32 | Bold | عناوين شاشة |
| `headingM` | 20/28 | SemiBold | عناوين أقسام |
| `headingS` | 17/24 | SemiBold | عناوين كروت |
| `bodyL` | 16/26 | Regular | نص أساسي |
| `bodyM` | 14/22 | Regular | نص ثانوي |
| `caption` | 12/18 | Regular | hints، أوقات |
| `button` | 15/20 | SemiBold | أزرار |
| `price` | 18/24 | Bold | الأسعار (Inter، tabular figures) |

**قواعد عربية:** lineHeight مريح (1.55-1.65)؛ أرقام غربية (1,2,3) في الأسعار والتواريخ (وضوح تجاري) مع خيار محلي لاحقاً؛ نصوص أزرار صيغة فعل («احجز الآن» لا «الحجز»)؛ طول السطر ≤ 72 حرفاً؛ ellipsis بعد سطرين للوصف مع «المزيد».

## 4) Spacing & Shape & Elevation

**Spacing scale (الوحيد المسموح):** `4, 8, 12, 16, 20, 24, 32, 40, 48` — هوامش الشاشة 16، تباعد الأقسام 24، داخل الكارت 16، بين العناصر 8-12.

**Radius:** `radiusS=8` (chips/inputs)، `radiusM=12` (كروت)، `radiusL=16` (sheets)، `radiusFull=999` (أفاتار/دائري مقصود).
**Elevation:** `e0` بلا ظل، `e1` = 0/1/3 (كروت)، `e2` = 0/2/8 (sheets/أزرار عائمة). لا ظلال ملونة.
**Touch targets:** ≥ 48×48dp دائماً؛ التباعد بين الأهداف التفاعلية ≥ 8dp.

## 5) Icons & Imagery
Line icons (Material Symbols rounded) بسمك موحد 1.5-2px، حجم 24/20. صور البائعين 4:3 مع `radiusM`؛ placeholder دائم (Skeleton) — لا صور مكسورة.

## 6) Motion (مقتصد)
| Token | المدة | المنحنى |
|---|---|---|
| `motionFast` | 120ms | ease-out |
| `motionBase` | 220ms | ease-in-out |
| `motionSheet` | 280ms | emphasized |

مسموح: ظهور Sheets، تقدم Stepper، Skeleton fade. ممنوع: دوران/ارتداد/parallax. احترام `MediaQuery.disableAnimations`.

## 7) الثيم في الكود
```
core/theme/
  app_colors.dart      (ThemeExtension<AppColors> light+dark)
  app_typography.dart
  app_spacing.dart     (AppSpacing.s4 ... s48 constants)
  app_radius.dart, app_motion.dart
  theme.dart           (lightTheme(), darkTheme())
```
كل القيم من هنا فقط. أرقام عشوائية في widgets = فشل مراجعة.
