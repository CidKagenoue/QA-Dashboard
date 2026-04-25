import { Injectable } from '@nestjs/common';
import { Prisma, NotificationType } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

const notificationSelect = {
  id: true,
  type: true,
  title: true,
  body: true,
  metadata: true,
  isRead: true,
  readAt: true,
  createdAt: true,
} satisfies Prisma.NotificationSelect;

type NotificationRecord = Prisma.NotificationGetPayload<{
  select: typeof notificationSelect;
}>;

@Injectable()
export class NotificationService {
  constructor(private readonly prisma: PrismaService) {}

  async listForUser(userId: number, options?: { limit?: number }) {
    const notifications = (await this.prisma.notification.findMany({
      where: { recipientUserId: userId },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: options?.limit ?? 50,
      select: notificationSelect,
    })) as NotificationRecord[];

    return {
      notifications: notifications.map((item) => this.serialize(item)),
    };
  }

  async getUnreadCount(userId: number) {
    const unreadCount = await this.prisma.notification.count({
      where: {
        recipientUserId: userId,
        isRead: false,
      },
    });

    return { unreadCount };
  }

  async markRead(userId: number, notificationIds: number[]) {
    const ids = Array.from(
      new Set(
        notificationIds.filter((id) => Number.isInteger(id) && id > 0),
      ),
    );

    if (ids.length === 0) {
      return { success: true, updatedCount: 0 };
    }

    const result = await this.prisma.notification.updateMany({
      where: {
        recipientUserId: userId,
        id: { in: ids },
        isRead: false,
      },
      data: {
        isRead: true,
        readAt: new Date(),
      },
    });

    return {
      success: true,
      updatedCount: result.count,
    };
  }

  async markAllRead(userId: number) {
    const result = await this.prisma.notification.updateMany({
      where: {
        recipientUserId: userId,
        isRead: false,
      },
      data: {
        isRead: true,
        readAt: new Date(),
      },
    });

    return {
      success: true,
      updatedCount: result.count,
    };
  }

  async notifyUser(params: {
    recipientUserId: number;
    type: NotificationType;
    title: string;
    body: string;
    metadata?: Prisma.InputJsonValue;
  }) {
    const recipientExists = await this.prisma.user.findUnique({
      where: { id: params.recipientUserId },
      select: { id: true },
    });

    if (!recipientExists) {
      return;
    }

    await this.prisma.notification.create({
      data: {
        recipientUserId: params.recipientUserId,
        type: params.type,
        title: params.title,
        body: params.body,
        metadata: params.metadata,
      },
    });
  }

  async notifyUsers(params: {
    recipientUserIds: number[];
    type: NotificationType;
    title: string;
    body: string;
    metadata?: Prisma.InputJsonValue;
  }) {
    const recipientUserIds = Array.from(
      new Set(
        params.recipientUserIds.filter(
          (id) => Number.isInteger(id) && id > 0,
        ),
      ),
    );

    if (recipientUserIds.length === 0) {
      return;
    }

    await this.prisma.notification.createMany({
      data: recipientUserIds.map((recipientUserId) => ({
        recipientUserId,
        type: params.type,
        title: params.title,
        body: params.body,
        metadata: params.metadata,
      })),
    });
  }

  private serialize(record: NotificationRecord) {
    return {
      id: record.id,
      type: record.type,
      title: record.title,
      body: record.body,
      metadata: record.metadata,
      isRead: record.isRead,
      readAt: record.readAt?.toISOString() ?? null,
      createdAt: record.createdAt.toISOString(),
    };
  }
}
