import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/prisma.service';

const NOTIF_SELECT = {
  id: true,
  type: true,
  title: true,
  body: true,
  refType: true,
  refId: true,
  readAt: true,
  createdAt: true,
} satisfies Prisma.NotificationSelect;

/**
 * Notifications: in-app الآن. الإرسال الفعلي (push/SMS/email) يتم عبر
 * enqueue داخل العملية نفسها — لا يفشل الـ API إن فشل التوصيل.
 */
@Injectable()
export class NotificationsService {
  constructor(private readonly prisma: PrismaService) {}

  /** تُستدعى من باقي الـ modules داخل نفس الـ transaction إن أمكن */
  async enqueue(tx: Prisma.TransactionClient, data: {
    userId: string;
    type: string;
    title: string;
    body?: string;
    refType?: string;
    refId?: string;
  }) {
    return tx.notification.create({ data });
  }

  listMine(userId: string, unreadOnly: boolean, page = 1, limit = 20) {
    return this.prisma.$transaction([
      this.prisma.notification.count({ where: { userId, ...(unreadOnly ? { readAt: null } : {}) } }),
      this.prisma.notification.findMany({
        where: { userId, ...(unreadOnly ? { readAt: null } : {}) },
        select: NOTIF_SELECT,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);
  }

  unreadCount(userId: string) {
    return this.prisma.notification.count({ where: { userId, readAt: null } });
  }

  async markRead(userId: string, notificationId: string) {
    const n = await this.prisma.notification.findUnique({
      where: { id: notificationId },
      select: { userId: true },
    });
    if (!n) throw new NotFoundException('Notification not found');
    if (n.userId !== userId) throw new ForbiddenException('Not your notification');
    await this.prisma.notification.update({
      where: { id: notificationId },
      data: { readAt: new Date() },
    });
    return { read: true };
  }

  async markAllRead(userId: string) {
    const res = await this.prisma.notification.updateMany({
      where: { userId, readAt: null },
      data: { readAt: new Date() },
    });
    return { marked: res.count };
  }
}
