import { Injectable, Logger } from '@nestjs/common';
import { Prisma, NotificationType } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationSettingsService } from '../notification-settings/notification-settings.service';

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
  private readonly logger = new Logger(NotificationService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly notificationSettingsService: NotificationSettingsService,
  ) {}

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
    const count = await this.prisma.notification.count({
      where: {
        recipientUserId: userId,
        isRead: false,
      },
    });

    return { count };
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
  }): Promise<boolean> {
    const shouldSend = await this.shouldSendInAppNotification(
      params.recipientUserId,
      params.type,
    );

    this.logger.debug(
      `[NotifyUser] userId=${params.recipientUserId}, type=${params.type}, shouldSend=${shouldSend}`,
    );

    if (!shouldSend) {
      this.logger.debug(
        `[NotifyUser] Skipped: user preferences disabled notifications`,
      );
      return false;
    }

    const recipientExists = await this.prisma.user.findUnique({
      where: { id: params.recipientUserId },
      select: { id: true },
    });

    if (!recipientExists) {
      this.logger.warn(
        `[NotifyUser] Recipient user ${params.recipientUserId} not found`,
      );
      return false;
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

    this.logger.debug(
      `[NotifyUser] Successfully created notification for user ${params.recipientUserId}`,
    );


    return true;
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

    const allowedRecipients = await this.filterRecipientsByPreference(
      recipientUserIds,
      params.type,
    );

    if (allowedRecipients.length === 0) {
      return;
    }

    await this.prisma.notification.createMany({
      data: allowedRecipients.map((recipientUserId) => ({
        recipientUserId,
        type: params.type,
        title: params.title,
        body: params.body,
        metadata: params.metadata,
      })),
    });
  }

  private async filterRecipientsByPreference(
    recipientUserIds: number[],
    type: NotificationType,
  ) {
    const results = await Promise.all(
      recipientUserIds.map(async (recipientUserId) => ({
        recipientUserId,
        shouldSend: await this.shouldSendInAppNotification(
          recipientUserId,
          type,
        ),
      })),
    );

    return results
      .filter((result) => result.shouldSend)
      .map((result) => result.recipientUserId);
  }

  private async shouldSendInAppNotification(
    userId: number,
    type: NotificationType,
  ) {
    try {
      return await this.notificationSettingsService.shouldSendNotification(
        userId,
        type,
        'IN_APP',
        'inApp',
      );
    } catch (error) {
      this.logger.warn(
        `Unable to read notification settings for user ${userId} and type ${type}; skipping in-app notification.`,
      );
      this.logger.debug(error);
      return false;
    }
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
