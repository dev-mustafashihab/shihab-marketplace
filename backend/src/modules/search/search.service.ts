import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/prisma.service';

export interface SearchFilters {
  q?: string;
  categoryId?: string;
  minRating?: number;
  maxPrice?: number;
  currency?: string;
  lat?: number;
  lng?: number;
  radiusKm?: number;
  openNow?: boolean;
  capacity?: number;
  sort?: 'price' | 'distance' | 'rating';
  page: number;
  limit: number;
}

interface VendorSearchRow {
  id: string;
  name: string;
  slug: string;
  description: string | null;
  address: string | null;
  min_price: number | null;
  currency: string;
  is_open: boolean;
  phone: string | null;
  image_url: string | null;
  category_name_ar: string;
  average_rating: string | number | null;
  reviews_count: bigint | number;
  distance_m: string | number | null;
}

@Injectable()
export class SearchService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * بحث البائعين المعتمدين: نص + تصنيف + مسافة (PostGIS) + فلاتر.
   * كل شروط اختيارية — تُجمَّع في WHERE ديناميكي آمن (parameterized).
   */
  async searchVendors(f: SearchFilters) {
    const offset = (f.page - 1) * f.limit;
    const conditions: string[] = [`v.status = 'APPROVED'`];
    const params: unknown[] = [];
    const bind = (v: unknown) => {
      params.push(v);
      return `$${params.length}`;
    };

    if (f.q) {
      const p = bind(`%${f.q}%`);
      conditions.push(`(v.name ILIKE ${p} OR v.description ILIKE ${p})`);
    }
    if (f.categoryId) {
      conditions.push(`v.category_id = ${bind(f.categoryId)}::uuid`);
    }
    if (f.maxPrice !== undefined) {
      conditions.push(`COALESCE(v.min_price, 0) <= ${bind(f.maxPrice)}`);
    }
    // الفلترة المزدوجة: السعر يُقارن ضمن عملته فقط — بلا معنى عبر العملات
    if (f.currency !== undefined) {
      conditions.push(`v.currency = ${bind(f.currency)}`);
    }
    if (f.capacity !== undefined) {
      conditions.push(`EXISTS (SELECT 1 FROM resources r WHERE r.vendor_id = v.id AND r.is_active AND r.capacity >= ${bind(f.capacity)})`);
    }
    // PHASE 11: openNow = مفتاح البائع مفعّل + توجد الآن نافذة عمل بتوقيت البائع المحلي
    if (f.minRating !== undefined) {
      conditions.push(`COALESCE(rr.average_rating, 0) >= ${bind(f.minRating)}`);
    }
    if (f.openNow === true) {
      conditions.push(`v.is_open = TRUE AND EXISTS (
        SELECT 1 FROM resources r
        JOIN availabilities a ON a.resource_id = r.id
        WHERE r.vendor_id = v.id AND r.is_active
          AND a.weekday = EXTRACT(DOW FROM (now() AT TIME ZONE v.timezone))::int
          AND a.start_min <= EXTRACT(HOUR FROM (now() AT TIME ZONE v.timezone)) * 60
                                   + EXTRACT(MINUTE FROM (now() AT TIME ZONE v.timezone))::int
          AND a.end_min   >= EXTRACT(HOUR FROM (now() AT TIME ZONE v.timezone)) * 60
                                   + EXTRACT(MINUTE FROM (now() AT TIME ZONE v.timezone))::int
      )`);
    }
    if (f.radiusKm !== undefined && f.lat !== undefined && f.lng !== undefined) {
      conditions.push(`v.location IS NOT NULL AND ST_DWithin(v.location, ST_SetSRID(ST_MakePoint(${bind(f.lng)}, ${bind(f.lat)}), 4326)::geography, ${bind(f.radiusKm * 1000)})`);
    }
    const where = conditions.join(' AND ');

    const distanceSelect = f.lat !== undefined && f.lng !== undefined
      ? `, ST_Distance(v.location, ST_SetSRID(ST_MakePoint(${bind(f.lng)}, ${bind(f.lat)}), 4326)::geography) AS distance_m`
      : ', NULL::double precision AS distance_m';

    const ratingJoin = `
      LEFT JOIN (
        SELECT vendor_id, AVG(rating)::numeric(3,2) AS average_rating, COUNT(*) AS reviews_count
        FROM reviews GROUP BY vendor_id
      ) rr ON rr.vendor_id = v.id`;

    const orderBy = f.sort === 'price'
      ? `ORDER BY v.min_price ASC NULLS LAST, v.is_open DESC, rr.average_rating DESC NULLS LAST, v.created_at DESC`
      : f.sort === 'rating'
      ? `ORDER BY rr.average_rating DESC NULLS LAST, v.is_open DESC, v.created_at DESC`
      : f.radiusKm !== undefined && f.lat !== undefined && f.lng !== undefined
      ? `ORDER BY distance_m ASC NULLS LAST`
      : `ORDER BY v.is_open DESC, rr.average_rating DESC NULLS LAST, v.created_at DESC`;

    const rowsRes = await this.prisma.$queryRawUnsafe<VendorSearchRow[]>(
      `SELECT v.id, v.name, v.slug, v.description, v.address, v.min_price, v.currency, v.is_open,
              v.phone,
              v.image_url AS image_url,
              c.name_ar AS category_name_ar,
              COALESCE(rr.average_rating, 0) AS average_rating,
              COALESCE(rr.reviews_count, 0) AS reviews_count
              ${distanceSelect}
       FROM vendors v
       JOIN categories c ON c.id = v.category_id
       ${ratingJoin}
       WHERE ${where}
       ${orderBy}
       LIMIT ${bind(f.limit)} OFFSET ${bind(offset)}`,
      ...params,
    );

    const countRes = await this.prisma.$queryRawUnsafe<{ count: bigint }[]>(
      `SELECT COUNT(*) AS count FROM vendors v ${ratingJoin} WHERE ${where}`,
      ...params,
    );

    const total = Number(countRes[0]?.count ?? 0);
    const data = rowsRes.map((r) => ({
      id: r.id,
      name: r.name,
      slug: r.slug,
      description: r.description,
      address: r.address,
      minPrice: r.min_price,
      currency: r.currency,
      isOpen: r.is_open,
      phone: r.phone,
      imageUrl: r.image_url,
      category: r.category_name_ar,
      averageRating: Number(r.average_rating ?? 0),
      reviewsCount: Number(r.reviews_count ?? 0),
      distanceKm: r.distance_m != null ? Math.round(Number(r.distance_m) / 100) / 10 : null,
    }));

    return {
      success: true as const,
      data,
      message: null,
      meta: { page: f.page, limit: f.limit, total, totalPages: Math.ceil(total / f.limit) },
    };
  }

  /** Home feed مجمّع: تصنيفات نشطة + بائعون قريبون (إن وُجد موقع) + الأكثر طلباً */
  async homeFeed(lat?: number, lng?: number) {
    const nearby = lat !== undefined && lng !== undefined
      ? await this.searchVendors({ lat, lng, radiusKm: 20, page: 1, limit: 8 })
      : await this.searchVendors({ page: 1, limit: 8 });
    return nearby;
  }
}
